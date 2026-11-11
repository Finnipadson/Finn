using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

public sealed record PeriodOption(string Label, int Days);

/// <summary>Einstellungen – jede Änderung wird sofort in %APPDATA% gespeichert.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsService _svc;
    private bool _loading;

    private static readonly PeriodOption[] VideoPeriodList =
    {
        new PeriodOption("3 Monate", 91), new PeriodOption("6 Monate", 182), new PeriodOption("1 Jahr", 365),
        new PeriodOption("2 Jahre", 730), new PeriodOption("Eigener Wert", -1),
    };

    private static readonly PeriodOption[] DownloadPeriodList =
    {
        new PeriodOption("1 Monat", 30), new PeriodOption("3 Monate", 91), new PeriodOption("6 Monate", 182),
        new PeriodOption("1 Jahr", 365), new PeriodOption("Eigener Wert", -1),
    };

    public IReadOnlyList<PeriodOption> VideoPeriods => VideoPeriodList;
    public IReadOnlyList<PeriodOption> DownloadPeriods => DownloadPeriodList;

    public ObservableCollection<string> ScanFolders { get; } = new();
    public ObservableCollection<string> ExcludedFolders { get; } = new();
    public ObservableCollection<string> ExceptionFiles { get; } = new();
    /// <summary>Selbst hinzugefügte Aufnahme-Ordner.</summary>
    public ObservableCollection<string> RecordingFolders { get; } = new();
    /// <summary>Alle gefundenen Aufnahme-Ordner (automatisch erkannt + eigene) – Anzeige auf der Scan-Seite.</summary>
    public ObservableCollection<RecordingFolder> DetectedRecordingFolders { get; } = new();
    public IReadOnlyList<string> ProtectedRoots { get; }

    [ObservableProperty] private bool _categoryVideos;
    [ObservableProperty] private bool _categoryDuplicates;
    [ObservableProperty] private bool _categoryTemp;
    [ObservableProperty] private bool _categoryDownloads;
    [ObservableProperty] private bool _categoryRecordings;
    [ObservableProperty] private PeriodOption? _videoPeriod;
    [ObservableProperty] private int _videoCustomDays;
    [ObservableProperty] private PeriodOption? _downloadPeriod;
    [ObservableProperty] private int _downloadCustomDays;
    [ObservableProperty] private double _minSizeMB;
    [ObservableProperty] private int _duplicateMinKB;
    [ObservableProperty] private bool _darkMode;
    [ObservableProperty] private bool _nvidiaOnlineCheck;
    [ObservableProperty] private string? _selectedScanFolder;
    [ObservableProperty] private string? _selectedExcludedFolder;
    [ObservableProperty] private string? _selectedException;

    public bool VideoCustom => VideoPeriod?.Days == -1;
    public bool DownloadCustom => DownloadPeriod?.Days == -1;

    public string SettingsPath => AppPaths.SettingsFile;

    public SettingsViewModel(SettingsService svc, ProtectionService protection)
    {
        _svc = svc;
        ProtectedRoots = protection.ProtectedRoots.Distinct(StringComparer.OrdinalIgnoreCase)
            .Concat(new[] { "Systemdateien, versteckte Systemdateien, geöffnete/gesperrte Dateien",
                            "OneDrive-Dateien „Nur online verfügbar“ (werden beim Scan nicht heruntergeladen)",
                            "Programm-, Spiele- und Entwicklerordner (steamapps, Epic Games, WindowsApps, .git, node_modules …)" })
            .ToList();
        Desktop = new DesktopSettingsViewModel(svc);
        Programs = new ProgramSettingsViewModel(svc);
        Reload();
    }

    /// <summary>Bereich „Programme“.</summary>
    public ProgramSettingsViewModel Programs { get; }

    /// <summary>Bereich „Desktop aufräumen“.</summary>
    public DesktopSettingsViewModel Desktop { get; }

    public void Reload()
    {
        _loading = true;
        var s = _svc.Current;
        Replace(ScanFolders, s.ScanFolders);
        Replace(ExcludedFolders, s.ExcludedFolders);
        Replace(ExceptionFiles, s.ExceptionFiles);
        Replace(RecordingFolders, s.RecordingFolders);
        CategoryRecordings = s.CategoryRecordings;
        CategoryVideos = s.CategoryVideos;
        CategoryDuplicates = s.CategoryDuplicates;
        CategoryTemp = s.CategoryTemp;
        CategoryDownloads = s.CategoryDownloads;
        VideoPeriod = VideoPeriods.FirstOrDefault(p => p.Days == s.VideoAgeDays) ?? VideoPeriods[^1];
        VideoCustomDays = s.VideoAgeDays;
        DownloadPeriod = DownloadPeriods.FirstOrDefault(p => p.Days == s.DownloadAgeDays) ?? DownloadPeriods[^1];
        DownloadCustomDays = s.DownloadAgeDays;
        MinSizeMB = s.MinSizeMB;
        DuplicateMinKB = s.DuplicateMinKB;
        DarkMode = s.DarkMode;
        NvidiaOnlineCheck = s.NvidiaOnlineCheck;
        _loading = false;
        RefreshRecordingFolders();
    }

    /// <summary>Aufnahme-Ordner neu ermitteln (NVIDIA, Xbox, Steam, AMD, OBS, Medal, SteelSeries + eigene).</summary>
    public void RefreshRecordingFolders()
    {
        DetectedRecordingFolders.Clear();
        try { foreach (var f in RecordingSources.Detect(RecordingFolders)) DetectedRecordingFolders.Add(f); }
        catch (Exception ex) { ErrorLog.Write("Aufnahme-Ordner konnten nicht ermittelt werden.", ex); }
        OnPropertyChanged(nameof(RecordingFoldersText));
    }

    public string RecordingFoldersText => DetectedRecordingFolders.Count == 0
        ? "Keine Aufnahme-Ordner gefunden."
        : $"{DetectedRecordingFolders.Count} Aufnahme-Ordner gefunden:";

    [RelayCommand]
    private void AddRecordingFolder()
    {
        var f = PickFolder("Ordner mit Spielaufnahmen wählen");
        if (f != null && !RecordingFolders.Contains(f, StringComparer.OrdinalIgnoreCase)) { RecordingFolders.Add(f); Persist(); RefreshRecordingFolders(); }
    }

    [RelayCommand]
    private void RemoveRecordingFolder(string? f)
    {
        if (f != null && RecordingFolders.Remove(RecordingFolders.FirstOrDefault(x => string.Equals(x, f, StringComparison.OrdinalIgnoreCase)) ?? ""))
        { Persist(); RefreshRecordingFolders(); }
    }

    private static void Replace(ObservableCollection<string> target, IEnumerable<string> src)
    {
        target.Clear();
        foreach (var x in src) target.Add(x);
    }

    protected override void OnPropertyChanged(System.ComponentModel.PropertyChangedEventArgs e)
    {
        base.OnPropertyChanged(e);
        if (e.PropertyName is nameof(VideoPeriod)) OnPropertyChanged(nameof(VideoCustom));
        if (e.PropertyName is nameof(DownloadPeriod)) OnPropertyChanged(nameof(DownloadCustom));
        if (_loading || e.PropertyName is null || e.PropertyName.StartsWith("Selected") ||
            e.PropertyName is nameof(VideoCustom) or nameof(DownloadCustom)) return;
        Persist();
    }

    private void Persist()
    {
        var s = _svc.Current;
        s.CategoryVideos = CategoryVideos;
        s.CategoryDuplicates = CategoryDuplicates;
        s.CategoryTemp = CategoryTemp;
        s.CategoryDownloads = CategoryDownloads;
        s.CategoryRecordings = CategoryRecordings;
        s.RecordingFolders = RecordingFolders.ToList();
        s.VideoAgeDays = VideoPeriod is { Days: > 0 } vp ? vp.Days : Math.Clamp(VideoCustomDays, 1, 36500);
        s.DownloadAgeDays = DownloadPeriod is { Days: > 0 } dp ? dp.Days : Math.Clamp(DownloadCustomDays, 1, 36500);
        s.MinSizeMB = Math.Max(0, MinSizeMB);
        s.DuplicateMinKB = Math.Max(1, DuplicateMinKB);
        s.DarkMode = DarkMode;
        s.NvidiaOnlineCheck = NvidiaOnlineCheck;
        s.ScanFolders = ScanFolders.ToList();
        s.ExcludedFolders = ExcludedFolders.ToList();
        s.ExceptionFiles = ExceptionFiles.ToList();
        _svc.Save();
    }

    partial void OnDarkModeChanged(bool value) => ThemeManager.Apply(value);

    public string VideoPeriodText => Describe(_svc.Current.VideoAgeDays);
    public string DownloadPeriodText => Describe(_svc.Current.DownloadAgeDays);

    private static string Describe(int days) => days switch
    {
        91 => "3 Monaten", 182 => "6 Monaten", 365 => "1 Jahr", 730 => "2 Jahren", 30 => "1 Monat",
        _ => $"{days} Tagen",
    };

    private static string? PickFolder(string title)
    {
        var dlg = new OpenFolderDialog { Title = title, Multiselect = false };
        return dlg.ShowDialog() == true ? dlg.FolderName : null;
    }

    [RelayCommand]
    private void AddScanFolder()
    {
        var f = PickFolder("Ordner oder Laufwerk zum Durchsuchen wählen");
        if (f != null && !ScanFolders.Contains(f, StringComparer.OrdinalIgnoreCase)) { ScanFolders.Add(f); Persist(); }
    }

    [RelayCommand]
    private void RemoveScanFolder(string? f)
    {
        f ??= SelectedScanFolder;
        if (f != null && ScanFolders.Remove(f)) Persist();
    }

    [RelayCommand]
    private void AddExcludedFolder()
    {
        var f = PickFolder("Ordner, der nie angefasst werden soll");
        if (f != null && !ExcludedFolders.Contains(f, StringComparer.OrdinalIgnoreCase)) { ExcludedFolders.Add(f); Persist(); }
    }

    [RelayCommand]
    private void RemoveExcludedFolder(string? f)
    {
        f ??= SelectedExcludedFolder;
        if (f != null && ExcludedFolders.Remove(f)) Persist();
    }

    [RelayCommand]
    private void RemoveException(string? f)
    {
        f ??= SelectedException;
        if (f != null && ExceptionFiles.Remove(f)) Persist();
    }

    public void AddException(string path)
    {
        if (!ExceptionFiles.Contains(path, StringComparer.OrdinalIgnoreCase)) { ExceptionFiles.Add(path); Persist(); }
    }

    public void AddExcluded(string path)
    {
        if (!ExcludedFolders.Contains(path, StringComparer.OrdinalIgnoreCase)) { ExcludedFolders.Add(path); Persist(); }
    }

    [RelayCommand]
    private void OpenDataFolder() => Shell.Open(AppPaths.BaseDir);
}
