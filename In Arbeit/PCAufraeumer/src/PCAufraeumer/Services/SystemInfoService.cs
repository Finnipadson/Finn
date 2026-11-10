using System.Diagnostics;
using System.Globalization;
using System.Management;
using Microsoft.Win32;

namespace PCAufraeumer.Services;

public sealed class CpuInfo
{
    public string Name = "Unbekannt";
    public int Cores;
    public int Threads;
    public int MaxClockMHz;
}

public sealed class GpuStatic
{
    public string Name = "";
    public string DriverVersion = "";
    public DateTime? DriverDate;
    public long? AdapterRamBytes;
    public string PnpDeviceId = "";
    public bool IsNvidia => Name.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase);
}

public sealed class GpuLive
{
    public string Name = "";
    public double MemTotalMB;
    public double MemUsedMB;
    public double UtilPercent;
    public double? TempC;
    public string DriverVersion = "";
}

public sealed class RamInfo
{
    public int ModuleCount;
    public string Type = "";
    public int SpeedMHz;
    public long InstalledBytes;
}

public sealed class DriveData
{
    public string Letter { get; set; } = "";
    public string Label { get; set; } = "";
    public long Total { get; set; }
    public long Free { get; set; }
    public string Kind { get; set; } = "Unbekannt";
    public string Health { get; set; } = "Nicht verfügbar";
    public string HealthLevel { get; set; } = "grau"; // grün / gelb / rot / grau
    public string Model { get; set; } = "";
    public string FileSystem { get; set; } = "";

    // Für die Anzeige
    public long Used => Total - Free;
    public double UsedPercent => Total > 0 ? Used * 100.0 / Total : 0;
    public string Title => $"{Letter}  {Label}";
    public string SizeText => $"{Format.Bytes(Free)} frei von {Format.Bytes(Total)}";
    public string Details => string.Join(" · ", new[] { Kind, FileSystem, Model }.Where(s => !string.IsNullOrWhiteSpace(s) && s != "Unbekannt"));
}

public sealed class BoardInfo
{
    public string Board = "";
    public string Bios = "";
    public string OsName = "";
    public string OsBuild = "";
}

/// <summary>Hardware- und Systeminformationen über WMI, nvidia-smi und Windows-APIs. Benötigt keine Adminrechte.</summary>
public sealed class SystemInfoService
{
    private long _prevIdle, _prevKernel, _prevUser;

    private static ManagementObjectCollection Query(string wql, string scope = @"root\cimv2")
    {
        var searcher = new ManagementObjectSearcher(scope, wql);
        searcher.Options.Timeout = TimeSpan.FromSeconds(10);
        return searcher.Get();
    }

    private static T Safe<T>(Func<T> f, T fallback, string what)
    {
        try { return f(); }
        catch (Exception ex) { ErrorLog.Write($"Systeminfo nicht lesbar: {what}", ex); return fallback; }
    }

    public CpuInfo GetCpu() => Safe(() =>
    {
        var c = new CpuInfo();
        foreach (ManagementObject o in Query("SELECT Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed FROM Win32_Processor"))
        {
            c.Name = (o["Name"] as string)?.Trim() ?? c.Name;
            c.Cores += Convert.ToInt32(o["NumberOfCores"] ?? 0);
            c.Threads += Convert.ToInt32(o["NumberOfLogicalProcessors"] ?? 0);
            c.MaxClockMHz = Convert.ToInt32(o["MaxClockSpeed"] ?? 0);
        }
        return c;
    }, new CpuInfo(), "CPU");

    /// <summary>CPU-Auslastung (wie Task-Manager) und aktueller Takt in MHz über Leistungsindikatoren.</summary>
    public (double load, double? clockMHz) GetCpuLive(int maxClockMHz)
    {
        try
        {
            foreach (ManagementObject o in Query(
                "SELECT PercentProcessorUtility, PercentProcessorPerformance FROM Win32_PerfFormattedData_Counters_ProcessorInformation WHERE Name='_Total'"))
            {
                double util = Convert.ToDouble(o["PercentProcessorUtility"] ?? 0);
                double perf = Convert.ToDouble(o["PercentProcessorPerformance"] ?? 0);
                double? clock = perf > 0 && maxClockMHz > 0 ? perf / 100.0 * maxClockMHz : null;
                return (Math.Clamp(util, 0, 100), clock);
            }
        }
        catch { /* Fallback unten */ }
        return (CpuLoadFallback(), null);
    }

    private double CpuLoadFallback()
    {
        if (!NativeMethods.GetSystemTimes(out var idle, out var kernel, out var user)) return 0;
        long di = idle - _prevIdle, dk = kernel - _prevKernel, du = user - _prevUser;
        _prevIdle = idle; _prevKernel = kernel; _prevUser = user;
        long total = dk + du;
        return total <= 0 ? 0 : Math.Clamp((total - di) * 100.0 / total, 0, 100);
    }

