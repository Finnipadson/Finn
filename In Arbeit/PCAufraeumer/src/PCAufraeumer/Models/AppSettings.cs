namespace PCAufraeumer.Models;

/// <summary>Alle Einstellungen der App. Wird als JSON in %APPDATA%\PCAufraeumer\einstellungen.json gespeichert.</summary>
public sealed class AppSettings
{
    /// <summary>Ordner/Laufwerke, die beim Scan durchsucht werden.</summary>
    public List<string> ScanFolders { get; set; } = new();

    /// <summary>Ordner, die nie angefasst werden (inkl. Unterordner).</summary>
    public List<string> ExcludedFolders { get; set; } = new();

    /// <summary>Einzelne Dateien, die „behalten / nie wieder vorschlagen“ markiert wurden.</summary>
    public List<string> ExceptionFiles { get; set; } = new();

    public bool CategoryVideos { get; set; } = true;
    public bool CategoryDuplicates { get; set; } = true;
    public bool CategoryTemp { get; set; } = true;
    public bool CategoryDownloads { get; set; } = true;

    /// <summary>Videos gelten als „alt“, wenn sie so viele Tage nicht geöffnet wurden. Standard 1 Jahr.</summary>
    public int VideoAgeDays { get; set; } = 365;

    /// <summary>Downloads/Installer gelten als „alt“ ab so vielen Tagen. Standard 6 Monate.</summary>
    public int DownloadAgeDays { get; set; } = 182;

    /// <summary>Optionaler Filter: nur Dateien größer als X MB (0 = aus).</summary>
    public double MinSizeMB { get; set; } = 0;

    /// <summary>Duplikate erst ab dieser Größe (KB) suchen – verhindert, dass tausende Mini-Dateien gehasht werden.</summary>
    public int DuplicateMinKB { get; set; } = 100;

    public bool DarkMode { get; set; } = true;

    /// <summary>NVIDIA-Treiberversion online prüfen (einzige Internetverbindung neben Windows Update).</summary>
    public bool NvidiaOnlineCheck { get; set; } = true;

    /// <summary>„Desktop aufräumen“. Fehlt in alten Einstellungsdateien → Standardwerte.</summary>
    public DesktopSettings Desktop { get; set; } = new();

    /// <summary>„Programme“. Fehlt in alten Einstellungsdateien → Standardwerte.</summary>
    public ProgramSettings Programs { get; set; } = new();
}

public enum LeftoverMode { Sicher, Moderat, Erweitert }

public sealed class ProgramSettings
{
    public LeftoverMode DefaultMode { get; set; } = LeftoverMode.Moderat;
    public bool ShowSystemComponents { get; set; }
    public bool CreateRestorePoint { get; set; } = true;
    /// <summary>Ordner und Registry-Pfade, die nie als Rest vorgeschlagen werden.</summary>
    public List<string> ProtectedPaths { get; set; } = new();
    /// <summary>Ordner für Installationsaufzeichnungen (leer = %APPDATA%\PCAufraeumer\Aufzeichnungen).</summary>
    public string RecordingsFolder { get; set; } = "";
    public bool WatchNewInstalls { get; set; }
    /// <summary>Programmliste nach Kategorie gruppieren.</summary>
    public bool GroupByCategory { get; set; }
}
