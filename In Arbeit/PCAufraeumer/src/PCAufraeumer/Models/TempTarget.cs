using System.Text.Json.Serialization;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Models;

/// <summary>Ein Temp-/Cache-Bereich (z. B. Chrome-Cache). Wird als eigener Bereich angezeigt und direkt (nicht Papierkorb) geleert.</summary>
public sealed partial class TempTarget : ObservableObject
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public List<string> Paths { get; set; } = new();

    /// <summary>Nur Dateinamen, die auf dieses Muster passen (z. B. thumbcache_*.db). Leer = alles.</summary>
    public string FilePattern { get; set; } = "*";

    /// <summary>Nur Dateien, die älter als so viele Stunden sind (Schutz für laufende Programme).</summary>
    public int MinAgeHours { get; set; }

    public bool RequiresAdmin { get; set; }

    /// <summary>Prozessname des Browsers (ohne .exe). Läuft er, darf der Cache nicht geleert werden.</summary>
    public string? BrowserProcess { get; set; }

    public long Size { get; set; }
    public int FileCount { get; set; }
    public bool Incomplete { get; set; }

    [ObservableProperty] private bool _isSelected;
    [ObservableProperty] private bool _browserRunning;
    [ObservableProperty] private string _status = "";

    [JsonIgnore] public bool CanSelect => !BrowserRunning && FileCount > 0;

    partial void OnBrowserRunningChanged(bool value)
    {
        if (value) IsSelected = false;
        OnPropertyChanged(nameof(CanSelect));
    }
}
