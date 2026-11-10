using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Treiberprüfung. Zeigt nur an und verlinkt – installiert nichts.</summary>
public sealed partial class DriversViewModel : ObservableObject
{
    private readonly DriverService _svc = new();
    private readonly SettingsService _settings;
    private bool _loaded;

    public ObservableCollection<DriverItem> Drivers { get; } = new();
    public ObservableCollection<WuDriverUpdate> OtherUpdates { get; } = new();

    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private bool _isSearchingWu;
    [ObservableProperty] private string _wuStatus = "Noch nicht gesucht. Die Suche fragt Windows Update nach angebotenen Treibern (dauert bis zu 1–2 Minuten).";

    // NVIDIA
    [ObservableProperty] private bool _hasNvidia;
    [ObservableProperty] private string _nvidiaName = "";
    [ObservableProperty] private string _nvidiaInstalled = "";
    [ObservableProperty] private string _nvidiaDate = "";
    [ObservableProperty] private string _nvidiaLatest = "–";
    [ObservableProperty] private string _nvidiaMessage = "Noch nicht geprüft.";
    [ObservableProperty] private Ampel _nvidiaStatus = Ampel.Grau;
    [ObservableProperty] private string _nvidiaDetailsUrl = DriverService.NvidiaDriverPage;
    [ObservableProperty] private bool _isCheckingNvidia;

    public DriversViewModel(SettingsService settings) => _settings = settings;

    public async Task EnsureLoadedAsync()
    {
        if (_loaded) return;
        _loaded = true;
        await ReloadAsync();
    }

    [RelayCommand]
    private async Task ReloadAsync()
    {
        IsLoading = true;
        try
        {
            var list = await Task.Run(_svc.GetDrivers);
            Drivers.Clear();
            foreach (var d in list) Drivers.Add(d);

            var nv = list.FirstOrDefault(d => d.DeviceClass == "DISPLAY" && d.DeviceName.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase));
            HasNvidia = nv != null;
            if (nv != null)
            {
                NvidiaName = nv.DeviceName;
                NvidiaInstalled = DriverService.ToNvidiaVersion(nv.Version);
                NvidiaDate = nv.DateText;
                nv.StatusText = "Siehe NVIDIA-Prüfung oben";
                if (_settings.Current.NvidiaOnlineCheck) await CheckNvidiaAsync();
                else NvidiaMessage = "Online-Prüfung ist in den Einstellungen ausgeschaltet.";
            }
        }
        finally { IsLoading = false; }
    }

    [RelayCommand]
    private async Task CheckNvidiaAsync()
    {
        if (!HasNvidia) return;
        IsCheckingNvidia = true;
        NvidiaMessage = "Frage NVIDIA nach der neuesten Version …";
        try
        {
            var r = await _svc.CheckNvidiaAsync(NvidiaName, NvidiaInstalled, CancellationToken.None);
            NvidiaDetailsUrl = r.DetailsUrl;
            NvidiaLatest = r.Checked ? r.LatestVersion + (r.ReleaseDate is { } d ? $" vom {d:dd.MM.yyyy}" : "") : "–";
            NvidiaMessage = r.Message;
            NvidiaStatus = !r.Checked ? Ampel.Grau : r.IsCurrent == true ? Ampel.Gruen : Ampel.Gelb;

            var nv = Drivers.FirstOrDefault(d => d.DeviceClass == "DISPLAY" && d.DeviceName == NvidiaName);
            if (nv != null)
            {
                nv.Status = NvidiaStatus;
                nv.StatusText = r.Checked ? r.Message + " (inoffizielle NVIDIA-Abfrage)" : "Nicht prüfbar – bitte NVIDIA-Seite öffnen";
                nv.Link = r.DetailsUrl;
            }
        }
        finally { IsCheckingNvidia = false; }
    }

    [RelayCommand]
    private async Task SearchWindowsUpdateAsync()
    {
        IsSearchingWu = true;
        WuStatus = "Windows Update wird gefragt … (das kann 1–2 Minuten dauern)";
        try
        {
            var updates = await _svc.SearchWindowsUpdateAsync();
            var other = DriverService.ApplyWindowsUpdate(Drivers, updates);
            OtherUpdates.Clear();
            foreach (var u in other) OtherUpdates.Add(u);
            WuStatus = updates.Count == 0
                ? $"Geprüft am {DateTime.Now:dd.MM.yyyy HH:mm}: Windows Update bietet derzeit keine Treiber-Updates an."
                : $"Geprüft am {DateTime.Now:dd.MM.yyyy HH:mm}: {updates.Count} Treiber-Update(s) angeboten. Installieren kannst du sie unter Einstellungen › Windows Update › Erweiterte Optionen › Optionale Updates.";
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Windows-Update-Suche fehlgeschlagen.", ex);
            WuStatus = "Windows Update konnte nicht abgefragt werden: " + ex.Message;
        }
        finally { IsSearchingWu = false; }
    }

    [RelayCommand] private void OpenNvidiaPage() => Shell.Open(NvidiaDetailsUrl);
    [RelayCommand] private void OpenNvidiaDriverSearch() => Shell.Open(DriverService.NvidiaDriverPage);
    [RelayCommand] private void OpenWindowsUpdate() => Shell.Open("ms-settings:windowsupdate-optionalupdates");
    [RelayCommand] private void OpenLink(string? url) { if (!string.IsNullOrEmpty(url)) Shell.Open(url); }
}
