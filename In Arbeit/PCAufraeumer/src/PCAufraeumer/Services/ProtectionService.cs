namespace PCAufraeumer.Services;

/// <summary>
/// Zentrale Schutzprüfung. JEDER Fund und JEDE Löschung läuft hier durch.
/// Geschützte Orte werden nie als löschbar vorgeschlagen.
/// </summary>
public sealed class ProtectionService
{
    // Cloud-Attribute (OneDrive „Nur online verfügbar“). FileAttributes kennt nicht alle davon als Namen.
    public const FileAttributes RecallOnOpen = (FileAttributes)0x00040000;
    public const FileAttributes RecallOnDataAccess = (FileAttributes)0x00400000;
    public const FileAttributes CloudOnlyMask = FileAttributes.Offline | RecallOnOpen | RecallOnDataAccess;

    private readonly List<string> _protectedRoots;
    private readonly List<string> _allowedCacheRoots = new();
    private readonly Func<IReadOnlyList<string>> _userExclusions;

    /// <summary>Ordnernamen, die überall übersprungen werden (Programm-, Spiele- und Entwicklerordner).</summary>
    public static readonly HashSet<string> ProtectedFolderNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "$Recycle.Bin", "System Volume Information", "Recovery", "$WinREAgent", "Config.Msi",
        "WindowsApps", "steamapps", "SteamLibrary", "Epic Games", "XboxGames", "GOG Games", "Riot Games",
        "Battle.net", "EA Games", "Ubisoft Game Launcher",
        ".git", ".svn", ".hg", "node_modules", ".vs", "__pycache__",
    };

    public ProtectionService(Func<IReadOnlyList<string>> userExclusions)
    {
        _userExclusions = userExclusions;
        _protectedRoots = new List<string>();
        void Add(string? p) { if (!string.IsNullOrWhiteSpace(p)) _protectedRoots.Add(Normalize(p)); }

        Add(Environment.GetFolderPath(Environment.SpecialFolder.Windows));
        Add(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles));
        Add(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86));
        Add(Environment.GetEnvironmentVariable("ProgramW6432"));
        Add(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData)); // C:\ProgramData
        // Programmdaten im Benutzerprofil: Apps legen dort absichtlich Kopien ab – nie im Dateiscan vorschlagen.
        Add(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData));
        Add(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData));
        Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "AppData"));
        // Feste Pfade zusätzlich, falls Umgebungsvariablen umgebogen sind.
        Add(@"C:\Windows");
        Add(@"C:\Program Files");
        Add(@"C:\Program Files (x86)");
        Add(@"C:\ProgramData");
    }

    public IReadOnlyList<string> ProtectedRoots => _protectedRoots;

    /// <summary>Bekannte Cache-Pfade (nur für den Temp/Cache-Bereich), die innerhalb geschützter Orte liegen dürfen.</summary>
    public void AllowCacheRoot(string path) => _allowedCacheRoots.Add(Normalize(path));

    public static string Normalize(string path)
    {
        try { path = Path.GetFullPath(path); } catch { /* ungültig – unverändert vergleichen */ }
        return path.TrimEnd('\\', '/') + "\\";
    }

    public static bool IsUnder(string path, string root) =>
        Normalize(path).StartsWith(Normalize(root), StringComparison.OrdinalIgnoreCase);

    public bool IsUserExcluded(string path) => _userExclusions().Any(ex => IsUnder(path, ex));

    /// <summary>Liegt der Pfad in einem fest geschützten Bereich oder in einem ausgeschlossenen Ordner?</summary>
    public bool IsProtectedPath(string path, bool allowKnownCache = false)
    {
        if (allowKnownCache && _allowedCacheRoots.Any(r => IsUnder(path, r))) return false;
        if (_protectedRoots.Any(r => IsUnder(path, r))) return true;
        if (IsUserExcluded(path)) return true;
        var parts = path.Split('\\', '/', StringSplitOptions.RemoveEmptyEntries);
        return parts.Any(ProtectedFolderNames.Contains);
    }

    public static bool IsCloudOnly(FileAttributes a) => (a & CloudOnlyMask) != 0;

    public static bool IsSystemFile(FileAttributes a) => (a & FileAttributes.System) != 0;

    public static bool IsHiddenSystem(FileAttributes a) =>
        (a & FileAttributes.System) != 0 && (a & FileAttributes.Hidden) != 0;

    /// <summary>Ist die Datei gerade geöffnet/gesperrt? (Öffnet nur den Handle, liest keine Daten.)</summary>
    public static bool IsLocked(string path)
    {
        try
        {
            using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None, 1, FileOptions.None);
            return false;
        }
        catch (FileNotFoundException) { return false; }
        catch (DirectoryNotFoundException) { return false; }
        catch (IOException) { return true; }
        catch (UnauthorizedAccessException) { return true; }
    }

    /// <summary>
    /// Komplettprüfung einer einzelnen Datei für Funde und Löschungen.
    /// Gibt null zurück, wenn die Datei verwendet werden darf, sonst den Grund.
    /// </summary>
    public string? CheckFile(string path, bool checkLock, bool allowKnownCache = false)
    {
        FileAttributes attrs;
        try { attrs = File.GetAttributes(path); }
        catch (FileNotFoundException) { return "Datei existiert nicht mehr"; }
        catch (DirectoryNotFoundException) { return "Datei existiert nicht mehr"; }
        catch (Exception ex) { return "Kein Zugriff: " + ex.Message; }

        if ((attrs & FileAttributes.Directory) != 0) return "Ist ein Ordner";
        if (IsProtectedPath(path, allowKnownCache)) return "Geschützter Ort";
        if (IsSystemFile(attrs)) return "Systemdatei";
        if (IsCloudOnly(attrs)) return "Nur online verfügbar (OneDrive)";
        if (checkLock && IsLocked(path)) return "Datei ist geöffnet oder gesperrt";
        return null;
    }

    /// <summary>Führt eine Leseaktion aus und setzt danach das „Letzter Zugriff“-Datum zurück,
    /// damit Hashen/Vorschaubilder die Einstufung beim nächsten Scan nicht verfälschen.</summary>
    public static T PreserveAccessTime<T>(string path, Func<T> action)
    {
        DateTime? before = null;
        try { before = File.GetLastAccessTimeUtc(path); } catch { }
        try { return action(); }
        finally
        {
            if (before.HasValue)
            {
                try { File.SetLastAccessTimeUtc(path, before.Value); } catch { /* schreibgeschützt o. ä. – egal */ }
            }
        }
    }
}
