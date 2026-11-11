using System.Text.Json.Serialization;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Models;

public enum ProgramKind { Programm, StoreApp, WindowsApp, Spiel }

/// <summary>Ein installiertes Programm, eine App oder ein Launcher-Spiel.</summary>
public sealed partial class InstalledProgram : ObservableObject
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Version { get; set; } = "";
    public string Publisher { get; set; } = "";
    public DateTime? InstallDate { get; set; }
    public ProgramKind Kind { get; set; }
    /// <summary>Launcher bei Spielen (Steam, Epic, GOG, EA, Ubisoft, Battle.net).</summary>
    public string Launcher { get; set; } = "";
    public string InstallLocation { get; set; } = "";
    public string UninstallString { get; set; } = "";
    public string QuietUninstallString { get; set; } = "";
    /// <summary>MSI-Produktcode {GUID}, falls vorhanden.</summary>
    public string ProductCode { get; set; } = "";
    /// <summary>Voller Registry-Pfad des Uninstall-Eintrags (z. B. HKEY_LOCAL_MACHINE\SOFTWARE\…\Uninstall\Xyz).</summary>
    public string RegistryPath { get; set; } = "";
    public string DisplayIcon { get; set; } = "";
    /// <summary>Haupt-.exe (für Kategorie, Restesuche, Desktop-Zuordnung).</summary>
    public string MainExe { get; set; } = "";
    public bool IsSystemComponent { get; set; }
    public bool IsUpdate { get; set; }
    public bool HasParent { get; set; }
    /// <summary>Von Windows als nicht entfernbar gekennzeichnet → gesperrt.</summary>
    public bool IsLocked { get; set; }
    public string PackageFullName { get; set; } = "";
    public string PackageFamilyName { get; set; } = "";
    /// <summary>Launcher-Adresse zum Deinstallieren/Öffnen (steam://uninstall/… usw.).</summary>
    public string LauncherUri { get; set; } = "";
    public string LauncherHint { get; set; } = "";
    public bool IsOrphaned { get; set; }
    public long? RegistrySize { get; set; }

    [ObservableProperty] private long? _size;
    [ObservableProperty] private bool _sizeIsEstimate;
    [ObservableProperty] private bool _isChecked;
    [ObservableProperty] private string _category = "";
    [ObservableProperty] private bool _isRecorded;
    [JsonIgnore] public ImageSource? Icon { get => _icon; set => SetProperty(ref _icon, value); }
    private ImageSource? _icon;

    public string TypeLabel => Kind switch
    {
        ProgramKind.Spiel => $"Spiel ({Launcher})",
        ProgramKind.StoreApp => "Store-App",
        ProgramKind.WindowsApp => "Windows-App",
        _ => "Programm",
    };

    public bool HiddenByDefault => IsSystemComponent || IsUpdate || HasParent;
    public bool IsMachineWide => RegistryPath.StartsWith("HKEY_LOCAL_MACHINE", StringComparison.OrdinalIgnoreCase);
    public string InstallDateText => InstallDate?.ToString("dd.MM.yyyy") ?? "";
    public string StatusIcons =>
        (IsLocked ? "🔒 " : "") + (IsRecorded ? "⏺ " : "") + (IsOrphaned ? "⚠ " : "");

    partial void OnIsCheckedChanged(bool value) { if (value && IsLocked) IsChecked = false; }
    partial void OnIsRecordedChanged(bool value) => OnPropertyChanged(nameof(StatusIcons));
}
