using System.Collections.ObjectModel;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Systemübersicht mit Kacheln. Live-Werte alle 3 Sekunden.</summary>
public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly SystemInfoService _sys = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(3) };
    private bool _busy;
    private int _maxClock;
    private bool _hasNvidiaSmi = true;
    private int _driveTick;

    // CPU
    [ObservableProperty] private string _cpuName = "Wird geladen …";
    [ObservableProperty] private string _cpuCores = "";
    [ObservableProperty] private double _cpuLoad;
    [ObservableProperty] private string _cpuClock = "–";
    [ObservableProperty] private string _cpuTemp = "–";
    [ObservableProperty] private string _cpuTempHint = "";

    // GPU
    [ObservableProperty] private string _gpuName = "Wird geladen …";
    [ObservableProperty] private string _gpuVram = "–";
    [ObservableProperty] private double _gpuLoad;
    [ObservableProperty] private bool _gpuLoadKnown;
    [ObservableProperty] private string _gpuTemp = "–";
    [ObservableProperty] private string _gpuDriver = "–";
    [ObservableProperty] private string _gpuDriverDate = "–";
    [ObservableProperty] private string _gpuHint = "";

    // RAM
    [ObservableProperty] private string _ramTotal = "–";
    [ObservableProperty] private string _ramUsed = "–";
    [ObservableProperty] private string _ramFree = "–";
    [ObservableProperty] private double _ramPercent;
    [ObservableProperty] private string _ramModules = "–";

    // System
    [ObservableProperty] private string _board = "–";
    [ObservableProperty] private string _bios = "–";
    [ObservableProperty] private string _osName = "–";
    [ObservableProperty] private string _osBuild = "–";
    [ObservableProperty] private string _uptime = "–";
    [ObservableProperty] private bool _isAdmin = TempService.IsAdmin;

    public ObservableCollection<DriveData> Drives { get; } = new();

    public DashboardViewModel()
    {
        _timer.Tick += async (_, _) => await RefreshLiveAsync();
    }

    public async Task InitializeAsync()
    {
        try
        {
            var data = await Task.Run(() => new
            {
                Cpu = _sys.GetCpu(),
                Gpus = _sys.GetGpus(),
                Ram = _sys.GetRam(),
                Board = _sys.GetBoard(),
                Drives = _sys.GetDrives(),
            });

            CpuName = data.Cpu.Name;
            CpuCores = $"{data.Cpu.Cores} Kerne / {data.Cpu.Threads} Threads · max. {Format.Number(data.Cpu.MaxClockMHz / 1000.0, "0.00")} GHz (Basis laut Windows)";
            _maxClock = data.Cpu.MaxClockMHz;
            CpuTempHint = IsAdmin ? "" : "Temperatur nur mit Adminrechten (und nicht auf jedem Mainboard)";

            var gpu = data.Gpus.FirstOrDefault();
            if (gpu != null)
            {
                GpuName = gpu.Name;
                GpuDriver = gpu.IsNvidia ? $"{DriverService.ToNvidiaVersion(gpu.DriverVersion)}  ({gpu.DriverVersion})" : gpu.DriverVersion;
                GpuDriverDate = gpu.DriverDate?.ToString("dd.MM.yyyy") ?? "–";
                if (gpu.AdapterRamBytes is > 0) GpuVram = Format.Bytes(gpu.AdapterRamBytes.Value) + " (laut Windows, max. 4 GB anzeigbar)";
            }
            else GpuName = "Keine Grafikkarte gefunden";

            RamModules = data.Ram.ModuleCount > 0
                ? $"{data.Ram.ModuleCount} Modul(e) · {data.Ram.Type} · {data.Ram.SpeedMHz} MT/s"
                : "Moduldaten nicht verfügbar";

            Board = string.IsNullOrWhiteSpace(data.Board.Board) ? "Unbekannt" : data.Board.Board;
            Bios = string.IsNullOrWhiteSpace(data.Board.Bios) ? "Unbekannt" : data.Board.Bios;
            OsName = data.Board.OsName;
            OsBuild = "Build " + data.Board.OsBuild;
            SetDrives(data.Drives);
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Dashboard konnte nicht geladen werden.", ex);
        }

        await RefreshLiveAsync();
        _timer.Start();
    }

    private void SetDrives(List<DriveData> drives)
    {
        Drives.Clear();
        foreach (var d in drives) Drives.Add(d);
    }

    public void Pause() => _timer.Stop();
    public void Resume() { if (!_timer.IsEnabled) _timer.Start(); }

    [RelayCommand]
    private async Task RefreshLiveAsync()
    {
        if (_busy) return;
        _busy = true;
        try
        {
            bool drives = ++_driveTick % 10 == 0; // Laufwerke nur alle ~30 s
            var live = await Task.Run(() => new
            {
                Cpu = _sys.GetCpuLive(_maxClock),
                Temp = _sys.GetCpuTemperature(),
                Mem = _sys.GetMemoryStatus(),
                Gpu = _hasNvidiaSmi ? _sys.GetNvidiaLive() : null,
                Drives = drives ? _sys.GetDrives() : null,
            });

            CpuLoad = Math.Round(live.Cpu.load, 1);
            CpuClock = live.Cpu.clockMHz is { } mhz ? $"{Format.Number(mhz / 1000.0, "0.00")} GHz" : "–";
            CpuTemp = live.Temp is { } t ? $"{Format.Number(t, "0")} °C (ACPI)" : "nicht auslesbar";

            if (live.Mem.total > 0)
            {
                ulong used = live.Mem.total - live.Mem.avail;
                RamTotal = Format.Bytes((long)live.Mem.total);
                RamUsed = Format.Bytes((long)used);
                RamFree = Format.Bytes((long)live.Mem.avail);
                RamPercent = Math.Round(used * 100.0 / live.Mem.total, 1);
            }

            if (live.Gpu != null)
            {
                GpuLoad = live.Gpu.UtilPercent;
                GpuLoadKnown = true;
                GpuTemp = live.Gpu.TempC is { } gt ? $"{Format.Number(gt, "0")} °C" : "–";
                GpuVram = $"{Format.Bytes((long)(live.Gpu.MemUsedMB * 1024 * 1024))} belegt von {Format.Bytes((long)(live.Gpu.MemTotalMB * 1024 * 1024))}";
                GpuHint = "Live-Werte über nvidia-smi";
            }
            else if (GpuName.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase))
            {
                _hasNvidiaSmi = false;
                GpuHint = "nvidia-smi nicht gefunden – Live-Werte nicht verfügbar";
            }

            Uptime = Format.Duration(SystemInfoService.Uptime);
            if (live.Drives != null) SetDrives(live.Drives);
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Live-Werte konnten nicht aktualisiert werden.", ex);
        }
        finally { _busy = false; }
    }

    [RelayCommand]
    private void RestartAsAdmin()
    {
        try
        {
            var exe = Environment.ProcessPath!;
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(exe) { UseShellExecute = true, Verb = "runas" });
            System.Windows.Application.Current.Shutdown();
        }
        catch (System.ComponentModel.Win32Exception) { /* UAC abgelehnt – einfach weiterlaufen */ }
    }
}