    /// <summary>CPU-Temperatur über die ACPI-Thermalzone. Nur mit Adminrechten und nicht auf allen Boards verfügbar.</summary>
    public double? GetCpuTemperature()
    {
        if (!TempService.IsAdmin) return null;
        try
        {
            double? max = null;
            foreach (ManagementObject o in Query("SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature", @"root\wmi"))
            {
                double c = Convert.ToDouble(o["CurrentTemperature"]) / 10.0 - 273.15;
                if (c > 0 && c < 125) max = max is null ? c : Math.Max(max.Value, c);
            }
            return max;
        }
        catch { return null; }
    }

    public List<GpuStatic> GetGpus() => Safe(() =>
    {
        var list = new List<GpuStatic>();
        foreach (ManagementObject o in Query("SELECT Name, DriverVersion, DriverDate, AdapterRAM, PNPDeviceID FROM Win32_VideoController"))
        {
            list.Add(new GpuStatic
            {
                Name = (o["Name"] as string ?? "").Trim(),
                DriverVersion = o["DriverVersion"] as string ?? "",
                DriverDate = ParseWmiDate(o["DriverDate"] as string),
                AdapterRamBytes = o["AdapterRAM"] is null ? null : Convert.ToInt64(o["AdapterRAM"]),
                PnpDeviceId = o["PNPDeviceID"] as string ?? "",
            });
        }
        // Virtuelle Adapter (Remote Desktop, Meta-Monitore) nach hinten.
        return list.OrderByDescending(g => g.IsNvidia).ThenBy(g => g.Name.Contains("Basic", StringComparison.OrdinalIgnoreCase)).ToList();
    }, new List<GpuStatic>(), "Grafikkarte");

    /// <summary>Live-Werte der NVIDIA-Karte über nvidia-smi (wird mit dem Treiber installiert).</summary>
    public GpuLive? GetNvidiaLive()
    {
        try
        {
            var psi = new ProcessStartInfo("nvidia-smi",
                "--query-gpu=name,memory.total,memory.used,utilization.gpu,temperature.gpu,driver_version --format=csv,noheader,nounits")
            {
                CreateNoWindow = true, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true,
            };
            using var p = Process.Start(psi);
            if (p == null) return null;
            var line = p.StandardOutput.ReadLine();
            p.StandardOutput.ReadToEnd();
            if (!p.WaitForExit(5000)) { try { p.Kill(); } catch { } return null; }
            if (string.IsNullOrWhiteSpace(line)) return null;
            var parts = line.Split(',').Select(s => s.Trim()).ToArray();
            if (parts.Length < 6) return null;
            static double D(string s) => double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0;
            return new GpuLive
            {
                Name = parts[0], MemTotalMB = D(parts[1]), MemUsedMB = D(parts[2]), UtilPercent = D(parts[3]),
                TempC = double.TryParse(parts[4], NumberStyles.Float, CultureInfo.InvariantCulture, out var t) ? t : null,
                DriverVersion = parts[5],
            };
        }
        catch { return null; }
    }

    public RamInfo GetRam() => Safe(() =>
    {
        var r = new RamInfo();
        foreach (ManagementObject o in Query("SELECT Capacity, Speed, ConfiguredClockSpeed, SMBIOSMemoryType FROM Win32_PhysicalMemory"))
        {
            r.ModuleCount++;
            r.InstalledBytes += Convert.ToInt64(o["Capacity"] ?? 0L);
            int cfg = Convert.ToInt32(o["ConfiguredClockSpeed"] ?? 0);
            int spd = Convert.ToInt32(o["Speed"] ?? 0);
            r.SpeedMHz = Math.Max(r.SpeedMHz, cfg > 0 ? cfg : spd);
            r.Type = Convert.ToInt32(o["SMBIOSMemoryType"] ?? 0) switch
            {
                20 => "DDR", 21 => "DDR2", 24 => "DDR3", 26 => "DDR4", 30 => "LPDDR4", 34 => "DDR5", 35 => "LPDDR5",
                _ => r.Type.Length > 0 ? r.Type : "Unbekannt",
            };
        }
        return r;
    }, new RamInfo(), "Arbeitsspeicher");

    public (ulong total, ulong avail) GetMemoryStatus()
    {
        var m = new NativeMethods.MEMORYSTATUSEX { dwLength = (uint)System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.MEMORYSTATUSEX>() };
        return NativeMethods.GlobalMemoryStatusEx(ref m) ? (m.ullTotalPhys, m.ullAvailPhys) : (0UL, 0UL);
    }

