using System.Text.Json.Serialization;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Models;

public enum FindingCategory
{
    Videos,
    Duplicates,
    Downloads,
}

public enum DateBasis
{
    LastAccess,
    LastWrite,
    Created,
}

/// <summary>Ein Fund aus dem Dateiscan (Video, Duplikat oder alter Download).</summary>
public sealed partial class FileCandidate : ObservableObject
{
    public string FullPath { get; set; } = "";
    public string Name { get; set; } = "";
    public string Directory { get; set; } = "";
    public long Size { get; set; }
    public string Extension { get; set; } = "";
    public string TypeLabel { get; set; } = "";
    public DateTime LastAccess { get; set; }
    public DateTime LastWrite { get; set; }
    public DateTime Created { get; set; }
    public FindingCategory Category { get; set; }
    public string Reason { get; set; } = "";

    /// <summary>Welches Datum für die Einstufung verwendet wurde (immer in der Liste sichtbar).</summary>
    public DateBasis Basis { get; set; }

    /// <summary>Gruppen-ID bei Duplikaten (gleicher Inhalt).</summary>
    public int GroupId { get; set; }
    public string Hash { get; set; } = "";

    /// <summary>Freigabe zum Löschen. Standard: NICHT ausgewählt.</summary>
    [ObservableProperty] private bool _isSelected;

    /// <summary>Bei Duplikaten: diese Kopie wird behalten (kann nicht ausgewählt werden).</summary>
    [ObservableProperty] private bool _isKeep;

    /// <summary>Wurde in dieser Sitzung bereits gelöscht.</summary>
    [ObservableProperty] private bool _isDeleted;

    [JsonIgnore] public ImageSource? Thumbnail { get => _thumb; set => SetProperty(ref _thumb, value); }
    private ImageSource? _thumb;
    [JsonIgnore] public bool ThumbnailRequested { get; set; }

    [JsonIgnore] public string CategoryLabel => Category switch
    {
        FindingCategory.Videos => "Alte Videos/Clips",
        FindingCategory.Duplicates => "Doppelte Dateien",
        FindingCategory.Downloads => "Alte Downloads/Installer",
        _ => "",
    };

    [JsonIgnore] public string BasisLabel => Basis switch
    {
        DateBasis.LastAccess => "letzter Zugriff",
        DateBasis.LastWrite => "Änderungsdatum",
        DateBasis.Created => "Download-Datum",
        _ => "",
    };

    [JsonIgnore] public string GroupLabel => Category == FindingCategory.Duplicates
        ? $"{CategoryLabel} · Gruppe {GroupId}"
        : CategoryLabel;

    [JsonIgnore] public bool CanSelect => !IsKeep && !IsDeleted;

    partial void OnIsKeepChanged(bool value)
    {
        if (value) IsSelected = false;
        OnPropertyChanged(nameof(CanSelect));
    }

    partial void OnIsDeletedChanged(bool value)
    {
        if (value) IsSelected = false;
        OnPropertyChanged(nameof(CanSelect));
    }

    /// <summary>Sicherheitsnetz: Die behaltene Kopie bzw. bereits gelöschte Dateien können nie ausgewählt werden.</summary>
    partial void OnIsSelectedChanged(bool value)
    {
        if (value && (IsKeep || IsDeleted)) IsSelected = false;
    }
}
