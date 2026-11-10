using System.Text.Json.Serialization;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Models;

public enum DesktopItemKind { AppIcon, File, Folder, System }

/// <summary>Anordnungs-Vorschläge für die App-Symbole.</summary>
public enum DesktopLayout { Spalten, Kompakt, Zeilen, Bloecke, Raender }

public sealed record LayoutOption(DesktopLayout Layout, string Name, string Description);

public static class LayoutOptions
{
    public static readonly IReadOnlyList<LayoutOption> All = new[]
    {
        new LayoutOption(DesktopLayout.Spalten, "Spalten", "Jede Kategorie in eigenen Spalten, von links nach rechts, mit Abstand dazwischen."),
        new LayoutOption(DesktopLayout.Kompakt, "Kompakt", "Alles dicht am linken Rand, Kategorien folgen direkt aufeinander – maximal viel freie Fläche."),
        new LayoutOption(DesktopLayout.Zeilen, "Zeilen", "Jede Kategorie als waagerechte Reihe oben am Bildschirm, eine unter der anderen."),
        new LayoutOption(DesktopLayout.Bloecke, "Blöcke", "Jede Kategorie als kleiner, fast quadratischer Block – wie Kacheln."),
        new LayoutOption(DesktopLayout.Raender, "Ränder", "Apps links, Ordner ganz rechts – die Mitte bleibt frei fürs Hintergrundbild."),
    };
}

/// <summary>Regel „Programm → Kategorie“: Muster wird (ohne Groß/Klein) in Ziel, Programmname, Hersteller, URL und Symbolname gesucht.</summary>
public sealed partial class AppRule : ObservableObject
{
    [ObservableProperty] private string _pattern = "";
    [ObservableProperty] private string _category = "";
    public AppRule() { }
    public AppRule(string pattern, string category) { _pattern = pattern; _category = category; }
}

/// <summary>Regel „Dateityp → Ordner“.</summary>
public sealed partial class FolderRule : ObservableObject
{
    [ObservableProperty] private string _folder = "";
    /// <summary>Endungen, durch Leerzeichen/Komma getrennt, z. B. ".jpg .png".</summary>
    [ObservableProperty] private string _extensions = "";
    /// <summary>Optional: Dateiname beginnt mit … (z. B. „Screenshot“). Getrennt durch „;“.</summary>
    [ObservableProperty] private string _namePrefixes = "";
    /// <summary>Andere Namen, unter denen ein vorhandener Ordner erkannt wird (z. B. „Fotos;Pictures“).</summary>
    [ObservableProperty] private string _aliases = "";
    public FolderRule() { }
    public FolderRule(string folder, string ext, string prefixes = "", string aliases = "")
    { _folder = folder; _extensions = ext; _namePrefixes = prefixes; _aliases = aliases; }

