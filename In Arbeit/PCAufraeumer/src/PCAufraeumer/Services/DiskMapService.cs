using System.IO.Enumeration;
using System.Windows;

namespace PCAufraeumer.Services;

/// <summary>Ein Eintrag der Speicherplatz-Karte: Ordner, große Datei oder Sammel-Eintrag („n weitere Dateien“).</summary>
public sealed class DiskNode
{
    public string Name { get; init; } = "";
    public string FullPath { get; init; } = "";
    public bool IsDirectory { get; init; }
    /// <summary>Sammel-Eintrag (kleine Dateien, nicht erfasst …) – kein echter Pfad zum Hineinzoomen.</summary>
    public bool IsGroup { get; init; }
    public long Size { get; set; }
    /// <summary>Anzahl Dateien (bei Ordnern inkl. Unterordner).</summary>
    public long FileCount { get; set; }
    /// <summary>Ordner, die nicht gelesen werden konnten (inkl. Unterordner).</summary>
    public int Unreadable { get; set; }
    public DiskNode? Parent { get; set; }
    public List<DiskNode> Children { get; } = new();

    public bool CanOpen => IsDirectory && !IsGroup && Children.Count > 0;
    public string SizeText => Format.Bytes(Size);
    public double ShareOfParent => Parent is { Size: > 0 } p ? (double)Size / p.Size : 1;
    public string ShareText => Format.Number(ShareOfParent * 100, "0.0") + " %";
    public string Glyph => IsGroup ? "" : IsDirectory ? "" : "";
    public string Detail => IsDirectory && !IsGroup
        ? $"{FileCount:N0} Dateien" + (Unreadable > 0 ? $" · {Unreadable} Ordner ohne Zugriff" : "")
        : IsGroup ? (FileCount > 0 ? $"{FileCount:N0} Dateien" : "") : "Datei";

    public IEnumerable<DiskNode> PathFromRoot()
    {
        var list = new List<DiskNode>();
        for (var n = this; n != null; n = n.Parent) list.Add(n);
        list.Reverse();
        return list;
    }
}

public sealed class DiskMapProgress
{
    public long Files;
    public long Bytes;
    public string Current = "";
}

/// <summary>
/// Liest einen Ordner/ein Laufwerk rekursiv ein und berechnet die Größen. Liest NUR, ändert nichts.
/// Gespeichert werden alle Ordner, pro Ordner aber nur die größten Dateien einzeln (der Rest als Sammel-Eintrag),
/// damit auch Laufwerke mit Millionen Dateien wenig Arbeitsspeicher brauchen.
/// Verknüpfte Ordner (Junctions/Symlinks) werden nicht verfolgt, „Nur online“-Dateien zählen nicht als belegter Platz.
/// </summary>
public sealed class DiskMapService
{
    public const int FilesPerFolder = 40;

    public long CloudOnlyBytes => Interlocked.Read(ref _cloudBytes);
    public int SkippedLinks => _links;
    private long _cloudBytes;
    private int _links;

    private readonly struct Entry
    {
        public Entry(string name, string path, long len, FileAttributes a, bool dir) { Name = name; Path = path; Length = len; Attributes = a; IsDirectory = dir; }
        public string Name { get; }
        public string Path { get; }
        public long Length { get; }
        public FileAttributes Attributes { get; }
        public bool IsDirectory { get; }
    }

    private static readonly EnumerationOptions Options = new()
    {
        IgnoreInaccessible = false,
        RecurseSubdirectories = false,
        ReturnSpecialDirectories = false,
        AttributesToSkip = 0,
    };

    public DiskNode Scan(string root, DiskMapProgress? progress = null, CancellationToken ct = default)
    {
        root = Path.GetFullPath(root);
        var name = root.Length <= 3 ? root : Path.GetFileName(root.TrimEnd('\\'));
        var node = new DiskNode { Name = name, FullPath = root, IsDirectory = true };
        ScanDir(node, progress, ct, depth: 0);
        AddUnaccounted(node);
        return node;
    }

    /// <summary>Bei ganzen Laufwerken: was Windows als belegt meldet, aber nicht lesbar war (System, kein Zugriff …).</summary>
    private static void AddUnaccounted(DiskNode root)
    {
        if (root.FullPath.Length > 3) return;
        try
        {
            var d = new DriveInfo(root.FullPath);
            if (!d.IsReady) return;
            long used = d.TotalSize - d.TotalFreeSpace;
            long rest = used - root.Size;
            if (rest > used / 100 && rest > 100L * 1024 * 1024)
            {
                root.Children.Add(new DiskNode
                {
                    Name = "Nicht erfasst (System, kein Zugriff, Schattenkopien)", FullPath = root.FullPath, IsGroup = true,
                    Size = rest, Parent = root,
                });
                root.Size += rest;
                root.Children.Sort((a, b) => b.Size.CompareTo(a.Size));
            }
        }
        catch { }
    }

