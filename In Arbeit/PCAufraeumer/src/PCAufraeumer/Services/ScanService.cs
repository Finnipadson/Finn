using System.Diagnostics;
using System.IO.Hashing;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

public sealed class ScanStats
{
    public long FilesSeen;
    public long FoldersSeen;
    public int SkippedProtected;
    public int SkippedCloudOnly;
    public int SkippedLocked;
    public int SkippedSystem;
    public int SkippedExceptions;
    public int Errors;
    public TimeSpan Duration;
}

public sealed class ScanResult
{
    public List<FileCandidate> Candidates { get; } = new();
    public ScanStats Stats { get; } = new();
    public bool Cancelled { get; set; }
}

/// <summary>
/// Dateiscan: alte Videos, doppelte Dateien, alte Downloads.
/// Läuft komplett im Hintergrund, meldet Fortschritt und reagiert auf „Abbrechen“.
/// </summary>
public sealed class ScanService
{
    public static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".mp4", ".mkv", ".mov", ".avi", ".wmv", ".webm", ".flv", ".m4v", ".mpg", ".mpeg", ".m2ts",
        ".mts", ".ts", ".3gp", ".3g2", ".vob", ".ogv", ".f4v", ".asf", ".rm", ".rmvb", ".divx",
    };

    public static readonly HashSet<string> DownloadExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".exe", ".msi", ".msix", ".msixbundle", ".appx", ".appxbundle", ".zip", ".rar", ".7z", ".iso",
        ".img", ".tar", ".gz", ".tgz", ".bz2", ".xz", ".cab", ".dmg", ".vhd", ".vhdx",
    };

    private readonly ProtectionService _protection;
    private readonly LastAccessService _lastAccess;

    public ScanService(ProtectionService protection, LastAccessService lastAccess)
    {
        _protection = protection;
        _lastAccess = lastAccess;
    }

    /// <summary>Zum Testen überschreibbar.</summary>
    public string DownloadsFolder { get; set; } = KnownFolders.Downloads;

    /// <summary>Aufnahme-Ordner ermitteln (zum Testen überschreibbar).</summary>
    public Func<AppSettings, List<RecordingFolder>> RecordingFolders { get; set; } = s => RecordingSources.Detect(s.RecordingFolders);

    /// <summary>Steam-Spielnamen (appid → Name), zum Testen überschreibbar.</summary>
    public Func<Dictionary<string, string>> SteamAppNames { get; set; } = RecordingSources.SteamAppNames;

    private readonly record struct Root(string Path, bool DownloadsOnly);

    private sealed record DupFile(FileInfo Info);

    public Task<ScanResult> ScanAsync(AppSettings s, IProgress<ScanProgress> progress, CancellationToken ct) =>
        Task.Run(() => Scan(s, progress, ct), ct);

    public ScanResult Scan(AppSettings s, IProgress<ScanProgress> progress, CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        var result = new ScanResult();
        var stats = result.Stats;
        var now = DateTime.Now;
        long minSize = (long)(s.MinSizeMB * 1024 * 1024);
        long dupMin = Math.Max(minSize, (long)s.DuplicateMinKB * 1024);
        var exceptions = new HashSet<string>(s.ExceptionFiles, StringComparer.OrdinalIgnoreCase);
        var bySize = new Dictionary<long, List<FileInfo>>();
        var lastReport = Stopwatch.StartNew();
        string downloads = DownloadsFolder;

        void Report(string phase, string path, double pct = -1)
        {
            if (lastReport.ElapsedMilliseconds < 80 && pct < 100) return;
            lastReport.Restart();
            progress.Report(new ScanProgress
            {
                Phase = phase, CurrentPath = path, Percent = pct,
                FilesSeen = stats.FilesSeen, Found = result.Candidates.Count,
            });
        }

        // Aufnahme-Ordner: ihre Videos erscheinen nur unter „Spielaufnahmen“ (nicht doppelt als alte Videos/Duplikate).
        var recFolders = s.CategoryRecordings ? RecordingFolders(s) : new List<RecordingFolder>();
        bool InRecordings(string path) => recFolders.Any(r => ProtectionService.IsUnder(path, r.Path));

        try
        {
            var roots = BuildRoots(s, downloads);
            foreach (var root in roots)
            {
                ct.ThrowIfCancellationRequested();
                foreach (var fi in Walk(root.Path, stats, ct, p => Report("Dateien werden durchsucht", p)))
                {
                    stats.FilesSeen++;
                    FileAttributes a;
                    try { a = fi.Attributes; } catch { stats.Errors++; continue; }

                    if (ProtectionService.IsSystemFile(a)) { stats.SkippedSystem++; continue; }
                    if (ProtectionService.IsCloudOnly(a)) { stats.SkippedCloudOnly++; continue; }
                    if (exceptions.Contains(fi.FullName)) { stats.SkippedExceptions++; continue; }

                    long size;
                    try { size = fi.Length; } catch { stats.Errors++; continue; }
                    if (size < minSize) continue;

                    var ext = fi.Extension;
                    bool inDownloads = s.CategoryDownloads && ProtectionService.IsUnder(fi.FullName, downloads);

                    if (inDownloads && DownloadExtensions.Contains(ext))
                    {
                        var created = fi.CreationTime;
                        var written = fi.LastWriteTime;
                        var (date, basis) = created > written ? (created, DateBasis.Created) : (written, DateBasis.LastWrite);
                        if ((now - date).TotalDays > s.DownloadAgeDays)
                        {
                            var c = Make(fi, FindingCategory.Downloads);
                            c.Basis = basis;
                            c.Reason = $"Installer/Archiv im Downloads-Ordner, {Format.Since(date, now)} da";
                            AddChecked(c, result);
                        }
                    }

                    if (root.DownloadsOnly) continue;
                    if (recFolders.Count > 0 && VideoExtensions.Contains(ext) && InRecordings(fi.FullName)) continue;

                    if (s.CategoryVideos && VideoExtensions.Contains(ext))
                    {
                        var (date, basis) = _lastAccess.UsageDate(fi.LastAccessTime, fi.LastWriteTime);
                        if ((now - date).TotalDays > s.VideoAgeDays)
                        {
                            var c = Make(fi, FindingCategory.Videos);
                            c.Basis = basis;
                            c.Reason = basis == DateBasis.LastAccess
                                ? $"{Format.Since(date, now)} nicht geöffnet"
                                : $"{Format.Since(date, now)} nicht geändert (Zugriffsdatum unzuverlässig)";
                            AddChecked(c, result);
                        }
                    }

                    if (s.CategoryDuplicates && size >= dupMin && size > 0)
                    {
                        if (!bySize.TryGetValue(size, out var list)) bySize[size] = list = new List<FileInfo>(2);
                        list.Add(fi);
                    }
                }
            }

            if (recFolders.Count > 0)
                FindRecordings(recFolders, exceptions, result, ct, p => Report("Spielaufnahmen werden gesucht", p));

            if (s.CategoryDuplicates)
                FindDuplicates(bySize, result, progress, ct);
        }
        catch (OperationCanceledException)
        {
            result.Cancelled = true;
        }

        stats.Duration = sw.Elapsed;
        progress.Report(new ScanProgress
        {
            Phase = result.Cancelled ? "Abgebrochen" : "Fertig", CurrentPath = "", Percent = 100,
            FilesSeen = stats.FilesSeen, Found = result.Candidates.Count,
        });
        return result;
    }

    /// <summary>Gewählte Ordner ohne Verschachtelung + Downloads-Ordner (falls nicht schon enthalten).</summary>
    private List<Root> BuildRoots(AppSettings s, string downloads)
    {
        var folders = s.ScanFolders
            .Where(f => !string.IsNullOrWhiteSpace(f) && System.IO.Directory.Exists(f))
            .Select(ProtectionService.Normalize)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(f => f.Length)
            .ToList();
        var roots = new List<Root>();
        foreach (var f in folders)
            if (!roots.Any(r => ProtectionService.IsUnder(f, r.Path)))
                roots.Add(new Root(f, false));

        if (s.CategoryDownloads && System.IO.Directory.Exists(downloads) &&
            !roots.Any(r => ProtectionService.IsUnder(downloads, r.Path)))
            roots.Add(new Root(ProtectionService.Normalize(downloads), true));
        return roots;
    }

    private static readonly EnumerationOptions EnumOpts = new()
    {
        IgnoreInaccessible = true,
        RecurseSubdirectories = false,
        AttributesToSkip = 0,
        ReturnSpecialDirectories = false,
    };

    /// <summary>Durchläuft Ordner iterativ. Überspringt geschützte Orte, Systemordner und Verknüpfungen (Junctions).</summary>
    private IEnumerable<FileInfo> Walk(string root, ScanStats stats, CancellationToken ct, Action<string> report)
    {
        var stack = new Stack<DirectoryInfo>();
        stack.Push(new DirectoryInfo(root));
        while (stack.Count > 0)
        {
            ct.ThrowIfCancellationRequested();
            var dir = stack.Pop();
            if (_protection.IsProtectedPath(dir.FullName)) { stats.SkippedProtected++; continue; }
            stats.FoldersSeen++;
            report(dir.FullName);

            IEnumerable<FileSystemInfo> entries;
            List<FileSystemInfo> list;
            try
            {
                entries = dir.EnumerateFileSystemInfos("*", EnumOpts);
                list = entries.ToList();
            }
            catch (Exception ex) when (ex is UnauthorizedAccessException or IOException or System.Security.SecurityException)
            {
                stats.Errors++;
                continue;
            }

            foreach (var e in list)
            {
                if (e is DirectoryInfo d)
                {
                    FileAttributes a;
                    try { a = d.Attributes; } catch { continue; }
                    if (ProtectionService.IsHiddenSystem(a)) { stats.SkippedProtected++; continue; }
                    if ((a & FileAttributes.ReparsePoint) != 0)
                    {
                        // Junctions/Symlinks nicht verfolgen (Schleifen!), OneDrive-Ordner aber schon (kein LinkTarget).
                        string? target = null;
                        try { target = d.LinkTarget; } catch { }
                        if (target != null) continue;
                    }
                    if (ProtectionService.ProtectedFolderNames.Contains(d.Name)) { stats.SkippedProtected++; continue; }
                    stack.Push(d);
                }
                else if (e is FileInfo f)
                {
                    yield return f;
                }
            }
        }
    }

    private static FileCandidate Make(FileInfo fi, FindingCategory cat) => new()
    {
        FullPath = fi.FullName,
        Name = fi.Name,
        Directory = fi.DirectoryName ?? "",
        Size = fi.Length,
        Extension = fi.Extension.ToLowerInvariant(),
        TypeLabel = TypeLabelFor(fi.Extension),
        LastAccess = fi.LastAccessTime,
        LastWrite = fi.LastWriteTime,
        Created = fi.CreationTime,
        Category = cat,
    };

    /// <summary>Letzte Prüfung pro Fund: geschützt, gesperrt oder nur online → nicht vorschlagen.</summary>
    private void AddChecked(FileCandidate c, ScanResult r)
    {
        var problem = _protection.CheckFile(c.FullPath, checkLock: true);
        if (problem == null) { r.Candidates.Add(c); return; }
        if (problem.Contains("gesperrt")) r.Stats.SkippedLocked++;
        else if (problem.Contains("online")) r.Stats.SkippedCloudOnly++;
        else r.Stats.SkippedProtected++;
    }

    public static string TypeLabelFor(string ext)
    {
        ext = ext.ToLowerInvariant();
        if (VideoExtensions.Contains(ext)) return "Video";
        if (ext is ".jpg" or ".jpeg" or ".png" or ".gif" or ".bmp" or ".webp" or ".tif" or ".tiff" or ".heic" or ".ico") return "Bild";
        if (ext is ".mp3" or ".wav" or ".flac" or ".m4a" or ".aac" or ".ogg" or ".wma" or ".opus") return "Audio";
        if (ext is ".pdf") return "PDF";
        if (ext is ".txt" or ".log" or ".md" or ".csv" or ".json" or ".xml" or ".ini" or ".cfg") return "Text";
        if (ext is ".doc" or ".docx" or ".xls" or ".xlsx" or ".ppt" or ".pptx" or ".odt") return "Dokument";
        if (ext is ".exe" or ".msi" or ".msix" or ".appx") return "Installer";
        if (DownloadExtensions.Contains(ext)) return "Archiv/Abbild";
        return ext.Length > 1 ? ext.TrimStart('.').ToUpperInvariant() + "-Datei" : "Datei";
    }

    // ───────────────────────── Spielaufnahmen ─────────────────────────

    /// <summary>
    /// Alle Clips der Aufnahme-Ordner, ohne Altersgrenze. Clips in „Behalten“-Ordnern werden ausgelassen.
    /// Gruppen-Nummer = Rang des Spiels nach Gesamtgröße (größtes Spiel zuerst).
    /// </summary>
    private void FindRecordings(List<RecordingFolder> folders, HashSet<string> exceptions, ScanResult result,
        CancellationToken ct, Action<string> report)
    {
        var stats = result.Stats;
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var found = new List<FileCandidate>();
        Dictionary<string, string>? steamNames = null;
        // Genauester Ordner zuerst (z. B. Videos\NVIDIA vor einem OBS-Ordner „Videos“)
        foreach (var f in folders.OrderByDescending(f => f.Path.Length))
        {
            ct.ThrowIfCancellationRequested();
            foreach (var fi in Walk(f.Path, stats, ct, report))
            {
                if (!VideoExtensions.Contains(fi.Extension) || !RecordingSources.Belongs(f, fi.FullName)) continue;
                if (!seen.Add(fi.FullName)) continue;
                if (RecordingSources.IsInKeepFolder(f.Path, fi.FullName)) { stats.SkippedExceptions++; continue; }
                if (exceptions.Contains(fi.FullName)) { stats.SkippedExceptions++; continue; }
                FileAttributes a;
                try { a = fi.Attributes; } catch { stats.Errors++; continue; }
                if (ProtectionService.IsSystemFile(a)) { stats.SkippedSystem++; continue; }
                if (ProtectionService.IsCloudOnly(a)) { stats.SkippedCloudOnly++; continue; }
                if (f.Source == "Steam") steamNames ??= SteamAppNames();
                var c = Make(fi, FindingCategory.Recordings);
                c.Game = RecordingSources.GameFor(f, fi.FullName, steamNames == null ? null : id => steamNames.GetValueOrDefault(id));
                c.Source = f.Source;
                c.Basis = DateBasis.LastWrite;
                c.Reason = (f.IsCustom ? "Aufnahme aus eigenem Ordner" : $"{f.Source}-Aufnahme") + $" vom {fi.LastWriteTime:dd.MM.yyyy HH:mm}";
                int before = result.Candidates.Count;
                AddChecked(c, result); // gerade laufende Aufnahmen (gesperrt) werden übersprungen
                if (result.Candidates.Count > before) found.Add(c);
            }
        }
        int rank = 1;
        foreach (var g in found.GroupBy(c => c.Game, StringComparer.OrdinalIgnoreCase).OrderByDescending(g => g.Sum(c => c.Size)))
        {
            var name = g.First().Game; // gleiche Schreibweise für die ganze Gruppe
            foreach (var c in g) { c.GroupId = rank; c.Game = name; }
            rank++;
        }
    }

    // ───────────────────────── Duplikate ─────────────────────────

    private const int PartialBlock = 64 * 1024;

    private void FindDuplicates(Dictionary<long, List<FileInfo>> bySize, ScanResult result,
        IProgress<ScanProgress> progress, CancellationToken ct)
    {
        var sizeGroups = bySize.Values.Where(l => l.Count > 1).ToList();
        if (sizeGroups.Count == 0) return;

        // Gesamtmenge für die Fortschrittsanzeige (Vorfilter + volle Hashes, grob geschätzt).
        long partialTotal = sizeGroups.Sum(g => g.Sum(f => Math.Min(f.Length, 2L * PartialBlock)));
        long done = 0;
        var tick = Stopwatch.StartNew();

        void Report(string phase, string path, long total)
        {
            if (tick.ElapsedMilliseconds < 80) return;
            tick.Restart();
            progress.Report(new ScanProgress
            {
                Phase = phase, CurrentPath = path,
                Percent = total > 0 ? Math.Min(99.9, done * 100.0 / total) : -1,
                FilesSeen = result.Stats.FilesSeen, Found = result.Candidates.Count,
            });
        }

        // Stufe 1: Anfang + Ende der Datei hashen (schneller Vorfilter).
        var partialGroups = new List<List<FileInfo>>();
        foreach (var g in sizeGroups)
        {
            var byPartial = new Dictionary<UInt128, List<FileInfo>>();
            foreach (var f in g)
            {
                ct.ThrowIfCancellationRequested();
                Report("Duplikate: Vorfilter (Dateianfang/-ende)", f.FullName, partialTotal);
                var h = TryHash(f.FullName, partial: true, ct, n => done += n);
                if (h is null) { result.Stats.Errors++; continue; }
                if (!byPartial.TryGetValue(h.Value, out var l)) byPartial[h.Value] = l = new List<FileInfo>(2);
                l.Add(f);
            }
            partialGroups.AddRange(byPartial.Values.Where(l => l.Count > 1));
        }

        // Stufe 2: kompletten Inhalt hashen (xxHash128) zur Bestätigung.
        // Kleine Dateien (≤ 128 KB) sind durch Stufe 1 bereits vollständig gehasht.
        long fullTotal = partialGroups.Sum(g => g.Sum(f => f.Length > 2L * PartialBlock ? f.Length : 0));
        done = 0;
        int groupId = 0;
        foreach (var g in partialGroups)
        {
            List<List<(FileInfo f, string hash)>> confirmed;
            if (g[0].Length <= 2L * PartialBlock)
            {
                confirmed = new() { g.Select(f => (f, "")).ToList() };
            }
            else
            {
                var byFull = new Dictionary<UInt128, List<(FileInfo, string)>>();
                foreach (var f in g)
                {
                    ct.ThrowIfCancellationRequested();
                    Report("Duplikate: Inhalt wird verglichen (Hash)", f.FullName, fullTotal);
                    var h = TryHash(f.FullName, partial: false, ct, n => done += n);
                    if (h is null) { result.Stats.Errors++; continue; }
                    if (!byFull.TryGetValue(h.Value, out var l)) byFull[h.Value] = l = new();
                    l.Add((f, h.Value.ToString("X32")));
                }
                confirmed = byFull.Values.Where(l => l.Count > 1).ToList();
            }

            foreach (var grp in confirmed)
            {
                // Gesperrte/geschützte Dateien entfernen – bleiben danach < 2 übrig, ist es keine Gruppe mehr.
                var members = new List<FileCandidate>();
                foreach (var (f, hash) in grp)
                {
                    var problem = _protection.CheckFile(f.FullName, checkLock: true);
                    if (problem != null)
                    {
                        if (problem.Contains("gesperrt")) result.Stats.SkippedLocked++; else result.Stats.SkippedProtected++;
                        continue;
                    }
                    var c = Make(f, FindingCategory.Duplicates);
                    c.Hash = hash;
                    c.Basis = DateBasis.LastWrite;
                    members.Add(c);
                }
                if (members.Count < 2) continue;
                groupId++;
                foreach (var m in members) m.GroupId = groupId;
                ApplyKeepSuggestion(members);
                result.Candidates.AddRange(members);
            }
        }
    }

    private static UInt128? TryHash(string path, bool partial, CancellationToken ct, Action<long> onBytes)
    {
        try
        {
            return ProtectionService.PreserveAccessTime(path, () => Hash(path, partial, ct, onBytes));
        }
        catch (OperationCanceledException) { throw; }
        catch (Exception ex)
        {
            ErrorLog.Write($"Datei konnte nicht gelesen werden (Duplikatprüfung): {path}", ex);
            return null;
        }
    }

    internal static UInt128 Hash(string path, bool partial, CancellationToken ct, Action<long>? onBytes = null)
    {
        var hasher = new XxHash128();
        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete,
            1, FileOptions.SequentialScan);
        long len = fs.Length;
        var buffer = new byte[partial ? PartialBlock : 1024 * 1024];

        if (partial)
        {
            int n = ReadFull(fs, buffer, ct);
            hasher.Append(buffer.AsSpan(0, n));
            onBytes?.Invoke(n);
            if (len > 2L * PartialBlock)
            {
                fs.Seek(-PartialBlock, SeekOrigin.End);
                n = ReadFull(fs, buffer, ct);
                hasher.Append(buffer.AsSpan(0, n));
                onBytes?.Invoke(n);
            }
            else if (len > PartialBlock)
            {
                n = ReadFull(fs, buffer, ct);
                hasher.Append(buffer.AsSpan(0, n));
                onBytes?.Invoke(n);
            }
        }
        else
        {
            int n;
            while ((n = fs.Read(buffer, 0, buffer.Length)) > 0)
            {
                ct.ThrowIfCancellationRequested();
                hasher.Append(buffer.AsSpan(0, n));
                onBytes?.Invoke(n);
            }
        }
        return hasher.GetCurrentHashAsUInt128();
    }

    private static int ReadFull(Stream s, byte[] buf, CancellationToken ct)
    {
        int total = 0, n;
        while (total < buf.Length && (n = s.Read(buf, total, buf.Length - total)) > 0)
        {
            ct.ThrowIfCancellationRequested();
            total += n;
        }
        return total;
    }

    /// <summary>
    /// Schlägt vor, welche Kopie behalten wird: die im „sinnvollsten“ Ordner
    /// (nicht Downloads/Temp, kein „Kopie“ im Namen), bei Gleichstand die älteste.
    /// </summary>
    public static void ApplyKeepSuggestion(List<FileCandidate> members)
    {
        var keep = members
            .OrderBy(PathPenalty)
            .ThenBy(m => m.Created < m.LastWrite ? m.Created : m.LastWrite)
            .ThenBy(m => m.FullPath.Length)
            .First();
        SetKeep(members, keep);
    }

    public static void SetKeep(IEnumerable<FileCandidate> members, FileCandidate keep)
    {
        foreach (var m in members)
        {
            m.IsKeep = ReferenceEquals(m, keep);
            m.Reason = m.IsKeep
                ? "Wird behalten (Vorschlag – änderbar)"
                : $"Duplikat von {keep.FullPath}";
        }
    }

    internal static int PathPenalty(FileCandidate c)
    {
        int p = 0;
        var path = c.FullPath.ToLowerInvariant();
        var name = c.Name.ToLowerInvariant();
        if (path.Contains(@"\downloads\")) p += 3;
        if (path.Contains(@"\temp\") || path.Contains(@"\tmp\")) p += 3;
        if (path.Contains(@"\desktop\")) p += 1;
        if (path.Contains(@"\onedrive")) p -= 1; // gesicherte Kopie bevorzugen
        if (name.Contains(" - kopie") || name.Contains(" - copy") || name.Contains("kopie von") || name.Contains("copy of")) p += 4;
        if (System.Text.RegularExpressions.Regex.IsMatch(name, @"\(\d+\)\.[^.]+$")) p += 3;
        return p;
    }
}
