using System.Diagnostics;
using System.Security.Principal;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Temp-/Cache-Bereiche. Unabhängig von der Ordnerauswahl. Diese Dateien werden direkt gelöscht
/// (nicht Papierkorb) – nur nach eigener, klar beschrifteter Bestätigung.
/// </summary>
public sealed class TempService
{
    public static bool IsAdmin
    {
        get
        {
            try { return new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator); }
            catch { return false; }
        }
    }

    public static List<TempTarget> BuildTargets()
    {
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var list = new List<TempTarget>
        {
            new()
            {
                Id = "user-temp", Name = "Temporäre Dateien (Benutzer)",
                Description = "%TEMP% – nur Dateien älter als 24 Stunden",
                Paths = { Path.GetTempPath() }, MinAgeHours = 24,
            },
            new()
            {
                Id = "win-temp", Name = "Temporäre Dateien (Windows)",
                Description = @"C:\Windows\Temp – nur Dateien älter als 24 Stunden",
                Paths = { Path.Combine(win, "Temp") }, MinAgeHours = 24, RequiresAdmin = true,
            },
        };

        list.Add(BrowserTarget("chrome-cache", "Google Chrome – Cache", "chrome",
            Path.Combine(local, "Google", "Chrome", "User Data")));
        list.Add(BrowserTarget("edge-cache", "Microsoft Edge – Cache", "msedge",
            Path.Combine(local, "Microsoft", "Edge", "User Data")));

        var ff = new TempTarget
        {
            Id = "firefox-cache", Name = "Mozilla Firefox – Cache", BrowserProcess = "firefox",
            Description = "cache2-Ordner aller Firefox-Profile",
        };
        var ffProfiles = Path.Combine(local, "Mozilla", "Firefox", "Profiles");
        if (System.IO.Directory.Exists(ffProfiles))
            foreach (var p in SafeDirs(ffProfiles))
                ff.Paths.Add(Path.Combine(p, "cache2"));
        list.Add(ff);

        list.Add(new TempTarget
        {
            Id = "thumbcache", Name = "Miniaturansichten-Cache",
            Description = "thumbcache_*.db – Windows erzeugt ihn bei Bedarf neu. Vom Explorer gesperrte Teile werden übersprungen.",
            Paths = { Path.Combine(local, "Microsoft", "Windows", "Explorer") }, FilePattern = "thumbcache_*.db",
        });

        list.Add(new TempTarget
        {
            Id = "wu-download", Name = "Windows-Update-Reste",
            Description = @"C:\Windows\SoftwareDistribution\Download – heruntergeladene Update-Pakete älter als 3 Tage",
            Paths = { Path.Combine(win, "SoftwareDistribution", "Download") }, MinAgeHours = 72, RequiresAdmin = true,
        });
        return list;
    }

    private static TempTarget BrowserTarget(string id, string name, string process, string userData)
    {
        var t = new TempTarget
        {
            Id = id, Name = name, BrowserProcess = process,
            Description = "Cache, Code-Cache und GPU-Cache aller Profile (keine Passwörter, Verläufe oder Cookies)",
        };
        if (System.IO.Directory.Exists(userData))
        {
            foreach (var profile in SafeDirs(userData))
            {
                var n = Path.GetFileName(profile);
                if (!(n == "Default" || n.StartsWith("Profile ", StringComparison.Ordinal) || n == "Guest Profile")) continue;
                t.Paths.Add(Path.Combine(profile, "Cache", "Cache_Data"));
                t.Paths.Add(Path.Combine(profile, "Code Cache"));
                t.Paths.Add(Path.Combine(profile, "GPUCache"));
            }
        }
        return t;
    }

    private static IEnumerable<string> SafeDirs(string dir)
    {
        try { return System.IO.Directory.GetDirectories(dir); }
        catch { return Array.Empty<string>(); }
    }

    public static bool IsProcessRunning(string? name)
    {
        if (string.IsNullOrEmpty(name)) return false;
        try
        {
            var ps = Process.GetProcessesByName(name);
            foreach (var p in ps) p.Dispose();
            return ps.Length > 0;
        }
        catch { return false; }
    }

    private static readonly EnumerationOptions Opts = new()
    {
        IgnoreInaccessible = true, RecurseSubdirectories = false, AttributesToSkip = 0,
    };

    /// <summary>Alle Dateien eines Bereichs (ohne Junctions zu verfolgen).</summary>
    private static IEnumerable<FileInfo> Files(TempTarget t, Action onAccessError, CancellationToken ct)
    {
        foreach (var root in t.Paths)
        {
            if (!System.IO.Directory.Exists(root)) continue;
            bool recurse = t.FilePattern == "*";
            var stack = new Stack<DirectoryInfo>();
            stack.Push(new DirectoryInfo(root));
            while (stack.Count > 0)
            {
                ct.ThrowIfCancellationRequested();
                var d = stack.Pop();
                List<FileSystemInfo> entries;
                try { entries = d.EnumerateFileSystemInfos(recurse ? "*" : t.FilePattern, Opts).ToList(); }
                catch { onAccessError(); continue; }
                foreach (var e in entries)
                {
                    if (e is DirectoryInfo sub)
                    {
                        if (!recurse) continue;
                        if ((sub.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push(sub);
                    }
                    else if (e is FileInfo f) yield return f;
                }
            }
        }
    }

    private static bool OldEnough(FileInfo f, TempTarget t)
    {
        if (t.MinAgeHours <= 0) return true;
        var newest = f.LastWriteTime > f.CreationTime ? f.LastWriteTime : f.CreationTime;
        return (DateTime.Now - newest).TotalHours >= t.MinAgeHours;
    }

    public static void Measure(TempTarget t, CancellationToken ct)
    {
        long size = 0; int count = 0; bool incomplete = false;
        try
        {
            foreach (var f in Files(t, () => incomplete = true, ct))
            {
                try
                {
                    if (!OldEnough(f, t)) continue;
                    size += f.Length; count++;
                }
                catch { incomplete = true; }
            }
        }
        catch (OperationCanceledException) { throw; }
        catch (Exception ex) { incomplete = true; ErrorLog.Write($"Temp-Bereich konnte nicht gemessen werden: {t.Name}", ex); }

        // IgnoreInaccessible verschluckt „Zugriff verweigert“ still → bei Admin-Bereichen explizit prüfen,
        // sonst stünde dort fälschlich „0 B – nichts zu löschen“.
        if (t.RequiresAdmin && !IsAdmin && !CanList(t)) incomplete = true;

        t.Size = size;
        t.FileCount = count;
        t.Incomplete = incomplete && t.RequiresAdmin && !IsAdmin;
        t.BrowserRunning = IsProcessRunning(t.BrowserProcess);
        t.Status = BuildStatus(t);
    }

    private static bool CanList(TempTarget t)
    {
        foreach (var root in t.Paths.Where(System.IO.Directory.Exists))
        {
            try { using var e = System.IO.Directory.EnumerateFileSystemEntries(root).GetEnumerator(); e.MoveNext(); }
            catch (UnauthorizedAccessException) { return false; }
            catch { }
        }
        return true;
    }

    public static string BuildStatus(TempTarget t)
    {
        if (t.Paths.Count == 0 || !t.Paths.Any(System.IO.Directory.Exists)) return "Nicht vorhanden";
        if (t.BrowserRunning) return "Browser ist geöffnet – bitte erst schließen";
        if (t.Incomplete && t.FileCount == 0) return "Ohne Adminrechte nicht messbar – Löschen fragt nach Adminrechten";
        if (t.Incomplete) return "Größe evtl. unvollständig (Adminrechte nötig)";
        if (t.FileCount == 0) return "Nichts zu löschen";
        return t.RequiresAdmin && !IsAdmin ? "Bereit – Löschen fragt nach Adminrechten" : "Bereit";
    }

    /// <summary>Löscht Dateien eines Bereichs direkt. Gesperrte Dateien werden übersprungen.</summary>
    public static List<DeleteLogEntry> Clean(TempTarget t, IProgress<string>? progress, CancellationToken ct)
    {
        var log = new List<DeleteLogEntry>();
        if (IsProcessRunning(t.BrowserProcess))
        {
            log.Add(new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = string.Join(" | ", t.Paths), Category = t.Name,
                Method = "Direkt gelöscht (Temp/Cache)", Success = false,
                Error = "Browser ist geöffnet – nicht geleert.",
            });
            return log;
        }

        foreach (var f in Files(t, () => { }, ct).ToList())
        {
            ct.ThrowIfCancellationRequested();
            long size = 0;
            try
            {
                if (!OldEnough(f, t)) continue;
                size = f.Length;
                progress?.Report(f.FullName);
                if ((f.Attributes & FileAttributes.ReadOnly) != 0) f.Attributes &= ~FileAttributes.ReadOnly;
                f.Delete();
                log.Add(new DeleteLogEntry
                {
                    Timestamp = DateTime.Now, Path = f.FullName, Size = size, Category = t.Name,
                    Method = "Direkt gelöscht (Temp/Cache)", Success = true,
                });
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                log.Add(new DeleteLogEntry
                {
                    Timestamp = DateTime.Now, Path = f.FullName, Size = size, Category = t.Name,
                    Method = "Direkt gelöscht (Temp/Cache)", Success = false,
                    Error = ex is UnauthorizedAccessException ? "Kein Zugriff" : "Datei ist in Benutzung",
                });
            }
        }

        // Leere Unterordner aufräumen (die Wurzelordner selbst bleiben bestehen).
        if (t.FilePattern == "*")
            foreach (var root in t.Paths.Where(System.IO.Directory.Exists))
                RemoveEmptyDirs(root, isRoot: true);
        return log;
    }

    private static void RemoveEmptyDirs(string dir, bool isRoot)
    {
        try
        {
            foreach (var sub in System.IO.Directory.GetDirectories(dir))
            {
                if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                RemoveEmptyDirs(sub, false);
            }
            if (!isRoot && !System.IO.Directory.EnumerateFileSystemEntries(dir).Any())
                System.IO.Directory.Delete(dir);
        }
        catch { /* in Benutzung – egal */ }
    }
}