    public IEnumerable<string> ExtensionList() =>
        Extensions.Split(new[] { ' ', ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(e => e.StartsWith('.') ? e.ToLowerInvariant() : "." + e.ToLowerInvariant());
    public IEnumerable<string> PrefixList() => NamePrefixes.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    public IEnumerable<string> AliasList() => Aliases.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

/// <summary>Einstellungen für „Desktop aufräumen“ (Teil von einstellungen.json, fehlt in alten Dateien → Standardwerte).</summary>
public sealed class DesktopSettings
{
    public const string Fallback = "Sonstiges";

    public List<string> Categories { get; set; } = DefaultCategories();
    public List<AppRule> AppRules { get; set; } = DefaultAppRules();
    public List<FolderRule> FolderRules { get; set; } = DefaultFolderRules();
    /// <summary>Elemente, die nie angefasst werden (Name wie auf dem Desktop oder voller Pfad).</summary>
    public List<string> NeverTouch { get; set; } = new();
    /// <summary>Gemerkte Zuordnungen aus der Vorschau: Dateiname des Symbols → Kategorie.</summary>
    public Dictionary<string, string> IconOverrides { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    /// <summary>Symbole auf Nebenmonitoren ebenfalls auf den Hauptmonitor holen.</summary>
    public bool AllOnPrimary { get; set; }
    /// <summary>Leere Spalten zwischen den Kategorie-Gruppen.</summary>
    public int GapColumns { get; set; } = 1;
    /// <summary>Zuletzt gewählter Anordnungs-Vorschlag.</summary>
    public DesktopLayout Layout { get; set; } = DesktopLayout.Spalten;

    public static List<string> DefaultCategories() => new()
    {
        "Spiele", "Browser & Internet", "Büro & Dokumente", "Kommunikation", "Medien",
        "Kreativ & Bearbeitung", "Entwicklung", "System & Tools", Fallback,
    };

    public static List<AppRule> DefaultAppRules()
    {
        var r = new List<AppRule>();
        void Add(string cat, params string[] patterns) { foreach (var p in patterns) r.Add(new AppRule(p, cat)); }
        // Reihenfolge zählt: die erste passende Regel gewinnt. Allgemeine Web-Links (http/https) stehen deshalb ganz am Ende.
        Add("Spiele", "steam://", "steamapps", "com.epicgames.launcher://", "Epic Games", "\\Steam\\steam.exe", "Riot Client",
            "Riot Games", "Battle.net", "Rockstar Games", "Ubisoft", "uplay://", "EA Desktop", "\\Electronic Arts\\", "origin2://",
            "GOG Galaxy", "goggalaxy://", "link2ea://", "Minecraft", "Lunar Client", "RobloxPlayer", "Roblox Player", "Xbox",
            "\\XboxGames\\", "Aimlabs", "GameSir", "Wallpaper Engine", "itch.io", "Playnite", "Heroic");
        Add("Kommunikation", "Discord", "Teams", "slack", "zoom", "skype", "whatsapp", "telegram", "signal", "thunderbird",
            "outlook", "TikTok", "Instagram", "Messenger", "TeamSpeak", "Mumble", "Wispr");
        Add("Büro & Dokumente", "winword", "excel.exe", "powerpnt", "onenote", "acrobat", "acrord32", "libreoffice", "soffice",
            "notion", "obsidian", "evernote", "\\Microsoft Office\\", ".pdf", ".docx", ".xlsx", ".pptx", "Foxit");
        Add("Medien", "spotify", "vlc", "itunes", "Apple Music", "foobar", "potplayer", "mpc-hc", "plex", "netflix",
            "musicbee", "Media Player", "Photos", "Kodi", "Stremio", "Deezer", "Amazon Music", "YouTube");
        Add("Kreativ & Bearbeitung", "photoshop", "gimp", "blender", "premiere", "after effects", "davinci", "resolve.exe",
            "obs64", "OBS Studio", "paint.net", "krita", "figma", "canva", "illustrator", "lightroom", "inkscape", "audacity",
            "FL Studio", "ableton", "CapCut", "Clipchamp", "Affinity", "Roblox Studio", "RobloxStudio");
        Add("Entwicklung", "\\Microsoft VS Code\\", "Code.exe", "Visual Studio", "devenv.exe", "JetBrains", "rider", "pycharm",
            "intellij", "webstorm", "Android Studio", "git-bash", "Git Bash", "GitHub Desktop", "postman", "docker", "cursor",
            "Unity Hub", "Unreal", "python", "node.js", "sublime", "notepad++", "Claude.exe");
        Add("System & Tools", "cmd.exe", "powershell", "wt.exe", "Terminal", "taskmgr", "control.exe", "regedit", "7-Zip",
            "winrar", "ccleaner", "NVIDIA", "GeForce", "AMD Software", "Radeon", "Logitech", "G HUB", "SteelSeries", "Razer",
            "Corsair", "iCUE", "Afterburner", "HWiNFO", "CPU-Z", "GPU-Z", "Everything", "PC Aufräumer", "PCAufraeumer",
            "AnyDesk", "TeamViewer", "KeePass", "Bitwarden", "1Password", "Rufus", "CrystalDisk", "Revo Uninstaller",
            "DriverHub", "ASUS", "Armoury", "3uTools", "Sideloadly", "VirtualBox", "VMware", "OpenRGB", "Malwarebytes");
        Add("Browser & Internet", "chrome.exe", "firefox.exe", "msedge.exe", "msedge_proxy.exe", "opera.exe", "brave.exe",
            "vivaldi.exe", "librewolf", "\\Tor Browser\\", "arc.exe", "qbittorrent", "filezilla", "http://", "https://");
        return r;
    }

    public static List<FolderRule> DefaultFolderRules() => new()
    {
        new("Screenshots", ".png .jpg .jpeg .bmp .webp", "Screenshot;Bildschirmfoto;Snip;Bildschirmaufnahme;Capture", "Bildschirmfotos"),
        new("Bilder", ".jpg .jpeg .png .gif .bmp .webp .heic .tif .tiff .svg .ico .raw .cr2 .nef .psd", "", "Fotos;Pictures;Images;Photos"),
        new("Videos", ".mp4 .mkv .mov .avi .wmv .webm .flv .m4v .mpg .mpeg", "", "Filme;Clips;Movies"),
        new("Musik", ".mp3 .wav .flac .m4a .aac .ogg .wma .opus", "", "Music;Audio"),
        new("Dokumente", ".pdf .doc .docx .odt .rtf .txt .md .xls .xlsx .ods .csv .ppt .pptx .odp", "", "Documents;Docs;Unterlagen"),
        new("Archive", ".zip .rar .7z .tar .gz .bz2 .xz", "", "Archiv;Zips"),
        new("Installer", ".exe .msi .msix .msixbundle .appx .iso .img", "", "Setups;Setup;Programme"),
        new("Sonstiges", "", "", "Andere;Misc"),
    };
}

/// <summary>Ein Element auf dem Desktop (aktueller Zustand).</summary>
public sealed class DesktopItem
{
    public string Path { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string FileName => System.IO.Path.GetFileName(Path);
    public DesktopItemKind Kind { get; set; }
    public bool IsPublic { get; set; }
    public int X { get; set; }
    public int Y { get; set; }
    /// <summary>Aufgelöstes Ziel/URL einer Verknüpfung (für Anzeige und Kategorie).</summary>
    public string Target { get; set; } = "";
    public string DetectedCategory { get; set; } = "";
    public bool NeverTouch { get; set; }
    public bool Locked { get; set; }
    [JsonIgnore] public ImageSource? Icon { get; set; }
}

public enum DesktopChangeKind { Position, MoveFile }

/// <summary>Eine geplante Änderung in der Vorschau (kann abgewählt/angepasst werden).</summary>
public sealed partial class DesktopChange : ObservableObject
{
    public DesktopItem Item { get; init; } = null!;
    public DesktopChangeKind Kind { get; init; }

    [ObservableProperty] private bool _isEnabled = true;
    /// <summary>Für Symbole: Kategorie-Gruppe. Für Dateien: Name des Zielordners.</summary>
    [ObservableProperty] private string _target = "";
    [ObservableProperty] private string _description = "";
    [ObservableProperty] private string _note = "";
    public bool CanEnable { get; init; } = true;

    // Vom Planer gesetzt
    public string FinalPath { get; set; } = "";
    public bool TargetIsNewFolder { get; set; }

    public string KindLabel => Kind == DesktopChangeKind.MoveFile ? "Datei" : Item.Kind == DesktopItemKind.Folder ? "Ordner" : "Symbol";
    public bool IsFile => Kind == DesktopChangeKind.MoveFile;
    public bool IsAppIcon => Kind == DesktopChangeKind.Position && Item.Kind == DesktopItemKind.AppIcon;
    public IReadOnlyList<string> Options { get; set; } = Array.Empty<string>();

    partial void OnIsEnabledChanged(bool value) { if (value && !CanEnable) IsEnabled = false; }
}

/// <summary>Gespeicherter Zustand vor einer Aufräumaktion – Grundlage für „Rückgängig machen“.</summary>
public sealed class DesktopSnapshot
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public DateTime Date { get; set; } = DateTime.Now;
    public string Description { get; set; } = "";
    public string ViewKind { get; set; } = "Desktop"; // „Desktop“ oder Pfad eines Testordners
    public List<SnapshotPosition> Positions { get; set; } = new();
    public List<SnapshotMove> Moves { get; set; } = new();
    public List<string> CreatedFolders { get; set; } = new();
    public bool Undone { get; set; }
    public DateTime? UndoneDate { get; set; }

    [JsonIgnore] public string Summary =>
        $"{Date:dd.MM.yyyy HH:mm} · {Moves.Count} Dateien verschoben, {CreatedFolders.Count} Ordner neu, {Positions.Count} Symbolpositionen gesichert" +
        (Undone ? $" · rückgängig gemacht am {UndoneDate:dd.MM. HH:mm}" : "");
}

public sealed class SnapshotPosition
{
    public string Path { get; set; } = "";
    public int X { get; set; }
    public int Y { get; set; }
}

public sealed class SnapshotMove
{
    public string From { get; set; } = "";
    public string To { get; set; } = "";
}
