using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Hauptfenster: Navigation über die Seitenleiste.</summary>
public sealed partial class MainViewModel : ObservableObject
{
    public SettingsService SettingsService { get; } = new();
    public DeleteLogService DeleteLog { get; } = new();
    public LastAccessService LastAccess { get; } = new();
    public ProtectionService Protection { get; }
    public CleanupService Cleanup { get; }
    public ThumbnailService Thumbnails { get; } = new();

    public DashboardViewModel Dashboard { get; }
    public DriversViewModel Drivers { get; }
    public ScanViewModel Scan { get; }
    public ResultsViewModel Results { get; }
    public LogViewModel Log { get; }
    public SettingsViewModel Settings { get; }
    public DesktopViewModel Desktop { get; }

    [ObservableProperty] private object? _currentPage;
    [ObservableProperty] private string _currentKey = "dashboard";
    [ObservableProperty] private bool _isAdmin = TempService.IsAdmin;

    public string AdminText => IsAdmin ? "Läuft mit Adminrechten" : "Läuft ohne Adminrechte";

    public MainViewModel()
    {
        SettingsService.Load();
        Protection = new ProtectionService(() => SettingsService.Current.ExcludedFolders);
        Cleanup = new CleanupService(Protection, DeleteLog);
        Settings = new SettingsViewModel(SettingsService, Protection);
        Log = new LogViewModel(DeleteLog);
        Results = new ResultsViewModel(SettingsService, Settings, Cleanup, Thumbnails, () => Log.Reload());
        Scan = new ScanViewModel(SettingsService, Settings, new ScanService(Protection, LastAccess), LastAccess, Results,
            () => Navigate("results"));
        Dashboard = new DashboardViewModel();
        Drivers = new DriversViewModel(SettingsService);
        Desktop = new DesktopViewModel(SettingsService, new DesktopApplier(DeleteLog), () => Log.Reload());
        CurrentPage = Dashboard;
    }

    public async Task InitializeAsync()
    {
        await Task.Run(LastAccess.Detect);
        Scan.RefreshLastAccess();
        Results.TryLoadLast();
        Log.Reload();
        await Dashboard.InitializeAsync();
    }

    [RelayCommand]
    private void Navigate(string key) => CurrentKey = key;

    partial void OnCurrentKeyChanged(string value) => ShowPage(value);

    private void ShowPage(string key)
    {
        CurrentPage = key switch
        {
            "dashboard" => Dashboard,
            "drivers" => Drivers,
            "scan" => Scan,
            "results" => Results,
            "log" => Log,
            "settings" => Settings,
            "desktop" => Desktop,
            _ => Dashboard,
        };
        if (key == "dashboard") Dashboard.Resume(); else Dashboard.Pause();
        if (key == "drivers") _ = Drivers.EnsureLoadedAsync();
        if (key == "log") Log.Reload();
        if (key == "desktop") _ = Desktop.EnsureLoadedAsync();
    }

    [RelayCommand]
    private void ToggleTheme() => Settings.DarkMode = !Settings.DarkMode;
}
