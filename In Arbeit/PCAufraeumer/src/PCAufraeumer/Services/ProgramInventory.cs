using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using Microsoft.Win32;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Liest alle installierten Programme: Registry (3 Uninstall-Schlüssel), Store-/Windows-Apps (Appx/PackageManager)
/// und Spiele aus Launchern (Steam, Epic, GOG, EA, Ubisoft, Battle.net). Nur lesend.
/// </summary>
public sealed class ProgramInventory
{
    private const string UninstallPath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";

    public List<InstalledProgram> ReadAll(CancellationToken ct = default)
    {
        var list = new List<InstalledProgram>();
        list.AddRange(Safe(ReadRegistry, "Registry"));
        ct.ThrowIfCancellationRequested();
        list.AddRange(Safe(ReadAppx, "Store-Apps"));
        ct.ThrowIfCancellationRequested();
        var games = new List<InstalledProgram>();
        games.AddRange(Safe(ReadSteam, "Steam"));
        games.AddRange(Safe(ReadEpic, "Epic"));
        games.AddRange(Safe(ReadGog, "GOG"));
        games.AddRange(Safe(ReadUbisoft, "Ubisoft"));
        MergeGames(list, games);
        return list.OrderBy(p => p.Name, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    private static IEnumerable<InstalledProgram> Safe(Func<IEnumerable<InstalledProgram>> f, string what)
    {
        try { return f().ToList(); }
        catch (Exception ex) { ErrorLog.Write($"Programmliste: {what} konnte nicht gelesen werden.", ex); return Array.Empty<InstalledProgram>(); }
    }

    // ───────────── Registry ─────────────

    public IEnumerable<InstalledProgram> ReadRegistry()
    {
        foreach (var (hive, view, label) in new[]
                 {
                     (RegistryHive.LocalMachine, RegistryView.Registry64, @"HKEY_LOCAL_MACHINE\SOFTWARE"),
                     (RegistryHive.LocalMachine, RegistryView.Registry32, @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node"),
                     (RegistryHive.CurrentUser, RegistryView.Registry64, @"HKEY_CURRENT_USER\SOFTWARE"),
                 })
        {
            using var root = RegistryKey.OpenBaseKey(hive, view);
            using var un = root.OpenSubKey(UninstallPath);
            if (un == null) continue;
            foreach (var sub in un.GetSubKeyNames())
            {
                using var k = un.OpenSubKey(sub);
                if (k == null) continue;
                var p = FromUninstallKey(k, sub, $@"{label}\Microsoft\Windows\CurrentVersion\Uninstall\{sub}");
                if (p != null) yield return p;
            }
        }
    }

    internal static InstalledProgram? FromUninstallKey(RegistryKey k, string sub, string fullPath)
    {
        var name = (k.GetValue("DisplayName") as string)?.Trim();
        if (string.IsNullOrEmpty(name)) return null;
        string S(string v) => (k.GetValue(v) as string ?? "").Trim();
        int I(string v) => k.GetValue(v) is int i ? i : 0;

        var p = new InstalledProgram
        {
            Id = "reg:" + fullPath,
            Name = name,
            Version = S("DisplayVersion"),
            Publisher = S("Publisher"),
            InstallLocation = S("InstallLocation").Trim('"').Replace('/', '\\'),
            UninstallString = S("UninstallString"),
            QuietUninstallString = S("QuietUninstallString"),
            DisplayIcon = S("DisplayIcon"),
            RegistryPath = fullPath,
            IsSystemComponent = I("SystemComponent") == 1,
            HasParent = !string.IsNullOrEmpty(S("ParentKeyName")),
        };
        var rt = S("ReleaseType");
        p.IsUpdate = rt.Contains("Update", StringComparison.OrdinalIgnoreCase) || rt.Contains("Hotfix", StringComparison.OrdinalIgnoreCase)
                     || Regex.IsMatch(name, @"\bKB\d{6,}\b");
        if (Guid.TryParse(sub.Trim('{', '}'), out _) && (I("WindowsInstaller") == 1 || p.UninstallString.Contains("msiexec", StringComparison.OrdinalIgnoreCase)))
            p.ProductCode = sub.StartsWith('{') ? sub : "{" + sub + "}";
        var date = S("InstallDate");
        if (DateTime.TryParseExact(date, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) p.InstallDate = d;
        else
        {
            try { p.InstallDate = RegKeyTime(k); } catch { }
        }
        if (k.GetValue("EstimatedSize") is int kb && kb > 0) { p.RegistrySize = kb * 1024L; p.Size = p.RegistrySize; }

        p.MainExe = ExeFromIcon(p.DisplayIcon);
        if (p.MainExe.Length == 0 && p.InstallLocation.Length > 0) p.MainExe = GuessMainExe(p.InstallLocation, name);

        // Spiele, die sich über ihren Launcher deinstallieren
        if (Regex.Match(sub, @"^Steam App (\d+)$") is { Success: true } sm)
        {
            p.Kind = ProgramKind.Spiel; p.Launcher = "Steam"; p.LauncherUri = $"steam://uninstall/{sm.Groups[1].Value}";
            p.Id = "steam:" + sm.Groups[1].Value;
        }
        else if (p.UninstallString.Contains("Battle.net", StringComparison.OrdinalIgnoreCase) &&
                 !name.StartsWith("Battle.net", StringComparison.OrdinalIgnoreCase))
        {
            p.Kind = ProgramKind.Spiel; p.Launcher = "Battle.net";
            p.LauncherHint = "Die Deinstallation läuft über den Battle.net-Launcher.";
        }
        else if (Regex.IsMatch(p.UninstallString, @"EAInstaller|\\EA Desktop\\|Origin\\", RegexOptions.IgnoreCase) &&
                 !name.Equals("EA app", StringComparison.OrdinalIgnoreCase))
        {
            p.Kind = ProgramKind.Spiel; p.Launcher = "EA";
            p.LauncherHint = "Die Deinstallation läuft über die EA App.";
        }
        else if (Regex.Match(sub, @"^Uplay Install (\d+)$") is { Success: true } um)
        {
            p.Kind = ProgramKind.Spiel; p.Launcher = "Ubisoft"; p.LauncherUri = "uplay://";
            p.LauncherHint = "Im Ubisoft-Launcher: Bibliothek → Spiel → Eigenschaften → Deinstallieren.";
            p.Id = "ubisoft:" + um.Groups[1].Value;
        }

        // Verwaist: weder Deinstaller noch Installationsordner vorhanden
        var uninstExe = ExeFromCommand(p.UninstallString);
        bool uninstMissing = p.UninstallString.Length == 0 ||
                             (uninstExe.Length > 0 && Path.IsPathRooted(uninstExe) && !File.Exists(uninstExe));
        bool locMissing = p.InstallLocation.Length == 0 || !Directory.Exists(p.InstallLocation);
        p.IsOrphaned = p.Kind != ProgramKind.Spiel && uninstMissing && locMissing && p.ProductCode.Length == 0;
        return p;
    }

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    private static extern int RegQueryInfoKey(Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey, IntPtr cls, IntPtr lpcClass, IntPtr res,
        IntPtr a, IntPtr b, IntPtr c, IntPtr d, IntPtr e, IntPtr f, IntPtr g, out long lastWrite);

    private static DateTime? RegKeyTime(RegistryKey k) =>
        RegQueryInfoKey(k.Handle, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero,
            IntPtr.Zero, IntPtr.Zero, out var ft) == 0 ? DateTime.FromFileTime(ft) : null;

    /// <summary>„C:\x\app.exe,0“ → „C:\x\app.exe“.</summary>
    public static string ExeFromIcon(string icon)
    {
        if (string.IsNullOrWhiteSpace(icon)) return "";
        var s = icon.Trim().Trim('"');
        var comma = s.LastIndexOf(',');
        if (comma > 2 && int.TryParse(s[(comma + 1)..].Trim(), out _)) s = s[..comma].Trim().Trim('"');
        s = Environment.ExpandEnvironmentVariables(s);
        return s.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ? s : "";
    }

    /// <summary>Programmpfad aus einer Befehlszeile („"C:\a b\x.exe" /S“ → C:\a b\x.exe).</summary>
    public static string ExeFromCommand(string cmd)
    {
        if (string.IsNullOrWhiteSpace(cmd)) return "";
        cmd = Environment.ExpandEnvironmentVariables(cmd.Trim());
        if (cmd.StartsWith('"'))
        {
            int end = cmd.IndexOf('"', 1);
            return end > 1 ? cmd[1..end] : cmd.Trim('"');
        }
        var m = Regex.Match(cmd, @"^(.+?\.(exe|cmd|bat|com))(\s|$)", RegexOptions.IgnoreCase);
        return m.Success ? m.Groups[1].Value : cmd.Split(' ')[0];
    }

    /// <summary>„cmd.exe“ → „C:\Windows\System32\cmd.exe“ (über System32, Windows-Ordner und PATH). Absolute Pfade unverändert.</summary>
    public static string ResolveExe(string exe)
    {
        if (string.IsNullOrWhiteSpace(exe) || Path.IsPathRooted(exe)) return exe;
        var candidates = new List<string>
        {
            Environment.GetFolderPath(Environment.SpecialFolder.System), Environment.GetFolderPath(Environment.SpecialFolder.Windows),
        };
        candidates.AddRange((Environment.GetEnvironmentVariable("PATH") ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries));
        foreach (var dir in candidates)
        {
            try
            {
                var p = Path.Combine(dir.Trim(), exe);
                if (File.Exists(p)) return p;
                if (!Path.HasExtension(exe) && File.Exists(p + ".exe")) return p + ".exe";
            }
            catch { }
        }
        return exe;
    }

    private static string GuessMainExe(string dir, string name)
    {
        try
        {
            if (!Directory.Exists(dir)) return "";
            var exes = Directory.GetFiles(dir, "*.exe", SearchOption.TopDirectoryOnly)
                .Where(f => !Regex.IsMatch(Path.GetFileName(f), @"unins|uninst|setup|update|crash|helper", RegexOptions.IgnoreCase)).ToList();
            var first = name.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "";
            return exes.FirstOrDefault(e => Path.GetFileName(e).Contains(first, StringComparison.OrdinalIgnoreCase)) ?? exes.FirstOrDefault() ?? "";
        }
        catch { return ""; }
    }

    // ───────────── Store- und Windows-Apps ─────────────

    private sealed class AppxRaw
    {
        public string? Name { get; set; }
        public string? PackageFullName { get; set; }
        public string? PackageFamilyName { get; set; }
        public string? Publisher { get; set; }
        public string? Version { get; set; }
        public string? InstallLocation { get; set; }
        public string? SignatureKind { get; set; }
        public bool NonRemovable { get; set; }
        public bool IsFramework { get; set; }
        public bool IsResourcePackage { get; set; }
    }

    [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
    private static extern int SHLoadIndirectString(string source, StringBuilder outBuf, int cap, IntPtr reserved);

    /// <summary>
    /// Store- und Windows-Apps des aktuellen Benutzers. Über das Windows-eigene Appx-Modul
    /// (nutzt intern dieselbe PackageManager-Schnittstelle), weil die direkte WinRT-API mit der
    /// Videoplayer-Bibliothek kollidiert.
    /// </summary>
    public IEnumerable<InstalledProgram> ReadAppx()
    {
        const string script =
            "$ErrorActionPreference='SilentlyContinue';" +
            "Get-AppxPackage | Where-Object { -not $_.IsFramework -and -not $_.IsResourcePackage } | " +
            "Select-Object Name,PackageFullName,PackageFamilyName,Publisher,@{n='Version';e={\"$($_.Version)\"}},InstallLocation," +
            "@{n='SignatureKind';e={\"$($_.SignatureKind)\"}},NonRemovable,IsFramework,IsResourcePackage | ConvertTo-Json -Compress";
        var json = RunPowerShell(script, 60000);
        if (string.IsNullOrWhiteSpace(json)) yield break;
        var raws = json.TrimStart().StartsWith('[')
            ? JsonSerializer.Deserialize<List<AppxRaw>>(json) ?? new()
            : new List<AppxRaw> { JsonSerializer.Deserialize<AppxRaw>(json)! };

        foreach (var r in raws)
        {
            if (r.PackageFullName == null || r.Name == null) continue;
            var loc = r.InstallLocation ?? "";
            var (display, logo, visible, description) = ReadManifest(loc, r.PackageFullName, r.Name);
            bool system = r.NonRemovable || string.Equals(r.SignatureKind, "System", StringComparison.OrdinalIgnoreCase);
            bool microsoft = (r.Publisher ?? "").Contains("Microsoft", StringComparison.OrdinalIgnoreCase) ||
                             PreinstalledIds.Any(id => r.Name.StartsWith(id, StringComparison.OrdinalIgnoreCase));
            var p = new InstalledProgram
            {
                Id = "appx:" + r.PackageFamilyName,
                Name = display,
                Version = r.Version ?? "",
                Publisher = PublisherDisplay(r.Publisher ?? ""),
                InstallLocation = loc,
                PackageFullName = r.PackageFullName,
                PackageFamilyName = r.PackageFamilyName ?? "",
                Kind = system || microsoft ? ProgramKind.WindowsApp : ProgramKind.StoreApp,
                IsLocked = system,
                // Unsichtbare Systempakete (ohne Eintrag im Startmenü) zählen wie Systemkomponenten.
                IsSystemComponent = !visible,
                DisplayIcon = logo,
            };
            try { if (Directory.Exists(loc)) p.InstallDate = Directory.GetCreationTime(loc); } catch { }
            yield return p;
        }
    }

    private static readonly string[] PreinstalledIds =
        { "Clipchamp.", "MicrosoftCorporationII.", "MicrosoftWindows.", "Microsoft.", "MSTeams" };

    private static string PublisherDisplay(string publisher)
    {
        var m = Regex.Match(publisher, @"(?:^|,\s*)O=([^,]+)");
        if (m.Success) return m.Groups[1].Value.Trim('"');
        m = Regex.Match(publisher, @"CN=([^,]+)");
        var cn = m.Success ? m.Groups[1].Value : publisher;
        return Guid.TryParse(cn, out _) ? "" : cn;
    }

    private static (string display, string logo, bool visible, string description) ReadManifest(string loc, string fullName, string name)
    {
        try
        {
            var file = Path.Combine(loc, "AppxManifest.xml");
            if (!File.Exists(file)) return (name, "", false, "");
            var doc = XDocument.Load(file);
            XNamespace? ns = doc.Root?.Name.Namespace;
            var props = doc.Root?.Elements().FirstOrDefault(e => e.Name.LocalName == "Properties");
            string display = props?.Elements().FirstOrDefault(e => e.Name.LocalName == "DisplayName")?.Value ?? name;
            string logo = props?.Elements().FirstOrDefault(e => e.Name.LocalName == "Logo")?.Value ?? "";
            display = ResolveResource(display, fullName, name);
            if (display.Length == 0 || display.StartsWith("ms-resource", StringComparison.OrdinalIgnoreCase)) display = name;

            // Sichtbar = mindestens eine App ohne AppListEntry="none"
            var apps = doc.Descendants().Where(e => e.Name.LocalName == "Application").ToList();
            bool visible = apps.Any(a =>
                !a.Descendants().Any(v => v.Name.LocalName == "VisualElements" &&
                                          string.Equals(v.Attribute("AppListEntry")?.Value, "none", StringComparison.OrdinalIgnoreCase)));
            return (display, ResolveLogo(loc, logo), visible, "");
        }
        catch { return (name, "", false, ""); }
    }

    private static string ResolveResource(string value, string fullName, string name)
    {
        if (!value.StartsWith("ms-resource:", StringComparison.OrdinalIgnoreCase)) return value;
        var res = value["ms-resource:".Length..];
        var candidates = res.StartsWith("//")
            ? new[] { "ms-resource:" + res }
            : new[] { $"ms-resource://{name}/resources/{res}", $"ms-resource://{name}/{res}", $"ms-resource:///Resources/{res}", "ms-resource:" + res };
        foreach (var c in candidates)
        {
            var sb = new StringBuilder(512);
            if (SHLoadIndirectString("@{" + fullName + "?" + c + "}", sb, sb.Capacity, IntPtr.Zero) == 0 && sb.Length > 0)
                return sb.ToString();
        }
        return value;
    }

    private static string ResolveLogo(string loc, string logo)
    {
        if (string.IsNullOrWhiteSpace(logo)) return "";
        var full = Path.Combine(loc, logo);
        if (File.Exists(full)) return full;
        var dir = Path.GetDirectoryName(full);
        if (dir == null || !Directory.Exists(dir)) return "";
        var baseName = Path.GetFileNameWithoutExtension(full);
        var ext = Path.GetExtension(full);
        var files = Directory.GetFiles(dir, baseName + ".*" + ext);
        return files.OrderBy(f => f.Contains("scale-100") ? 0 : f.Contains("scale-200") ? 1 : 2).FirstOrDefault() ?? "";
    }

    internal static string RunPowerShell(string script, int timeoutMs)
    {
        // Ausgabe als UTF-8 erzwingen (sonst gehen Umlaute in App-Namen verloren)
        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand " +
            Convert.ToBase64String(Encoding.Unicode.GetBytes("[Console]::OutputEncoding=[Text.Encoding]::UTF8;" + script)))
        {
            CreateNoWindow = true, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
        };
        using var p = Process.Start(psi)!;
        var outTask = p.StandardOutput.ReadToEndAsync();
        var errTask = p.StandardError.ReadToEndAsync();
        if (!p.WaitForExit(timeoutMs)) { try { p.Kill(true); } catch { } throw new TimeoutException("PowerShell hat nicht geantwortet."); }
        var err = errTask.Result;
        if (p.ExitCode != 0 && !string.IsNullOrWhiteSpace(err)) throw new InvalidOperationException(err.Trim());
        return outTask.Result;
    }

    // ───────────── Launcher-Spiele ─────────────

    public IEnumerable<InstalledProgram> ReadSteam()
    {
        var steam = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam")?.GetValue("SteamPath") as string;
        if (string.IsNullOrEmpty(steam)) yield break;
        steam = steam.Replace('/', '\\');
        var vdf = Path.Combine(steam, "steamapps", "libraryfolders.vdf");
        var libs = new List<string> { steam };
        if (File.Exists(vdf))
            foreach (Match m in Regex.Matches(File.ReadAllText(vdf), "\"path\"\\s+\"([^\"]+)\""))
                libs.Add(m.Groups[1].Value.Replace(@"\\", @"\"));
        foreach (var lib in libs.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var apps = Path.Combine(lib, "steamapps");
            if (!Directory.Exists(apps)) continue;
            foreach (var acf in Directory.GetFiles(apps, "appmanifest_*.acf"))
            {
                var t = File.ReadAllText(acf);
                string V(string key) => Regex.Match(t, $"\"{key}\"\\s+\"([^\"]*)\"", RegexOptions.IgnoreCase).Groups[1].Value;
                var id = V("appid");
                if (id == "228980") continue; // Steamworks Common Redistributables
                var name = V("name");
                if (string.IsNullOrEmpty(name)) continue;
                var dir = Path.Combine(apps, "common", V("installdir"));
                var p = new InstalledProgram
                {
                    Id = "steam:" + id, Name = name, Kind = ProgramKind.Spiel, Launcher = "Steam", Publisher = "",
                    InstallLocation = dir, LauncherUri = $"steam://uninstall/{id}",
                    LauncherHint = "Steam fragt nach einer Bestätigung und deinstalliert dann.",
                };
                if (long.TryParse(V("SizeOnDisk"), out var size) && size > 0) { p.Size = size; p.RegistrySize = size; }
                if (long.TryParse(V("LastUpdated"), out var ts) && ts > 0) p.InstallDate = DateTimeOffset.FromUnixTimeSeconds(ts).LocalDateTime;
                var icon = Path.Combine(steam, "appcache", "librarycache", id + "_icon.jpg");
                p.DisplayIcon = File.Exists(icon) ? icon : "";
                yield return p;
            }
        }
    }

    public IEnumerable<InstalledProgram> ReadEpic()
    {
        var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "Epic", "EpicGamesLauncher", "Data", "Manifests");
        if (!Directory.Exists(dir)) yield break;
        foreach (var f in Directory.GetFiles(dir, "*.item"))
        {
            JsonElement root;
            try { root = JsonDocument.Parse(File.ReadAllText(f)).RootElement; } catch { continue; }
            string S(string k) => root.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";
            var name = S("DisplayName");
            if (name.Length == 0) continue;
            var p = new InstalledProgram
            {
                Id = "epic:" + S("AppName"), Name = name, Version = S("AppVersionString"), Kind = ProgramKind.Spiel, Launcher = "Epic",
                InstallLocation = S("InstallLocation").Replace('/', '\\'), MainExe = "",
                LauncherUri = "com.epicgames.launcher://store/library",
                LauncherHint = "Im Epic-Launcher: Bibliothek → … beim Spiel → Verwalten → Deinstallieren.",
            };
            if (root.TryGetProperty("InstallSize", out var sz) && sz.TryGetInt64(out var s) && s > 0) { p.Size = s; p.RegistrySize = s; }
            var exe = S("LaunchExecutable");
            if (exe.Length > 0) p.MainExe = Path.Combine(p.InstallLocation, exe.Replace('/', '\\'));
            p.DisplayIcon = p.MainExe;
            try { p.InstallDate = File.GetCreationTime(f); } catch { }
            yield return p;
        }
    }

    public IEnumerable<InstalledProgram> ReadGog()
    {
        using var k = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32).OpenSubKey(@"SOFTWARE\GOG.com\Games");
        if (k == null) yield break;
        foreach (var id in k.GetSubKeyNames())
        {
            using var g = k.OpenSubKey(id);
            var name = g?.GetValue("gameName") as string;
            if (g == null || string.IsNullOrEmpty(name)) continue;
            yield return new InstalledProgram
            {
                Id = "gog:" + id, Name = name, Kind = ProgramKind.Spiel, Launcher = "GOG",
                Version = g.GetValue("ver") as string ?? "", InstallLocation = g.GetValue("path") as string ?? "",
                MainExe = g.GetValue("exe") as string ?? "", DisplayIcon = g.GetValue("exe") as string ?? "",
                LauncherUri = $"goggalaxy://openGameView/{id}",
                LauncherHint = "In GOG Galaxy: Spiel → Einstellungen (Zahnrad) → Installation verwalten → Deinstallieren.",
            };
        }
    }

    public IEnumerable<InstalledProgram> ReadUbisoft()
    {
        using var k = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32).OpenSubKey(@"SOFTWARE\Ubisoft\Launcher\Installs");
        if (k == null) yield break;
        foreach (var id in k.GetSubKeyNames())
        {
            using var g = k.OpenSubKey(id);
            var dir = (g?.GetValue("InstallDir") as string ?? "").Replace('/', '\\').TrimEnd('\\');
            if (dir.Length == 0) continue;
            yield return new InstalledProgram
            {
                Id = "ubisoft:" + id, Name = Path.GetFileName(dir), Kind = ProgramKind.Spiel, Launcher = "Ubisoft",
                InstallLocation = dir, LauncherUri = "uplay://",
                LauncherHint = "Im Ubisoft-Launcher: Bibliothek → Spiel → Eigenschaften → Deinstallieren.",
            };
        }
    }

    /// <summary>Spiele aus Launcher-Dateien mit Registry-Einträgen zusammenführen (keine Doppelten).</summary>
    private static void MergeGames(List<InstalledProgram> list, List<InstalledProgram> games)
    {
        foreach (var g in games)
        {
            var existing = list.FirstOrDefault(p => p.Id == g.Id) ??
                           list.FirstOrDefault(p => p.InstallLocation.Length > 0 && g.InstallLocation.Length > 0 &&
                                                    string.Equals(p.InstallLocation.TrimEnd('\\'), g.InstallLocation.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase));
            if (existing != null)
            {
                // Registry-Eintrag als Spiel des Launchers markieren; bessere Daten übernehmen
                existing.Kind = ProgramKind.Spiel;
                existing.Launcher = g.Launcher;
                if (g.LauncherUri.Length > 0) existing.LauncherUri = g.LauncherUri;
                if (g.LauncherHint.Length > 0) existing.LauncherHint = g.LauncherHint;
                if (existing.Name.Length == 0) existing.Name = g.Name;
                if (existing.Size == null && g.Size != null) { existing.Size = g.Size; existing.RegistrySize = g.RegistrySize; }
                if (existing.InstallLocation.Length == 0) existing.InstallLocation = g.InstallLocation;
                if (existing.DisplayIcon.Length == 0) existing.DisplayIcon = g.DisplayIcon;
                existing.IsOrphaned = false;
                continue;
            }
            // Ubisoft-Ordnernamen nur, wenn kein Registry-Name existiert
            list.Add(g);
        }
    }

    // ───────────── Größe ─────────────

    /// <summary>Ordnergröße (für Einträge ohne EstimatedSize). Bricht bei Systemordnern/Laufwerkswurzeln ab.</summary>
    public static long? FolderSize(string dir, CancellationToken ct)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(dir) || !Directory.Exists(dir)) return null;
            var full = Path.GetFullPath(dir).TrimEnd('\\');
            if (full.Length <= 3) return null; // Laufwerkswurzel
            var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows).TrimEnd('\\');
            if (full.Equals(win, StringComparison.OrdinalIgnoreCase)) return null;
            long sum = 0;
            var opts = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true, AttributesToSkip = FileAttributes.ReparsePoint };
            foreach (var f in new DirectoryInfo(full).EnumerateFiles("*", opts))
            {
                ct.ThrowIfCancellationRequested();
                sum += f.Length;
            }
            return sum;
        }
        catch (OperationCanceledException) { throw; }
        catch { return null; }
    }
}
