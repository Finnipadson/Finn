using System.Text.RegularExpressions;
using Microsoft.Win32;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Sucht nach Resten deinstallierter Programme (Dateien, Ordner, Registry, Dienste, Aufgaben, Autostart, Firewall).
/// Ändert NICHTS. Gemeinsam genutzte Ordner/Schlüssel und Systembereiche werden nie vorgeschlagen.
/// </summary>
public sealed class LeftoverScanner
{
    private readonly ProgramSettings _settings;
    private readonly IReadOnlyList<InstalledProgram> _stillInstalled;

    /// <summary>Für Tests: Wurzeln der Dateisuche überschreiben.</summary>
    public List<(string path, int depth, string label)>? RootsOverride { get; set; }
    /// <summary>Für Tests: Registry-Wurzeln überschreiben (z. B. HKCU\Software\PCA-Test).</summary>
    public List<string>? RegistryRootsOverride { get; set; }
    public bool ScanSystemObjects { get; set; } = true;

    public LeftoverScanner(ProgramSettings settings, IReadOnlyList<InstalledProgram> stillInstalled)
    {
        _settings = settings;
        _stillInstalled = stillInstalled;
    }

    // ───────────── Fußabdruck vor der Deinstallation ─────────────

    public static ProgramFootprint Footprint(InstalledProgram p, InstallRecording? rec = null)
    {
        var f = new ProgramFootprint
        {
            Id = p.Id, Name = p.Name, Publisher = p.Publisher, InstallLocation = p.InstallLocation.TrimEnd('\\'), MainExe = p.MainExe,
            ProductCode = p.ProductCode, RegistryPath = p.RegistryPath, PackageFamilyName = p.PackageFamilyName, Recording = rec,
        };
        try
        {
            if (f.InstallLocation.Length > 3 && Directory.Exists(f.InstallLocation))
                f.ExeNames = new DirectoryInfo(f.InstallLocation)
                    .EnumerateFiles("*.exe", new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 2, IgnoreInaccessible = true })
                    .Select(x => x.Name).Distinct(StringComparer.OrdinalIgnoreCase).Take(200).ToList();
        }
        catch { }
        if (p.MainExe.Length > 0) f.ExeNames.Add(Path.GetFileName(p.MainExe));
        f.ExeNames = f.ExeNames.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        return f;
    }

    // ───────────── Namens-Erkennung ─────────────

    private static readonly HashSet<string> Generic = new(StringComparer.OrdinalIgnoreCase)
    {
        "microsoft", "windows", "update", "updater", "setup", "program", "programs", "software", "app", "apps", "games", "game",
        "the", "common", "system", "driver", "drivers", "runtime", "edition", "client", "launcher", "service", "services", "tools",
        "tool", "data", "user", "users", "files", "file", "help", "helper", "uninstall", "installer", "install", "main", "core",
        "x64", "x86", "bit", "for", "and", "pro", "free", "desktop", "studio", "manager", "center", "media", "player", "cache",
        "crashpad", "electron", "unins000", "elevate", "plugins", "temp", "local", "roaming", "config", "settings", "logs",
    };

    public static string Compact(string s) => new string(s.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());

    public static string CleanName(string name)
    {
        var s = name;
        s = Regex.Replace(s, @"^(uninstall|deinstall)\s+", "", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"\(.*?\)|\[.*?\]", " ");
        s = Regex.Replace(s, @"\bfor\s+\S+\\.*$", " ", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"\bv?\d+(\.\d+)+\S*", " ");
        s = Regex.Replace(s, @"\b(x64|x86|64-bit|32-bit|amd64|de|en|en-us|de-de)\b", " ", RegexOptions.IgnoreCase);
        return Regex.Replace(s, @"\s+", " ").Trim(' ', '-', '–');
    }

    public static string CleanPublisher(string pub)
    {
        var s = Regex.Replace(pub, @",?\s*\b(inc|ltd|llc|gmbh|corp|corporation|co|company|s\.a|ag|limited|technologies|technology|software|group|plc|pte)\b\.?", " ", RegexOptions.IgnoreCase);
        return Regex.Replace(s, @"\s+", " ").Trim(' ', ',', '.');
    }

    private sealed class Matcher
    {
        public string Name = "";        // kompakt, z. B. "wisprflow"
        public string Publisher = "";   // kompakt, z. B. "wisprflow"
        public HashSet<string> Exes = new(StringComparer.OrdinalIgnoreCase);
        public List<string> Words = new();

        /// <summary>0 = kein Treffer, 3 = exakt Name/Exe, 2 = enthält Namen, 1 = nur ein Wort.</summary>
        public int Score(string candidate)
        {
            var cn = Compact(candidate);
            if (cn.Length < 3) return 0;
            if (Name.Length >= 3 && (cn == Name || cn == Name + "data" || cn == Name + "app")) return 3;
            if (Exes.Contains(cn)) return 3;
            if (Name.Length >= 5 && cn.Contains(Name)) return 2;
            if (Words.Any(w => cn == w)) return 1;
            if (Words.Any(w => w.Length >= 5 && cn.Contains(w))) return 1;
            return 0;
        }

        public bool IsPublisher(string candidate) => Publisher.Length >= 3 && Compact(candidate) == Publisher;
    }

    private static Matcher BuildMatcher(ProgramFootprint f)
    {
        var name = CleanName(f.Name);
        var m = new Matcher { Name = Compact(name), Publisher = Compact(CleanPublisher(f.Publisher)) };
        m.Words = Regex.Split(name, @"[^\p{L}\p{N}]+").Select(w => w.ToLowerInvariant())
            .Where(w => w.Length >= 4 && !Generic.Contains(w)).Distinct().ToList();
        // Nur .exe-Namen als Erkennungsmerkmal, die zum Programm passen (Haupt-.exe oder Name/Wort darin) –
        // Hilfsprogramme wie updater.exe oder maintenanceservice.exe würden sonst Fremdes treffen.
        var main = Compact(Path.GetFileNameWithoutExtension(f.MainExe));
        foreach (var e in f.ExeNames)
        {
            var x = Compact(Path.GetFileNameWithoutExtension(e));
            if (x.Length < 4 || Generic.Contains(x) || x.StartsWith("unins")) continue;
            if (x == main || x == m.Name || (m.Name.Length >= 4 && x.Contains(m.Name)) || m.Words.Any(w => x.Contains(w) || w.Contains(x)))
                m.Exes.Add(x);
        }
        if (m.Publisher == m.Name) m.Publisher = ""; // z. B. „Wispr Flow“ von „Wispr Flow“
        return m;
    }

    // ───────────── Schutzregeln ─────────────

    private static readonly HashSet<string> SharedFolderNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "Common Files", "Microsoft", "Microsoft Shared", "Microsoft.NET", "dotnet", "Windows", "Windows NT", "Windows Defender",
        "Windows Defender Advanced Threat Protection", "WindowsApps", "WindowsPowerShell", "Reference Assemblies", "MSBuild",
        "Internet Explorer", "Windows Mail", "Windows Media Player", "Windows Photo Viewer", "Windows Sidebar", "ModifiableWindowsApps",
        "Package Cache", "Packages", "Temp", "Programs", "Installer", "Drivers", "DriverStore", "Microsoft Visual Studio",
        "Microsoft SDKs", "Windows Kits", "IIS", "IIS Express", "Uninstall Information", "Application Data", "History", "Start Menu",
        "Startup", "Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos", "Favorites", "Links", "Saved Games", "Contacts",
        "My Games", "OneDrive", "D3DSCache", "CrashDumps", "Comms", "ConnectedDevicesPlatform", "PeerDistRepub", "Publishers",
        "regid.1991-06.com.microsoft", "ssh", "USOShared", "Package Cache", "Intel", "AMD", "NVIDIA", "NVIDIA Corporation",
    };

    private static readonly string[] SharedNameParts = { "visual c++", "vc_redist", "vcredist", ".net", "directx", "redistributable", "runtime" };

    private List<string> FixedRoots()
    {
        string E(Environment.SpecialFolder f) => Environment.GetFolderPath(f);
        var list = new List<string>
        {
            E(Environment.SpecialFolder.Windows), E(Environment.SpecialFolder.ProgramFiles), E(Environment.SpecialFolder.ProgramFilesX86),
            E(Environment.SpecialFolder.CommonApplicationData), E(Environment.SpecialFolder.ApplicationData), E(Environment.SpecialFolder.LocalApplicationData),
            Path.Combine(E(Environment.SpecialFolder.UserProfile), "AppData", "LocalLow"), E(Environment.SpecialFolder.MyDocuments),
            E(Environment.SpecialFolder.UserProfile), E(Environment.SpecialFolder.DesktopDirectory), E(Environment.SpecialFolder.CommonDesktopDirectory),
            E(Environment.SpecialFolder.Programs), E(Environment.SpecialFolder.CommonPrograms), E(Environment.SpecialFolder.Startup),
            E(Environment.SpecialFolder.CommonStartup), Path.GetTempPath(), KnownFolders.Desktop, KnownFolders.PublicDesktop, KnownFolders.Downloads,
            Path.Combine(E(Environment.SpecialFolder.LocalApplicationData), "Programs"),
            Path.Combine(E(Environment.SpecialFolder.MyDocuments), "My Games"),
            Path.Combine(E(Environment.SpecialFolder.UserProfile), "Saved Games"),
            Path.Combine(E(Environment.SpecialFolder.ApplicationData), "Microsoft", "Internet Explorer", "Quick Launch"),
            Path.Combine(E(Environment.SpecialFolder.LocalApplicationData), "Packages"),
        };
        return list.Where(s => !string.IsNullOrEmpty(s)).Select(s => s.TrimEnd('\\')).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    /// <summary>Darf dieser Datei-/Ordnerpfad überhaupt vorgeschlagen werden?</summary>
    public string? FileBlockReason(string path, ProgramFootprint f)
    {
        var full = path.TrimEnd('\\');
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (ProtectionService.IsUnder(full, win)) return "Windows-Ordner";
        if (full.Length <= 3) return "Laufwerk";
        if (FixedRoots().Any(r => string.Equals(r, full, StringComparison.OrdinalIgnoreCase))) return "Systemordner";
        if (FixedRoots().Any(r => ProtectionService.IsUnder(r, full))) return "enthält Systemordner";
        // Nur die Teile UNTERHALB des nächsten Systemordners prüfen (sonst würde z. B. „…\Start Menu\…“ alles sperren)
        var root = FixedRoots().Where(r => ProtectionService.IsUnder(full, r)).OrderByDescending(r => r.Length).FirstOrDefault();
        var rel = root != null ? full[(root.Length + 1)..] : full[(Path.GetPathRoot(full)?.Length ?? 0)..];
        var segs = rel.Split('\\', StringSplitOptions.RemoveEmptyEntries);
        if (segs.Any(s => SharedFolderNames.Contains(s)) && !IsExactAppDataOfPackage(full, f)) return "gemeinsam genutzter Ordner";
        var leaf = (segs.Length > 0 ? segs[^1] : full).ToLowerInvariant();
        if (SharedNameParts.Any(s => leaf.Contains(s))) return "gemeinsam genutzte Laufzeitumgebung";
        foreach (var other in _stillInstalled)
        {
            if (other.Id == f.Id || other.InstallLocation.Length < 4) continue;
            var loc = other.InstallLocation.TrimEnd('\\');
            if (ProtectionService.IsUnder(loc, full) || ProtectionService.IsUnder(full, loc))
                return $"gehört (auch) zu „{other.Name}“";
        }
        foreach (var p in _settings.ProtectedPaths)
            if (!p.StartsWith("HKEY", StringComparison.OrdinalIgnoreCase) && ProtectionService.IsUnder(full, p)) return "eigene Schutzliste";
        return null;
    }

    private static bool IsExactAppDataOfPackage(string path, ProgramFootprint f) =>
        f.PackageFamilyName.Length > 0 && path.EndsWith(@"\Packages\" + f.PackageFamilyName, StringComparison.OrdinalIgnoreCase);

    /// <summary>Wird ein Hersteller-Ordner/-Schlüssel noch von einem anderen installierten Programm genutzt?</summary>
    private bool PublisherShared(string publisherCompact, ProgramFootprint f) =>
        _stillInstalled.Any(o => o.Id != f.Id && o.Publisher.Length > 0 && Compact(CleanPublisher(o.Publisher)) == publisherCompact);

    private List<(string id, string name, string exe, string publisher)>? _others;

    private List<(string id, string name, string exe, string publisher)> Others() => _others ??= _stillInstalled
        .Select(o => (o.Id, Compact(CleanName(o.Name)), Compact(Path.GetFileNameWithoutExtension(o.MainExe)), Compact(CleanPublisher(o.Publisher))))
        .ToList();

    /// <summary>
    /// Gehört ein Ordner-/Schlüsselname (auch) einem anderen installierten Programm?
    /// Gleicher Name, gleiche Haupt-.exe, gleicher Hersteller – oder der Name eines anderen, längeren Programms steckt darin
    /// (z. B. „Firefox Developer Edition“, wenn „Firefox“ deinstalliert wird).
    /// </summary>
    private bool NameUsedByOther(string candidateCompact, ProgramFootprint f, Matcher? m = null)
    {
        if (candidateCompact.Length < 3) return false;
        foreach (var (id, name, exe, publisher) in Others())
        {
            if (id == f.Id) continue;
            if (candidateCompact == name || (exe.Length >= 4 && candidateCompact == exe) || (publisher.Length >= 3 && candidateCompact == publisher)) return true;
            if (m != null && name.Length >= 5 && name.Length > m.Name.Length && candidateCompact.Contains(name)) return true;
        }
        return false;
    }

    public string? RegistryBlockReason(string keyPath, bool isValue, ProgramFootprint f)
    {
        try { AdminHelper.EnsureRegistryAllowed(keyPath, isValue); }
        catch (Exception ex) { return ex.Message; }
        foreach (var p in _settings.ProtectedPaths)
            if (p.StartsWith("HKEY", StringComparison.OrdinalIgnoreCase) &&
                (keyPath.StartsWith(p.TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase) || string.Equals(keyPath, p.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)))
                return "eigene Schutzliste";
        var leaf = keyPath.Split('\\')[^1].ToLowerInvariant();
        if (SharedNameParts.Any(s => leaf.Contains(s))) return "gemeinsam genutzte Laufzeitumgebung";
        return null;
    }

    // ───────────── Suche ─────────────

    public List<Leftover> Scan(ProgramFootprint f, LeftoverMode mode, IProgress<string>? progress, CancellationToken ct)
    {
        var found = new Dictionary<string, Leftover>(StringComparer.OrdinalIgnoreCase);
        var m = BuildMatcher(f);
        var loc = f.InstallLocation;
        bool HasLoc() => loc.Length > 3;

        void Add(Leftover l)
        {
            var key = l.Kind + "|" + l.Path;
            if (found.TryGetValue(key, out var ex))
            {
                if (l.Confidence < ex.Confidence) { ex.Confidence = l.Confidence; ex.Reason = l.Reason; }
                return;
            }
            if (Rank(l.Confidence) > Rank(MaxFor(mode))) return;
            found[key] = l;
        }

        void AddPath(string path, Confidence c, string reason)
        {
            if (!File.Exists(path) && !Directory.Exists(path)) return;
            if (FileBlockReason(path, f) != null) return;
            bool dir = Directory.Exists(path);
            Add(new Leftover
            {
                Kind = dir ? LeftoverKind.Ordner : LeftoverKind.Datei, Path = path.TrimEnd('\\'), Display = path.TrimEnd('\\'),
                Confidence = c, Reason = reason, Program = f.Name,
            });
        }

        void AddKey(string keyPath, Confidence c, string reason, bool isValue = false, LeftoverKind kind = LeftoverKind.RegistrySchluessel)
        {
            var key = isValue ? keyPath[..keyPath.IndexOf('|')] : keyPath;
            if (RegistryBlockReason(key, isValue, f) != null) return;
            if (!RegExists(keyPath)) return;
            Add(new Leftover
            {
                Kind = isValue ? LeftoverKind.RegistryWert : kind, Path = keyPath,
                Display = isValue ? keyPath.Replace("|", "  →  Wert: ") : keyPath, Confidence = c, Reason = reason, Program = f.Name,
            });
        }

        // 1) Aufzeichnung (exakt)
        if (f.Recording is { } rec)
        {
            progress?.Report("Installationsaufzeichnung wird ausgewertet …");
            var why = rec.IsEstimate ? "laut geschätzter Zuordnung" : "laut Installationsaufzeichnung";
            // Während der Aufzeichnung können auch andere Programme etwas angelegt haben:
            // „sicher“ nur, wenn der Pfad zum Programm passt, sonst „wahrscheinlich“.
            (Confidence, string) Rate(string path)
            {
                bool fits = path.Split('\\', '|').Any(seg => m.Score(seg) >= 2) || (loc.Length > 3 && ProtectionService.IsUnder(path.Split('|')[0], loc));
                if (rec.IsEstimate) return (Confidence.Wahrscheinlich, why + " (zeitlich und vom Namen her passend)");
                return fits ? (Confidence.Sicher, why + " neu angelegt") : (Confidence.Wahrscheinlich, why + " neu angelegt – Name passt nicht eindeutig, evtl. von einem anderen Programm");
            }
            foreach (var d in rec.NewDirectories) { var (c, w) = Rate(d); AddPath(d, c, w); }
            foreach (var file in rec.NewFiles) { var (c, w) = Rate(file); AddPath(file, c, w); }
            foreach (var k in rec.NewKeys) { var (c, w) = Rate(k); AddKey(k, c, w); }
            foreach (var v in rec.NewValues) { var (c, w) = Rate(v); AddKey(v, c, w, isValue: true); }
        }

        // 2) Installationsordner und Uninstall-Eintrag
        progress?.Report("Installationsordner und Programmeintrag …");
        if (HasLoc()) AddPath(loc, Confidence.Sicher, "Installationsordner des Programms");
        if (f.RegistryPath.Length > 0) AddKey(f.RegistryPath, Confidence.Sicher, "übrig gebliebener Eintrag in der Programmliste");
        if (f.ProductCode.Length > 0)
            foreach (var root in new[] { @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\", @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" })
                AddKey(root + f.ProductCode, Confidence.Sicher, "Uninstall-Eintrag mit passendem Produktcode");

        // 3) Typische Ordner
        progress?.Report("Typische Ordner werden durchsucht …");
        foreach (var (root, depth, label) in RootsOverride ?? StandardRoots(mode))
        {
            ct.ThrowIfCancellationRequested();
            ScanFolder(root, depth, label, f, m, mode, AddPath, ct);
        }

        // 4) Verknüpfungen (Startmenü, Desktop, Schnellstart), die ins Programm zeigen
        if (RootsOverride == null) ScanShortcuts(f, m, AddPath, ct);

        // 5) Registry
        progress?.Report("Registry wird durchsucht …");
        ScanRegistry(f, m, mode, AddKey, ct);

        // 6) Dienste, Aufgaben, Firewall, die auf (nicht mehr vorhandene) Programmdateien zeigen
        if (ScanSystemObjects && mode != LeftoverMode.Sicher)
        {
            progress?.Report("Dienste, geplante Aufgaben und Firewall-Regeln …");
            ScanSystemObjectsFor(f, m, Add, ct);
        }

        // Größe für Ordner/Dateien; Unterpunkte eines vorgeschlagenen Ordners entfernen
        var list = found.Values.ToList();
        var dirs = list.Where(l => l.Kind == LeftoverKind.Ordner).Select(l => l.Path).ToList();
        list = list.Where(l => !(l.IsFileSystem && dirs.Any(d => !string.Equals(d, l.Path, StringComparison.OrdinalIgnoreCase) && ProtectionService.IsUnder(l.Path, d)))).ToList();
        var keys = list.Where(l => l.Kind == LeftoverKind.RegistrySchluessel).Select(l => l.Path).ToList();
        list = list.Where(l => !((l.Kind is LeftoverKind.RegistrySchluessel or LeftoverKind.RegistryWert) &&
                                 keys.Any(k => !string.Equals(k, l.Path, StringComparison.OrdinalIgnoreCase) &&
                                               (l.Path.StartsWith(k + "\\", StringComparison.OrdinalIgnoreCase) || l.Path.StartsWith(k + "|", StringComparison.OrdinalIgnoreCase))))).ToList();
        foreach (var l in list.Where(l => l.IsFileSystem))
        {
            try { l.Size = l.Kind == LeftoverKind.Datei ? new FileInfo(l.Path).Length : ProgramInventory.FolderSize(l.Path, ct) ?? 0; } catch { }
        }
        return list.OrderBy(l => Rank(l.Confidence)).ThenBy(l => l.Path, StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static int Rank(Confidence c) => (int)c;
    private static Confidence MaxFor(LeftoverMode mode) => mode switch
    {
        LeftoverMode.Sicher => Confidence.Sicher,
        LeftoverMode.Moderat => Confidence.Wahrscheinlich,
        _ => Confidence.Unsicher,
    };

    private List<(string path, int depth, string label)> StandardRoots(LeftoverMode mode)
    {
        string E(Environment.SpecialFolder f) => Environment.GetFolderPath(f);
        var local = E(Environment.SpecialFolder.LocalApplicationData);
        var docs = E(Environment.SpecialFolder.MyDocuments);
        var list = new List<(string, int, string)>
        {
            (E(Environment.SpecialFolder.ProgramFiles), 2, "Programme"),
            (E(Environment.SpecialFolder.ProgramFilesX86), 2, "Programme (x86)"),
            (E(Environment.SpecialFolder.CommonApplicationData), 2, "ProgramData"),
            (E(Environment.SpecialFolder.ApplicationData), 2, "AppData\\Roaming"),
            (local, 2, "AppData\\Local"),
            (Path.Combine(local, "Programs"), 1, "AppData\\Local\\Programs"),
            (Path.Combine(E(Environment.SpecialFolder.UserProfile), "AppData", "LocalLow"), 2, "AppData\\LocalLow"),
            (docs, mode == LeftoverMode.Erweitert ? 2 : 1, "Dokumente"),
            (Path.Combine(docs, "My Games"), 1, "Dokumente\\My Games"),
            (Path.Combine(E(Environment.SpecialFolder.UserProfile), "Saved Games"), 1, "Gespeicherte Spiele"),
            (E(Environment.SpecialFolder.Programs), 1, "Startmenü"),
            (E(Environment.SpecialFolder.CommonPrograms), 1, "Startmenü (alle Benutzer)"),
        };
        if (mode != LeftoverMode.Sicher) list.Add((Path.GetTempPath().TrimEnd('\\'), 1, "Temp"));
        return list;
    }

    private void ScanFolder(string root, int depth, string label, ProgramFootprint f, Matcher m, LeftoverMode mode,
        Action<string, Confidence, string> add, CancellationToken ct)
    {
        if (!Directory.Exists(root)) return;
        IEnumerable<string> entries;
        try { entries = Directory.EnumerateFileSystemEntries(root).ToList(); } catch { return; }
        foreach (var e in entries)
        {
            ct.ThrowIfCancellationRequested();
            bool isDir = Directory.Exists(e);
            var name = isDir ? Path.GetFileName(e) : Path.GetFileNameWithoutExtension(e);
            if (isDir && SharedFolderNames.Contains(name)) continue;
            int score = m.Score(name);
            var cn = Compact(name);
            bool foreign = score > 0 && NameUsedByOther(cn, f, m);

            if (foreign) { /* gehört (auch) einem anderen installierten Programm → nie vorschlagen */ }
            else if (score == 3) add(e, Confidence.Sicher, $"{label}: Name passt genau zum Programm");
            else if (score == 2) add(e, Confidence.Wahrscheinlich, $"{label}: Name enthält den Programmnamen");
            else if (score == 1 && mode == LeftoverMode.Erweitert)
                add(e, Confidence.Unsicher, $"{label}: Name enthält ein Wort aus dem Programmnamen");

            // Hersteller-Ordner: hineinschauen (Programm-Unterordner) – den Herstellerordner selbst nur, wenn ihn sonst niemand nutzt
            if (isDir && depth > 1 && m.IsPublisher(name))
            {
                bool shared = PublisherShared(m.Publisher, f);
                ScanFolder(e, depth - 1, label + "\\" + name, f, m, mode, add, ct);
                if (!shared && mode != LeftoverMode.Sicher)
                    add(e, Confidence.Wahrscheinlich, $"{label}: Herstellerordner „{name}“ (kein anderes Programm dieses Herstellers installiert)");
            }
        }
    }

    private void ScanShortcuts(ProgramFootprint f, Matcher m, Action<string, Confidence, string> add, CancellationToken ct)
    {
        string E(Environment.SpecialFolder s) => Environment.GetFolderPath(s);
        var roots = new[]
        {
            E(Environment.SpecialFolder.Programs), E(Environment.SpecialFolder.CommonPrograms), KnownFolders.Desktop, KnownFolders.PublicDesktop,
            Path.Combine(E(Environment.SpecialFolder.ApplicationData), "Microsoft", "Internet Explorer", "Quick Launch"),
            E(Environment.SpecialFolder.Startup), E(Environment.SpecialFolder.CommonStartup),
        };
        var loc = f.InstallLocation;
        foreach (var r in roots.Where(Directory.Exists))
        {
            IEnumerable<string> lnks;
            try { lnks = Directory.EnumerateFiles(r, "*.lnk", new EnumerationOptions { RecurseSubdirectories = true, MaxRecursionDepth = 3, IgnoreInaccessible = true }).ToList(); }
            catch { continue; }
            foreach (var l in lnks)
            {
                ct.ThrowIfCancellationRequested();
                var target = ShortcutResolver.Resolve(l).Target; // Scan läuft auf einem STA-Thread
                if (target.Length == 0) continue;
                bool intoLoc = loc.Length > 3 && ProtectionService.IsUnder(target, loc);
                bool exeMatch = m.Exes.Contains(Compact(Path.GetFileNameWithoutExtension(target)));
                if ((intoLoc || exeMatch) && !File.Exists(target))
                    add(l, Confidence.Sicher, "Verknüpfung zeigt auf eine nicht mehr vorhandene Programmdatei");
                else if (intoLoc)
                    add(l, Confidence.Sicher, "Verknüpfung zeigt in den Installationsordner");
            }
        }
    }

    // ───────────── Registry ─────────────

    private static bool RegExists(string path)
    {
        try
        {
            var bar = path.IndexOf('|');
            var (root, sub) = AdminHelper.SplitKey(bar < 0 ? path : path[..bar]);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                if (k == null) return false;
                return bar < 0 || k.GetValue(path[(bar + 1)..]) != null;
            }
        }
        catch { return false; }
    }

    private void ScanRegistry(ProgramFootprint f, Matcher m, LeftoverMode mode, Action<string, Confidence, string, bool, LeftoverKind> addKey, CancellationToken ct)
    {
        void Key(string p, Confidence c, string why) => addKey(p, c, why, false, LeftoverKind.RegistrySchluessel);
        void Val(string p, Confidence c, string why) => addKey(p, c, why, true, LeftoverKind.RegistryWert);
        var loc = f.InstallLocation;

        var softwareRoots = RegistryRootsOverride ?? new List<string>
        {
            @"HKEY_CURRENT_USER\SOFTWARE", @"HKEY_LOCAL_MACHINE\SOFTWARE", @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node",
        };
        foreach (var root in softwareRoots)
        {
            ct.ThrowIfCancellationRequested();
            foreach (var (name, path) in SubKeys(root))
            {
                if (name.Equals("Microsoft", StringComparison.OrdinalIgnoreCase) || name.Equals("Classes", StringComparison.OrdinalIgnoreCase) ||
                    name.Equals("WOW6432Node", StringComparison.OrdinalIgnoreCase) || name.Equals("Policies", StringComparison.OrdinalIgnoreCase)) continue;
                int score = m.Score(name);
                var cn = Compact(name);
                bool foreign = score > 0 && NameUsedByOther(cn, f, m);
                if (foreign) { }
                else if (score == 3) Key(path, Confidence.Sicher, "Registry-Schlüssel mit genau dem Programmnamen");
                else if (score == 2) Key(path, Confidence.Wahrscheinlich, "Registry-Schlüssel enthält den Programmnamen");
                else if (score == 1 && mode == LeftoverMode.Erweitert) Key(path, Confidence.Unsicher, "Registry-Schlüssel enthält ein Wort aus dem Programmnamen");

                if (m.IsPublisher(name))
                {
                    foreach (var (n2, p2) in SubKeys(path))
                    {
                        int s2 = m.Score(n2);
                        if (s2 > 0 && NameUsedByOther(Compact(n2), f, m)) continue;
                        if (s2 == 3) Key(p2, Confidence.Sicher, $"Schlüssel des Programms unter dem Hersteller „{name}“");
                        else if (s2 == 2) Key(p2, Confidence.Wahrscheinlich, $"Schlüssel unter dem Hersteller „{name}“");
                        else if (s2 == 1 && mode == LeftoverMode.Erweitert) Key(p2, Confidence.Unsicher, $"Schlüssel unter dem Hersteller „{name}“");
                    }
                    if (mode != LeftoverMode.Sicher && !PublisherShared(m.Publisher, f))
                        Key(path, Confidence.Wahrscheinlich, $"Hersteller-Schlüssel „{name}“ (kein anderes Programm dieses Herstellers installiert)");
                }
            }
        }
        if (RegistryRootsOverride != null) return;

        // App Paths
        foreach (var root in new[] { @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths", @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths" })
            foreach (var (name, path) in SubKeys(root))
            {
                var def = ReadDefault(path);
                bool into = loc.Length > 3 && ProtectionService.IsUnder(def.Trim('"'), loc);
                if (m.Exes.Contains(Compact(Path.GetFileNameWithoutExtension(name))) && (into || !File.Exists(def.Trim('"'))))
                    Key(path, Confidence.Sicher, "App-Paths-Eintrag für eine Programmdatei");
            }

        // Autostart (Run/RunOnce)
        foreach (var root in new[]
                 {
                     @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                     @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                     @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
                 })
            foreach (var (valueName, data) in Values(root))
            {
                var exe = ProgramInventory.ResolveExe(ProgramInventory.ExeFromCommand(data));
                bool into = loc.Length > 3 && ProtectionService.IsUnder(exe, loc);
                bool exeMatch = m.Exes.Contains(Compact(Path.GetFileNameWithoutExtension(exe)));
                if ((into || exeMatch) && !File.Exists(exe)) Val(root + "|" + valueName, Confidence.Sicher, "Autostart-Eintrag zeigt auf eine gelöschte Programmdatei");
                else if (into) Val(root + "|" + valueName, Confidence.Wahrscheinlich, "Autostart-Eintrag zeigt in den Installationsordner");
            }

        if (mode == LeftoverMode.Sicher) return;

        // Dateizuordnungen und Kontextmenüs, deren Befehl ins Programm zeigt
        foreach (var classes in new[] { @"HKEY_CURRENT_USER\SOFTWARE\Classes", @"HKEY_LOCAL_MACHINE\SOFTWARE\Classes" })
        {
            foreach (var (name, path) in SubKeys(classes))
            {
                ct.ThrowIfCancellationRequested();
                if (name.StartsWith('.') || name is "CLSID" or "Interface" or "TypeLib" or "AppID" or "Installer" or "Local Settings") continue;
                if (name is "*" or "Directory" or "Folder" or "Drive" or "AllFilesystemObjects")
                {
                    foreach (var shellRoot in new[] { path + @"\shell", path + @"\Background\shell" })
                        foreach (var (verb, vpath) in SubKeys(shellRoot))
                            if (CommandMatches(ReadDefault(vpath + @"\command"), loc, m))
                                Key(vpath, Confidence.Wahrscheinlich, "Kontextmenü-Eintrag, dessen Befehl ins Programm zeigt");
                    continue;
                }
                var cmd = ReadDefault(path + @"\shell\open\command");
                if (cmd.Length > 0 && CommandMatches(cmd, loc, m))
                    Key(path, Confidence.Wahrscheinlich, "Dateizuordnung, deren Öffnen-Befehl ins Programm zeigt");
            }
        }

        // Erweitert: Werte, die den Installationspfad enthalten (begrenzte Tiefe)
        if (mode == LeftoverMode.Erweitert && loc.Length > 3)
        {
            foreach (var root in new[] { @"HKEY_CURRENT_USER\SOFTWARE", @"HKEY_LOCAL_MACHINE\SOFTWARE" })
                DeepValueScan(root, loc, 4, Val, ct);
        }
    }

    private static bool CommandMatches(string cmd, string loc, Matcher m)
    {
        if (cmd.Length == 0) return false;
        var exe = ProgramInventory.ExeFromCommand(cmd);
        if (loc.Length > 3 && ProtectionService.IsUnder(exe, loc)) return true;
        return m.Exes.Contains(Compact(Path.GetFileNameWithoutExtension(exe))) && !File.Exists(exe);
    }

    private static int _deepBudget;

    private static void DeepValueScan(string root, string loc, int depth, Action<string, Confidence, string> val, CancellationToken ct)
    {
        _deepBudget = 200_000;
        void Walk(string path, int d)
        {
            if (d < 0 || _deepBudget-- <= 0) return;
            ct.ThrowIfCancellationRequested();
            foreach (var (name, data) in Values(path))
                if (data.Contains(loc, StringComparison.OrdinalIgnoreCase))
                    val(path + "|" + name, Confidence.Unsicher, "Wert enthält den Installationspfad");
            foreach (var (n, p) in SubKeys(path))
            {
                if (n is "Microsoft" or "Classes" or "Policies" or "WOW6432Node") continue;
                Walk(p, d - 1);
            }
        }
        Walk(root, depth);
    }

    private static IEnumerable<(string name, string path)> SubKeys(string keyPath)
    {
        string[] names;
        try
        {
            var (root, sub) = AdminHelper.SplitKey(keyPath);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                names = k?.GetSubKeyNames() ?? Array.Empty<string>();
            }
        }
        catch { names = Array.Empty<string>(); }
        foreach (var n in names) yield return (n, keyPath + "\\" + n);
    }

    private static IEnumerable<(string name, string data)> Values(string keyPath)
    {
        var list = new List<(string, string)>();
        try
        {
            var (root, sub) = AdminHelper.SplitKey(keyPath);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                if (k != null)
                    foreach (var n in k.GetValueNames())
                        if (k.GetValue(n, null, RegistryValueOptions.DoNotExpandEnvironmentNames) is string s) list.Add((n, Environment.ExpandEnvironmentVariables(s)));
            }
        }
        catch { }
        return list;
    }

    private static string ReadDefault(string keyPath)
    {
        try
        {
            var (root, sub) = AdminHelper.SplitKey(keyPath);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                return Environment.ExpandEnvironmentVariables(k?.GetValue("") as string ?? "");
            }
        }
        catch { return ""; }
    }

    // ───────────── Dienste, Aufgaben, Firewall ─────────────

    private void ScanSystemObjectsFor(ProgramFootprint f, Matcher m, Action<Leftover> add, CancellationToken ct)
    {
        var loc = f.InstallLocation;
        bool Points(string exe) =>
            exe.Length > 0 && ((loc.Length > 3 && ProtectionService.IsUnder(exe, loc)) ||
                               (m.Exes.Contains(Compact(Path.GetFileNameWithoutExtension(exe))) && !File.Exists(exe)));

        // Dienste
        foreach (var (name, path) in SubKeys(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services"))
        {
            ct.ThrowIfCancellationRequested();
            var img = Values(path).FirstOrDefault(v => v.name.Equals("ImagePath", StringComparison.OrdinalIgnoreCase)).data ?? "";
            var exe = ProgramInventory.ResolveExe(ProgramInventory.ExeFromCommand(img));
            if (!Points(exe) || File.Exists(exe)) continue; // nur verwaiste Dienste
            add(new Leftover
            {
                Kind = LeftoverKind.Dienst, Path = name, Display = $"Dienst „{name}“ → {exe}", Extra = path,
                Confidence = Confidence.Wahrscheinlich, Reason = "Dienst zeigt auf eine nicht mehr vorhandene Programmdatei", Program = f.Name,
            });
        }

        // Geplante Aufgaben
        try
        {
            foreach (var (taskPath, exe) in ScheduledTaskActions())
            {
                if (!Points(exe) || File.Exists(exe)) continue;
                add(new Leftover
                {
                    Kind = LeftoverKind.Aufgabe, Path = taskPath, Display = $"Aufgabe „{taskPath}“ → {exe}",
                    Confidence = Confidence.Wahrscheinlich, Reason = "Geplante Aufgabe startet eine nicht mehr vorhandene Programmdatei", Program = f.Name,
                });
            }
        }
        catch (Exception ex) { ErrorLog.Write("Geplante Aufgaben konnten nicht gelesen werden.", ex); }

        // Firewall-Regeln
        try
        {
            var t = Type.GetTypeFromProgID("HNetCfg.FwPolicy2");
            if (t != null)
            {
                dynamic pol = Activator.CreateInstance(t)!;
                foreach (dynamic rule in pol.Rules)
                {
                    string app = "";
                    try { app = Environment.ExpandEnvironmentVariables((string)(rule.ApplicationName ?? "")); } catch { }
                    if (!Points(app) || File.Exists(app)) continue;
                    string name = rule.Name;
                    add(new Leftover
                    {
                        Kind = LeftoverKind.Firewall, Path = name, Display = $"Firewall-Regel „{name}“ → {app}",
                        Confidence = Confidence.Wahrscheinlich, Reason = "Firewall-Regel für eine nicht mehr vorhandene Programmdatei", Program = f.Name,
                    });
                }
            }
        }
        catch (Exception ex) { ErrorLog.Write("Firewall-Regeln konnten nicht gelesen werden.", ex); }
    }

    /// <summary>Alle geplanten Aufgaben mit ihren Programmaktionen (Aufgabenplanung über COM).</summary>
    public static List<(string path, string exe)> ScheduledTaskActions()
    {
        var list = new List<(string, string)>();
        var t = Type.GetTypeFromProgID("Schedule.Service");
        if (t == null) return list;
        dynamic svc = Activator.CreateInstance(t)!;
        svc.Connect();
        void Walk(dynamic folder)
        {
            try
            {
                foreach (dynamic task in folder.GetTasks(1)) // 1 = auch versteckte
                {
                    try
                    {
                        foreach (dynamic action in task.Definition.Actions)
                            if ((int)action.Type == 0) list.Add(((string)task.Path, ProgramInventory.ResolveExe(Environment.ExpandEnvironmentVariables((string)action.Path).Trim('"'))));
                    }
                    catch { }
                }
                foreach (dynamic sub in folder.GetFolders(0)) Walk(sub);
            }
            catch { }
        }
        Walk(svc.GetFolder("\\"));
        return list;
    }
}