    /// <summary>Laufwerke inkl. SSD/HDD/NVMe und Gesundheitsstatus (Storage-WMI, ohne Adminrechte).</summary>
    public List<DriveData> GetDrives()
    {
        var disks = new Dictionary<string, (string kind, string health, string level, string model)>();
        var letterToDisk = new Dictionary<char, string>();
        try
        {
            const string scope = @"root\Microsoft\Windows\Storage";
            foreach (ManagementObject o in Query("SELECT DeviceId, FriendlyName, MediaType, BusType, HealthStatus FROM MSFT_PhysicalDisk", scope))
            {
                var id = Convert.ToString(o["DeviceId"]) ?? "";
                int media = Convert.ToInt32(o["MediaType"] ?? 0);
                int bus = Convert.ToInt32(o["BusType"] ?? 0);
                int health = Convert.ToInt32(o["HealthStatus"] ?? 5);
                string kind = bus == 17 ? "NVMe-SSD" : media switch { 3 => "HDD", 4 => "SSD", 5 => "SCM", _ => "Unbekannt" };
                if (bus == 7) kind += " (USB)";
                var (h, lvl) = health switch
                {
                    0 => ("Gesund", "grün"),
                    1 => ("Warnung", "gelb"),
                    2 => ("Fehlerhaft", "rot"),
                    _ => ("Nicht verfügbar", "grau"),
                };
                disks[id] = (kind, h, lvl, Convert.ToString(o["FriendlyName"]) ?? "");
            }
            foreach (ManagementObject o in Query("SELECT DriveLetter, DiskNumber FROM MSFT_Partition", scope))
            {
                var l = o["DriveLetter"];
                if (l is null) continue;
                char letter = Convert.ToChar(l);
                if (letter == '\0') continue;
                letterToDisk[char.ToUpperInvariant(letter)] = Convert.ToString(o["DiskNumber"]) ?? "";
            }
        }
        catch (Exception ex) { ErrorLog.Write("Laufwerksdetails (Storage-WMI) nicht lesbar.", ex); }

        var result = new List<DriveData>();
        foreach (var d in DriveInfo.GetDrives())
        {
            try
            {
                if (!d.IsReady) continue;
                var dd = new DriveData
                {
                    Letter = d.Name.TrimEnd('\\'),
                    Label = string.IsNullOrWhiteSpace(d.VolumeLabel) ? "Lokaler Datenträger" : d.VolumeLabel,
                    Total = d.TotalSize, Free = d.AvailableFreeSpace, FileSystem = d.DriveFormat,
                };
                if (d.DriveType == DriveType.Network) dd.Kind = "Netzlaufwerk";
                else if (d.DriveType == DriveType.CDRom) dd.Kind = "Optisch";
                if (letterToDisk.TryGetValue(char.ToUpperInvariant(d.Name[0]), out var disk) && disks.TryGetValue(disk, out var info))
                {
                    dd.Kind = info.kind; dd.Health = info.health; dd.HealthLevel = info.level; dd.Model = info.model;
                }
                result.Add(dd);
            }
            catch { /* Laufwerk gerade nicht bereit */ }
        }
        return result;
    }

    public BoardInfo GetBoard() => Safe(() =>
    {
        var b = new BoardInfo();
        foreach (ManagementObject o in Query("SELECT Manufacturer, Product FROM Win32_BaseBoard"))
            b.Board = $"{o["Manufacturer"]} {o["Product"]}".Trim();
        foreach (ManagementObject o in Query("SELECT SMBIOSBIOSVersion, ReleaseDate, Manufacturer FROM Win32_BIOS"))
        {
            var date = ParseWmiDate(o["ReleaseDate"] as string);
            b.Bios = $"{o["SMBIOSBIOSVersion"]}" + (date is null ? "" : $" vom {date:dd.MM.yyyy}");
        }
        foreach (ManagementObject o in Query("SELECT Caption, BuildNumber FROM Win32_OperatingSystem"))
        {
            b.OsName = (o["Caption"] as string ?? "Windows").Replace("Microsoft ", "");
            b.OsBuild = o["BuildNumber"] as string ?? "";
        }
        try
        {
            using var k = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            var disp = k?.GetValue("DisplayVersion") as string;
            var ubr = k?.GetValue("UBR");
            if (ubr != null) b.OsBuild += "." + ubr;
            if (!string.IsNullOrEmpty(disp)) b.OsName += $" (Version {disp})";
        }
        catch { }
        return b;
    }, new BoardInfo(), "Mainboard/BIOS/Windows");

    public static TimeSpan Uptime => TimeSpan.FromMilliseconds(Environment.TickCount64);

    public static DateTime? ParseWmiDate(string? s)
    {
        if (string.IsNullOrEmpty(s) || s.Length < 8) return null;
        try { return ManagementDateTimeConverter.ToDateTime(s); }
        catch
        {
            return DateTime.TryParseExact(s[..8], "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;
        }
    }
}
