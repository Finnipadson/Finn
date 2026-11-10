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
}
