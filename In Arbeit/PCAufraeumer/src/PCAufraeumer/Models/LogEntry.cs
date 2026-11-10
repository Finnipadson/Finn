namespace PCAufraeumer.Models;

/// <summary>Ein Eintrag im Löschprotokoll.</summary>
public sealed class DeleteLogEntry
{
    public DateTime Timestamp { get; set; }
    public string Path { get; set; } = "";
    public long Size { get; set; }
    /// <summary>"Papierkorb" oder "Direkt gelöscht (Temp/Cache)".</summary>
    public string Method { get; set; } = "";
    public string Category { get; set; } = "";
    public bool Success { get; set; }
    public string? Error { get; set; }
}

/// <summary>Gespeicherte Ergebnisliste – kann später ohne neuen Scan weiterbearbeitet werden.</summary>
public sealed class SavedScanResult
{
    public int Version { get; set; } = 1;
    public DateTime ScanDate { get; set; }
    public List<string> ScannedFolders { get; set; } = new();
    public List<FileCandidate> Candidates { get; set; } = new();
    public List<TempTarget> TempTargets { get; set; } = new();
    public string LastAccessInfo { get; set; } = "";
}

public sealed class ScanProgress
{
    public string Phase { get; init; } = "";
    public string CurrentPath { get; init; } = "";
    public double Percent { get; init; } = -1; // -1 = unbestimmt
    public long FilesSeen { get; init; }
    public int Found { get; init; }
}
