using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace PCAufraeumer.Services;

/// <summary>Ein Ordner, in den ein Aufnahme-Programm Clips speichert.</summary>
/// <param name="Recursive">Unterordner mit durchsuchen (bei Xbox/OBS liegen die Clips direkt im Ordner).</param>
/// <param name="GameFromFolder">Liegt ein Clip in einem Unterordner, ist dessen Name das Spiel (NVIDIA, AMD, Medal …).</param>
public sealed record RecordingFolder(string Path, string Source, bool Recursive, bool GameFromFolder)
{
    public bool IsCustom => Source == "Eigener Ordner";
}

/// <summary>
/// Findet die Aufnahme-Ordner von NVIDIA, Xbox Game Bar, Steam, AMD ReLive, OBS, Medal und SteelSeries Moments
/// und erkennt das Spiel eines Clips. Liest nur.
/// </summary>
public static partial class RecordingSources
{
    /// <summary>Clips in Unterordnern mit diesem Namen werden nie vorgeschlagen.</summary>
    public const string KeepFolderName = "Behalten";
    public const string UnknownGame = "Unbekanntes Spiel";

    /// <summary>Unterordner, die keine Clips enthalten (Vorschaubilder usw.).</summary>
    private static readonly HashSet<string> IgnoredFolders = new(StringComparer.OrdinalIgnoreCase) { "thumbs", "thumbnails", ".thumbs" };

    public static string VideosFolder => Environment.GetFolderPath(Environment.SpecialFolder.MyVideos);

    /// <summary>Alle vorhandenen Aufnahme-Ordner (doppelte entfernt). Eigene Ordner aus den Einstellungen kommen dazu.</summary>
    public static List<RecordingFolder> Detect(IEnumerable<string>? custom = null)
    {
        var list = new List<RecordingFolder>();
        var videos = VideosFolder;
        void Add(string? path, string source, bool recursive = true, bool gameFromFolder = true)
        {
            if (string.IsNullOrWhiteSpace(path)) return;
            try
            {
                path = System.IO.Path.GetFullPath(Environment.ExpandEnvironmentVariables(path.Trim().Trim('"')));
                if (!Directory.Exists(path)) return;
                if (list.Any(r => string.Equals(r.Path.TrimEnd('\\'), path.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))) return;
                list.Add(new RecordingFolder(path, source, recursive, gameFromFolder));
            }
            catch { }
        }

        // NVIDIA (ShadowPlay / NVIDIA App): eigener Pfad in der Registry (UTF-16, binär), sonst Videos\NVIDIA
        Add(NvidiaPath(), "NVIDIA");
        Add(Path.Combine(videos, "NVIDIA"), "NVIDIA");
        // Xbox Game Bar: Videos\Captures, Clips liegen direkt darin („Spiel 2026-01-04 17-32-11.mp4“)
        Add(Path.Combine(videos, "Captures"), "Xbox Game Bar", recursive: false, gameFromFolder: false);
        // AMD ReLive / Adrenalin
        Add(RegString(@"Software\AMD\DVR", "VideoSavePath"), "AMD");
        Add(Path.Combine(videos, "Radeon ReLive"), "AMD");
        // Medal
        Add(Path.Combine(videos, "Medal"), "Medal");
        Add(@"C:\Medal\Clips", "Medal");
        // SteelSeries Moments (Unterordner sind „Exported Clips“ usw., kein Spielname)
        Add(Path.Combine(videos, "SteelSeries Moments"), "SteelSeries Moments", gameFromFolder: false);
        // OBS: Aufnahmepfad aus jedem Profil
        foreach (var p in ObsPaths()) Add(p, "OBS", recursive: false, gameFromFolder: false);
        // Steam: Spielaufnahmen je Benutzer
        foreach (var p in SteamRecordingPaths()) Add(p, "Steam", gameFromFolder: false);
        // Eigene Ordner
        if (custom != null) foreach (var c in custom) Add(c, "Eigener Ordner");
        return list;
    }

    private static string? NvidiaPath()
    {
        try
        {
            using var k = Registry.CurrentUser.OpenSubKey(@"Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS");
            if (k?.GetValue("DefaultPathW") is byte[] b && b.Length > 2)
                return Encoding.Unicode.GetString(b).TrimEnd('\0');
        }
        catch { }
        return null;
    }

    private static string? RegString(string key, string value)
    {
        try
        {
            using var k = Registry.CurrentUser.OpenSubKey(key);
            return k?.GetValue(value) as string;
        }
        catch { return null; }
    }