    private void ScanDir(DiskNode dir, DiskMapProgress? progress, CancellationToken ct, int depth)
    {
        ct.ThrowIfCancellationRequested();
        List<Entry> entries;
        try
        {
            entries = new FileSystemEnumerable<Entry>(dir.FullPath,
                (ref FileSystemEntry e) => new Entry(e.FileName.ToString(), e.ToFullPath(), e.IsDirectory ? 0 : e.Length, e.Attributes, e.IsDirectory),
                Options).ToList();
        }
        catch (Exception ex) when (ex is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            dir.Unreadable = 1;
            return;
        }

        var files = new List<DiskNode>();
        long smallSize = 0, smallCount = 0;
        var subDirs = new List<DiskNode>();
        foreach (var e in entries)
        {
            if (e.IsDirectory)
            {
                if ((e.Attributes & FileAttributes.ReparsePoint) != 0 && IsLink(e.Path)) { Interlocked.Increment(ref _links); continue; }
                subDirs.Add(new DiskNode { Name = e.Name, FullPath = e.Path, IsDirectory = true, Parent = dir });
                continue;
            }
            long len = e.Length;
            if (ProtectionService.IsCloudOnly(e.Attributes)) { Interlocked.Add(ref _cloudBytes, len); len = 0; }
            dir.FileCount++;
            dir.Size += len;
            files.Add(new DiskNode { Name = e.Name, FullPath = e.Path, Size = len, Parent = dir, FileCount = 1 });
        }
        if (progress != null)
        {
            Interlocked.Add(ref progress.Files, dir.FileCount);
            Interlocked.Add(ref progress.Bytes, dir.Size);
            progress.Current = dir.FullPath;
        }

        // Die oberen zwei Ebenen parallel lesen (z. B. C:\Users\…), darunter der Reihe nach.
        if (depth < 2 && subDirs.Count > 1)
            Parallel.ForEach(subDirs, new ParallelOptions { CancellationToken = ct, MaxDegreeOfParallelism = Math.Min(8, Environment.ProcessorCount) },
                s => ScanDir(s, progress, ct, depth + 1));
        else
            foreach (var s in subDirs) ScanDir(s, progress, ct, depth + 1);

        foreach (var s in subDirs)
        {
            dir.Size += s.Size;
            dir.FileCount += s.FileCount;
            dir.Unreadable += s.Unreadable;
            dir.Children.Add(s);
        }

        // Nur die größten Dateien einzeln behalten, den Rest bündeln.
        files.Sort((a, b) => b.Size.CompareTo(a.Size));
        for (int i = 0; i < files.Count; i++)
        {
            if (i < FilesPerFolder) dir.Children.Add(files[i]);
            else { smallSize += files[i].Size; smallCount++; }
        }
        if (smallCount > 0)
            dir.Children.Add(new DiskNode
            {
                Name = $"{smallCount:N0} weitere Dateien", FullPath = dir.FullPath, IsGroup = true,
                Size = smallSize, FileCount = smallCount, Parent = dir,
            });
        dir.Children.Sort((a, b) => b.Size.CompareTo(a.Size));
    }

    /// <summary>Junction/Symlink? (OneDrive-Platzhalterordner sind zwar auch Reparse-Punkte, aber keine Verknüpfungen.)</summary>
    private static bool IsLink(string path)
    {
        try { return new DirectoryInfo(path).LinkTarget != null; }
        catch { return true; }
    }
}

/// <summary>Kachel-Aufteilung („squarified treemap“): Fläche proportional zur Größe, möglichst quadratische Kacheln.</summary>
public static class TreemapLayout
{
    public static List<(T Item, Rect Rect)> Compute<T>(IReadOnlyList<T> items, Func<T, double> value, Rect bounds)
    {
        var result = new List<(T, Rect)>();
        var list = items.Select(i => (Item: i, V: Math.Max(0, value(i)))).Where(x => x.V > 0).OrderByDescending(x => x.V).ToList();
        double total = list.Sum(x => x.V);
        if (list.Count == 0 || total <= 0 || bounds.Width <= 0 || bounds.Height <= 0) return result;
        double scale = bounds.Width * bounds.Height / total;
        var areas = list.Select(x => (x.Item, A: x.V * scale)).ToList();

        var r = bounds;
        int i = 0;
        while (i < areas.Count)
        {
            double side = Math.Min(r.Width, r.Height);
            if (side <= 0) break;
            int end = i + 1;
            double sum = areas[i].A;
            double worst = Worst(areas, i, end, sum, side);
            while (end < areas.Count)
            {
                double s2 = sum + areas[end].A;
                double w2 = Worst(areas, i, end + 1, s2, side);
                if (w2 > worst) break;
                sum = s2; worst = w2; end++;
            }
            // Reihe am kürzeren Rand anlegen
            if (r.Width >= r.Height)
            {
                double w = end == areas.Count ? r.Width : Math.Min(r.Width, sum / r.Height);
                double y = r.Y;
                for (int k = i; k < end; k++)
                {
                    double h = k == end - 1 ? r.Bottom - y : areas[k].A / w;
                    result.Add((areas[k].Item, new Rect(r.X, y, w, Math.Max(0, h))));
                    y += h;
                }
                r = new Rect(r.X + w, r.Y, Math.Max(0, r.Width - w), r.Height);
            }
            else
            {
                double h = end == areas.Count ? r.Height : Math.Min(r.Height, sum / r.Width);
                double x = r.X;
                for (int k = i; k < end; k++)
                {
                    double w = k == end - 1 ? r.Right - x : areas[k].A / h;
                    result.Add((areas[k].Item, new Rect(x, r.Y, Math.Max(0, w), h)));
                    x += w;
                }
                r = new Rect(r.X, r.Y + h, r.Width, Math.Max(0, r.Height - h));
            }
            i = end;
        }
        return result;
    }

    private static double Worst<T>(List<(T Item, double A)> a, int from, int to, double sum, double side)
    {
        double max = 0, min = double.MaxValue;
        for (int k = from; k < to; k++) { max = Math.Max(max, a[k].A); min = Math.Min(min, a[k].A); }
        double s2 = sum * sum, w2 = side * side;
        return Math.Max(w2 * max / s2, s2 / (w2 * min));
    }
}
