using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Schnappschuss der relevanten Datei- und Registry-Bereiche.</summary>
public sealed class SystemSnapshot
{
    public Dictionary<string, (long size, long mtime)> Files { get; } = new(StringComparer.OrdinalIgnoreCase);
    public HashSet<string> Directories { get; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, long> Keys { get; } = new(StringComparer.OrdinalIgnoreCase);
    public HashSet<string> Values { get; } = new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>
/// „Installation aufzeichnen“: Schnappschuss vorher → Setup läuft → Schnappschuss nachher → Unterschied speichern.
/// Außerdem: Ablage der Aufzeichnungen und nachträgliche (geschätzte) Zuordnung.
/// </summary>
public static class InstallRecorder
{
    public static string? FolderOverride { get; set; }

    public static string Folder(ProgramSettings s)
    {
        var d = FolderOverride ?? (string.IsNullOrWhiteSpace(s.RecordingsFolder) ? Path.Combine(AppPaths.BaseDir, "Aufzeichnungen") : s.RecordingsFolder);
        Directory.CreateDirectory(d);
        return d;
    }

    private static ProgramSettings? _settings;
    public static void Configure(ProgramSettings s) => _settings = s;
    private static string Dir => Folder(_settings ?? new ProgramSettings());

    public static List<InstallRecording> LoadAll()
    {
        var list = new List<InstallRecording>();
        foreach (var f in Directory.GetFiles(Dir, "*.json"))
        {
            try { if (JsonSerializer.Deserialize<InstallRecording>(File.ReadAllText(f), Json.Options) is { } r) list.Add(r); }
            catch (Exception ex) { ErrorLog.Write($"Aufzeichnung nicht lesbar: {f}", ex); }
        }
        return list.OrderByDescending(r => r.Date).ToList();
    }

    public static void Save(InstallRecording r) => Json.WriteAtomic(Path.Combine(Dir, r.Id + ".json"), r);
    public static void Delete(InstallRecording r) { try { File.Delete(Path.Combine(Dir, r.Id + ".json")); } catch { } }

    public static HashSet<string> RecordedProgramIds()
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        try { foreach (var r in LoadAll()) foreach (var id in r.ProgramIds) set.Add(id); } catch { }
        return set;
    }

    public static InstallRecording? FindFor(InstalledProgram p) =>
        LoadAll().FirstOrDefault(r => r.ProgramIds.Contains(p.Id, StringComparer.OrdinalIgnoreCase) ||
                                      r.ProgramIds.Contains(DesktopCategorizer.NameKey(p.Name), StringComparer.OrdinalIgnoreCase));

    // ───────────── Schnappschuss ─────────────

    /// <summary>Für Tests: eigene Wurzeln.</summary>
    public static List<string>? FileRootsOverride { get; set; }
    public static List<string>? KeyRootsOverride { get; set; }

    private static readonly string[] NoisyParts =
    {
        @"\temp\", @"\inetcache\", @"\packages\", @"\crashdumps\", @"\d3dscache\", @"\microsoft\windows\explorer\",
        @"\google\chrome\user data\", @"\microsoft\edge\user data\", @"\mozilla\firefox\profiles\", @"\bravesoftware\",
        @"\microsoft\windows\notifications\", @"\microsoft\windows\webcache\", @"\nvidia\dxcache\", @"\nvidia\glcache\",
        @"\microsoft\windows\recent\", @"\connecteddevicesplatform\", @"\pcaufraeumer\", @"\windowsapps\",
    };

    private static bool Noisy(string path)
    {
        var p = path.ToLowerInvariant() + "\\";
        return NoisyParts.Any(n => p.Contains(n));
    }

    public static List<string> FileRoots()
    {
        if (FileRootsOverride != null) return FileRootsOverride;
        string E(Environment.SpecialFolder f) => Environment.GetFolderPath(f);
        return new[]
        {
            E(Environment.SpecialFolder.ProgramFiles), E(Environment.SpecialFolder.ProgramFilesX86), E(Environment.SpecialFolder.CommonApplicationData),
            E(Environment.SpecialFolder.ApplicationData), E(Environment.SpecialFolder.LocalApplicationData),
            Path.Combine(E(Environment.SpecialFolder.UserProfile), "AppData", "LocalLow"),
            E(Environment.SpecialFolder.Programs), E(Environment.SpecialFolder.CommonPrograms), KnownFolders.Desktop, KnownFolders.PublicDesktop,
            E(Environment.SpecialFolder.MyDocuments),
        }.Where(Directory.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static readonly string[] KeyRoots =
    {
        @"HKEY_LOCAL_MACHINE\SOFTWARE", @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node", @"HKEY_CURRENT_USER\SOFTWARE",
    };

    private static readonly string[] ExplicitKeyRoots =
    {
        @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        @"HKEY_CURRENT_USER\SOFTWARE\Classes", @"HKEY_LOCAL_MACHINE\SOFTWARE\Classes",
    };

    private static readonly string[] RunKeys =
    {
        @"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        @"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    };

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    private static extern int RegQueryInfoKey(Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey, IntPtr cls, IntPtr lpcClass, IntPtr res,
        IntPtr a, IntPtr b, IntPtr c, IntPtr d, IntPtr e, IntPtr f, IntPtr g, out long lastWrite);

    public static SystemSnapshot Take(IProgress<string>? progress, CancellationToken ct)
    {
        var s = new SystemSnapshot();
        var opts = new EnumerationOptions { RecurseSubdirectories = false, IgnoreInaccessible = true, AttributesToSkip = FileAttributes.ReparsePoint };
        foreach (var root in FileRoots())
        {
            progress?.Report("Dateien: " + root);
            var stack = new Stack<string>();
            stack.Push(root);
            while (stack.Count > 0)
            {
                ct.ThrowIfCancellationRequested();
                var d = stack.Pop();
                if (Noisy(d)) continue;
                s.Directories.Add(d);
                try
                {
                    foreach (var e in new DirectoryInfo(d).EnumerateFileSystemInfos("*", opts))
                    {
                        if (e is DirectoryInfo sub) stack.Push(sub.FullName);
                        else if (e is FileInfo fi) s.Files[fi.FullName] = (fi.Length, fi.LastWriteTimeUtc.Ticks);
                    }
                }
                catch { }
            }
        }

        foreach (var root in KeyRootsOverride ?? KeyRoots.ToList())
        {
            progress?.Report("Registry: " + root);
            WalkKeys(root, s, KeyRootsOverride != null ? 20 : 6, skipMicrosoft: KeyRootsOverride == null, ct);
        }
        if (KeyRootsOverride == null)
        {
            foreach (var root in ExplicitKeyRoots) WalkKeys(root, s, 1, skipMicrosoft: false, ct);
            foreach (var run in RunKeys)
                try
                {
                    var (r, sub) = AdminHelper.SplitKey(run);
                    using (r) { using var k = r.OpenSubKey(sub); if (k != null) foreach (var v in k.GetValueNames()) s.Values.Add(run + "|" + v); }
                }
                catch { }
        }
        return s;
    }

    private static void WalkKeys(string path, SystemSnapshot s, int depth, bool skipMicrosoft, CancellationToken ct)
    {
        try
        {
            var (root, sub) = AdminHelper.SplitKey(path);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                if (k == null) return;
                Walk(k, path, depth);
            }
        }
        catch { }

        void Walk(RegistryKey k, string p, int d)
        {
            ct.ThrowIfCancellationRequested();
            RegQueryInfoKey(k.Handle, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero,
                IntPtr.Zero, IntPtr.Zero, out var lw);
            s.Keys[p] = lw;
            if (d <= 0) return;
            string[] names;
            try { names = k.GetSubKeyNames(); } catch { return; }
            foreach (var n in names)
            {
                if (skipMicrosoft && n is "Microsoft" or "Classes" or "Policies" or "WOW6432Node" or "Clients" or "RegisteredApplications") continue;
                try
                {
                    using var c = k.OpenSubKey(n);
                    if (c != null) Walk(c, p + "\\" + n, d - 1);
                }
                catch { }
            }
        }
    }

    /// <summary>Unterschied zweier Schnappschüsse → Aufzeichnung.</summary>
    public static InstallRecording Diff(SystemSnapshot before, SystemSnapshot after, string name, string setup)
    {
        var r = new InstallRecording { Name = name, SetupFile = setup };
        var newDirs = after.Directories.Where(d => !before.Directories.Contains(d)).ToList();
        // Nur die obersten neuen Ordner (Inhalte stecken darin)
        r.NewDirectories = newDirs.Where(d => !newDirs.Any(o => !string.Equals(o, d, StringComparison.OrdinalIgnoreCase) && ProtectionService.IsUnder(d, o)))
            .OrderBy(d => d).ToList();
        r.NewFiles = after.Files.Keys.Where(f => !before.Files.ContainsKey(f) && !r.NewDirectories.Any(d => ProtectionService.IsUnder(f, d)))
            .OrderBy(f => f).ToList();
        r.ChangedFiles = after.Files.Where(kv => before.Files.TryGetValue(kv.Key, out var b) && b != kv.Value).Select(kv => kv.Key).OrderBy(f => f).ToList();
        var newKeys = after.Keys.Keys.Where(k => !before.Keys.ContainsKey(k)).ToList();
        r.NewKeys = newKeys.Where(k => !newKeys.Any(o => !string.Equals(o, k, StringComparison.OrdinalIgnoreCase) && k.StartsWith(o + "\\", StringComparison.OrdinalIgnoreCase)))
            .OrderBy(k => k).ToList();
        r.ChangedKeys = after.Keys.Where(kv => before.Keys.TryGetValue(kv.Key, out var t) && t != kv.Value).Select(kv => kv.Key).OrderBy(k => k).ToList();
        r.NewValues = after.Values.Where(v => !before.Values.Contains(v)).OrderBy(v => v).ToList();

        // Neue Uninstall-Einträge → Programm zuordnen
        foreach (var k in r.NewKeys.Where(k => k.Contains(@"\CurrentVersion\Uninstall\", StringComparison.OrdinalIgnoreCase)))
        {
            r.ProgramIds.Add("reg:" + k);
            var display = ReadDisplayName(k);
            if (display.Length > 0)
            {
                r.ProgramIds.Add(DesktopCategorizer.NameKey(display));
                if (r.Name.Length == 0 || r.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || r.Name.EndsWith(".msi", StringComparison.OrdinalIgnoreCase))
                    r.Name = display;
            }
        }
        return r;
    }

    private static string ReadDisplayName(string keyPath)
    {
        try
        {
            var (root, sub) = AdminHelper.SplitKey(keyPath);
            using (root) { using var k = root.OpenSubKey(sub); return k?.GetValue("DisplayName") as string ?? ""; }
        }
        catch { return ""; }
    }

    // ───────────── Nachträgliche Zuordnung (geschätzt) ─────────────

    /// <summary>
    /// Nachträglich lässt sich nur noch schätzen, was ein Setup angelegt hat: Ordner/Dateien in den typischen Orten und
    /// Registry-Schlüssel, die rund um den Installationszeitpunkt entstanden sind UND zum Programmnamen passen.
    /// Geänderte Dateien oder Werte ohne passenden Namen sind im Nachhinein nicht mehr erkennbar.
    /// </summary>
    public static InstallRecording EstimateFor(InstalledProgram p, DateTime installedAround)
    {
        var r = new InstallRecording { Name = p.Name, IsEstimate = true, Date = installedAround };
        r.ProgramIds.Add(p.Id);
        r.ProgramIds.Add(DesktopCategorizer.NameKey(p.Name));
        var from = installedAround.AddMinutes(-30);
        var tokens = new[] { LeftoverScanner.Compact(LeftoverScanner.CleanName(p.Name)), LeftoverScanner.Compact(LeftoverScanner.CleanPublisher(p.Publisher)) }
            .Where(t => t.Length >= 4).ToList();
        bool Match(string name) { var c = LeftoverScanner.Compact(name); return tokens.Any(t => c.Contains(t)); }

        foreach (var root in FileRoots())
        {
            IEnumerable<DirectoryInfo> dirs;
            try { dirs = new DirectoryInfo(root).EnumerateDirectories("*", new EnumerationOptions { IgnoreInaccessible = true, RecurseSubdirectories = true, MaxRecursionDepth = 1 }).ToList(); }
            catch { continue; }
            foreach (var d in dirs)
                if (d.CreationTime >= from && Match(d.Name) && !Noisy(d.FullName)) r.NewDirectories.Add(d.FullName);
        }
        r.NewDirectories = r.NewDirectories.Where(d => !r.NewDirectories.Any(o => !string.Equals(o, d, StringComparison.OrdinalIgnoreCase) && ProtectionService.IsUnder(d, o))).ToList();

        var snap = new SystemSnapshot();
        foreach (var root in KeyRoots) WalkKeys(root, snap, 2, skipMicrosoft: true, CancellationToken.None);
        foreach (var (k, lw) in snap.Keys)
        {
            if (DateTime.FromFileTime(lw) < from) continue;
            var leaf = k.Split('\\')[^1];
            if (Match(leaf)) r.NewKeys.Add(k);
        }
        r.NewKeys = r.NewKeys.Where(k => !r.NewKeys.Any(o => !string.Equals(o, k, StringComparison.OrdinalIgnoreCase) && k.StartsWith(o + "\\", StringComparison.OrdinalIgnoreCase))).ToList();
        if (p.InstallLocation.Length > 3 && Directory.Exists(p.InstallLocation) && !r.NewDirectories.Contains(p.InstallLocation, StringComparer.OrdinalIgnoreCase))
            r.NewDirectories.Add(p.InstallLocation);
        return r;
    }
}