    private static IEnumerable<string> ObsPaths()
    {
        var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "obs-studio", "basic", "profiles");
        if (!Directory.Exists(dir)) yield break;
        foreach (var ini in SafeFiles(dir, "basic.ini"))
        {
            string[] lines;
            try { lines = File.ReadAllLines(ini); } catch { continue; }
            foreach (var l in lines)
            {
                if (l.StartsWith("FilePath=", StringComparison.OrdinalIgnoreCase)) yield return l[9..];
                else if (l.StartsWith("RecFilePath=", StringComparison.OrdinalIgnoreCase)) yield return l[12..];
            }
        }
    }

    private static IEnumerable<string> SafeFiles(string dir, string name)
    {
        try { return Directory.EnumerateFiles(dir, name, SearchOption.AllDirectories).ToList(); }
        catch { return Array.Empty<string>(); }
    }

    public static string? SteamPath() => RegString(@"Software\Valve\Steam", "SteamPath")?.Replace('/', '\\');

    private static IEnumerable<string> SteamRecordingPaths()
    {
        var steam = SteamPath();
        if (steam == null) yield break;
        var userdata = Path.Combine(steam, "userdata");
        if (!Directory.Exists(userdata)) yield break;
        string[] users;
        try { users = Directory.GetDirectories(userdata); } catch { yield break; }
        foreach (var u in users)
        {
            // Steam speichert Clips intern als viele Bruchstücke (.m4s) – nur Ordner mit echten Videodateien (z. B. Exporte) zählen.
            var p = Path.Combine(u, "gamerecordings");
            if (ContainsVideo(p)) yield return p;
        }
    }

    private static bool ContainsVideo(string dir)
    {
        try
        {
            return Directory.Exists(dir) && Directory.EnumerateFiles(dir, "*", new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true })
                .Any(f => ScanService.VideoExtensions.Contains(Path.GetExtension(f)));
        }
        catch { return false; }
    }

    /// <summary>Clip liegt in einem „Behalten“-Ordner (oder darunter)?</summary>
    public static bool IsInKeepFolder(string root, string file)
    {
        var rel = Path.GetRelativePath(root, Path.GetDirectoryName(file) ?? root);
        if (rel == "." || rel.StartsWith("..")) return false;
        return rel.Split('\\').Any(s => string.Equals(s, KeepFolderName, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>Gehört der Clip zu diesem Ordner (Unterordner nur, wenn rekursiv; Vorschaubild-Ordner nie)?</summary>
    public static bool Belongs(RecordingFolder f, string file)
    {
        var dir = Path.GetDirectoryName(file) ?? "";
        if (!ProtectionService.IsUnder(dir, f.Path)) return false;
        var rel = Path.GetRelativePath(f.Path, dir);
        if (rel == ".") return true;
        if (!f.Recursive) return false;
        return !rel.Split('\\').Any(IgnoredFolders.Contains);
    }

    /// <summary>Spielname: Unterordner (bei NVIDIA/AMD/Medal), sonst aus dem Dateinamen, sonst „Unbekanntes Spiel“.</summary>
    public static string GameFor(RecordingFolder f, string file, Func<string, string?>? steamAppName = null)
    {
        var dir = Path.GetDirectoryName(file) ?? "";
        var rel = Path.GetRelativePath(f.Path, dir);
        if (f.Source == "Steam" && steamAppName != null)
        {
            var m = SteamAppId().Match(file);
            if (m.Success && steamAppName(m.Groups[1].Value) is { Length: > 0 } n) return Clean(n);
        }
        if (f.GameFromFolder && rel != "." && !rel.StartsWith(".."))
        {
            var first = rel.Split('\\')[0];
            if (!string.Equals(first, KeepFolderName, StringComparison.OrdinalIgnoreCase)) return Clean(first);
        }
        return GameFromFileName(Path.GetFileNameWithoutExtension(file));
    }

    /// <summary>„Apex Legends 2026.01.04 - 17.32.11.02.DVR“ → „Apex Legends“, „Fortnite 2026-01-04 17-32-11“ → „Fortnite“.</summary>
    public static string GameFromFileName(string name)
    {
        var m = DatePart().Match(name);
        var game = m.Success ? name[..m.Index] : "";
        game = game.Trim(' ', '_', '-', '.', '(');
        return game.Length == 0 ? UnknownGame : Clean(game);
    }

    /// <summary>Doppelte Leerzeichen zusammenfassen („Call of Duty  Black Ops 7“ = „Call of Duty Black Ops 7“).</summary>
    private static string Clean(string s) => Spaces().Replace(s.Trim(), " ");

    [GeneratedRegex(@"\d{4}[.\-_]\d{2}[.\-_]\d{2}")]
    private static partial Regex DatePart();

    [GeneratedRegex(@"\s{2,}")]
    private static partial Regex Spaces();

    [GeneratedRegex(@"(?:clip|bg|timeline)_(\d+)_", RegexOptions.IgnoreCase)]
    private static partial Regex SteamAppId();

    /// <summary>Steam-Spielnamen aus den appmanifest-Dateien aller Bibliotheken (appid → Name).</summary>
    public static Dictionary<string, string> SteamAppNames()
    {
        var map = new Dictionary<string, string>();
        var steam = SteamPath();
        if (steam == null) return map;
        var libs = new List<string> { Path.Combine(steam, "steamapps") };
        try
        {
            var vdf = Path.Combine(steam, "steamapps", "libraryfolders.vdf");
            if (File.Exists(vdf))
                foreach (Match m in Regex.Matches(File.ReadAllText(vdf), "\"path\"\\s+\"([^\"]+)\""))
                    libs.Add(Path.Combine(m.Groups[1].Value.Replace(@"\\", @"\"), "steamapps"));
        }
        catch { }
        foreach (var lib in libs.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (!Directory.Exists(lib)) continue;
            foreach (var acf in Directory.EnumerateFiles(lib, "appmanifest_*.acf"))
            {
                try
                {
                    var text = File.ReadAllText(acf);
                    var id = Regex.Match(text, "\"appid\"\\s+\"(\\d+)\"").Groups[1].Value;
                    var name = Regex.Match(text, "\"name\"\\s+\"([^\"]+)\"").Groups[1].Value;
                    if (id.Length > 0 && name.Length > 0) map[id] = name;
                }
                catch { }
            }
        }
        return map;
    }
}
