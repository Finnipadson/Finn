using System.Globalization;
using System.Management;
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Services;

public enum Ampel { Gruen, Gelb, Grau }

public sealed partial class DriverItem : ObservableObject
{
    public string Category { get; set; } = "";
    public string DeviceName { get; set; } = "";
    public string Manufacturer { get; set; } = "";
    public string Version { get; set; } = "";
    public DateTime? Date { get; set; }
    public string HardwareId { get; set; } = "";
    public string DeviceClass { get; set; } = "";

    [ObservableProperty] private Ampel _status = Ampel.Grau;
    [ObservableProperty] private string _statusText = "Nicht geprüft";
    [ObservableProperty] private string? _link;

    public string DateText => Date?.ToString("dd.MM.yyyy") ?? "–";
    public bool OlderThanYear => Date is { } d && (DateTime.Now - d).TotalDays > 365;
}

public sealed class WuDriverUpdate
{
    public string Title { get; set; } = "";
    public string Model { get; set; } = "";
    public string HardwareId { get; set; } = "";
    public string Manufacturer { get; set; } = "";
    public DateTime? Date { get; set; }
    public string DriverClass { get; set; } = "";
}

public sealed class NvidiaCheckResult
{
    public bool Checked { get; set; }
    public string LatestVersion { get; set; } = "";
    public DateTime? ReleaseDate { get; set; }
    public string DetailsUrl { get; set; } = "";
    public string Message { get; set; } = "";
    public bool? IsCurrent { get; set; }
}

/// <summary>Treiberliste (WMI), Windows-Update-Treiberangebote und NVIDIA-Versionsprüfung. Installiert NICHTS.</summary>
public sealed class DriverService
{
    public const string NvidiaDriverPage = "https://www.nvidia.com/de-de/drivers/";

    private static readonly Dictionary<string, string> ClassNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["DISPLAY"] = "Grafik", ["NET"] = "Netzwerk", ["MEDIA"] = "Audio", ["AUDIOENDPOINT"] = "",
        ["USB"] = "USB", ["SYSTEM"] = "Chipsatz/System", ["HDC"] = "Speicher-Controller",
        ["SCSIADAPTER"] = "Speicher-Controller", ["BLUETOOTH"] = "Bluetooth", ["HIDCLASS"] = "Eingabegeräte",
        ["CAMERA"] = "Kamera", ["IMAGE"] = "Kamera", ["BIOMETRIC"] = "Biometrie",
    };

    public List<DriverItem> GetDrivers()
    {
        var list = new List<DriverItem>();
        try
        {
            using var s = new ManagementObjectSearcher(
                "SELECT DeviceName, DeviceClass, DriverVersion, DriverDate, Manufacturer, DriverProviderName, HardWareID FROM Win32_PnPSignedDriver");
            s.Options.Timeout = TimeSpan.FromSeconds(30);
            foreach (ManagementObject o in s.Get())
            {
                var cls = (o["DeviceClass"] as string ?? "").ToUpperInvariant();
                if (!ClassNames.TryGetValue(cls, out var label) || label.Length == 0) continue;
                var name = (o["DeviceName"] as string ?? "").Trim();
                var provider = (o["DriverProviderName"] as string ?? "").Trim();
                if (name.Length == 0) continue;
                // Mitgelieferte Microsoft-Standardtreiber bei System/USB/HID ausblenden – sonst hunderte Einträge.
                bool msGeneric = provider.Equals("Microsoft", StringComparison.OrdinalIgnoreCase) ||
                                 provider.StartsWith("(Standard", StringComparison.OrdinalIgnoreCase);
                if (msGeneric && cls is "SYSTEM" or "USB" or "HIDCLASS" or "HDC" or "SCSIADAPTER") continue;

                list.Add(new DriverItem
                {
                    Category = label,
                    DeviceClass = cls.ToUpperInvariant(),
                    DeviceName = name,
                    Manufacturer = provider.Length > 0 ? provider : (o["Manufacturer"] as string ?? ""),
                    Version = o["DriverVersion"] as string ?? "",
                    Date = SystemInfoService.ParseWmiDate(o["DriverDate"] as string),
                    HardwareId = o["HardWareID"] as string ?? "",
                });
            }
        }
        catch (Exception ex) { ErrorLog.Write("Treiberliste konnte nicht gelesen werden.", ex); }

        var unique = list
            .GroupBy(d => (d.DeviceName, d.Version))
            .Select(g => g.First())
            .OrderBy(d => CategoryOrder(d.Category)).ThenBy(d => d.DeviceName)
            .ToList();
        foreach (var d in unique) ApplyOffline(d);
        return unique;
    }

    /// <summary>Mit Windows mitgelieferte Treiber (Datum oft symbolisch 2006) – Ampel „älter als 1 Jahr“ wäre irreführend.</summary>
    internal static bool IsInbox(DriverItem d) =>
        d.Manufacturer.Equals("Microsoft", StringComparison.OrdinalIgnoreCase) ||
        d.Manufacturer.StartsWith("(Standard", StringComparison.OrdinalIgnoreCase);

    private static int CategoryOrder(string c) => c switch
    {
        "Grafik" => 0, "Chipsatz/System" => 1, "Netzwerk" => 2, "Audio" => 3, "USB" => 4, _ => 5,
    };

    /// <summary>Status ohne Online-Prüfung: nur „älter als 1 Jahr“ ist sicher bekannt.</summary>
    private static void ApplyOffline(DriverItem d)
    {
        if (IsInbox(d))
        {
            d.Status = Ampel.Grau;
            d.StatusText = "Windows-Standardtreiber – wird mit Windows selbst aktualisiert";
        }
        else if (d.OlderThanYear) { d.Status = Ampel.Gelb; d.StatusText = "Älter als 1 Jahr – noch nicht online geprüft"; }
        else { d.Status = Ampel.Grau; d.StatusText = "Noch nicht geprüft"; }
    }

    /// <summary>
    /// Fragt den Windows Update Agent nach angebotenen (nicht installierten) Treiber-Updates.
    /// Kann 30–90 Sekunden dauern. Installiert nichts.
    /// </summary>
    public Task<List<WuDriverUpdate>> SearchWindowsUpdateAsync() => StaTask.Run(() =>
    {
        var result = new List<WuDriverUpdate>();
        var type = Type.GetTypeFromProgID("Microsoft.Update.Session")
                   ?? throw new InvalidOperationException("Windows Update Agent ist nicht verfügbar.");
        dynamic session = Activator.CreateInstance(type)!;
        session.ClientApplicationID = "PC Aufraeumer";
        dynamic searcher = session.CreateUpdateSearcher();
        searcher.Online = true;
        dynamic sr = searcher.Search("IsInstalled=0 and Type='Driver'");
        int count = sr.Updates.Count;
        for (int i = 0; i < count; i++)
        {
            dynamic u = sr.Updates.Item(i);
            DateTime? date = null;
            try { date = (DateTime)u.DriverVerDate; } catch { }
            result.Add(new WuDriverUpdate
            {
                Title = (string)u.Title,
                Model = SafeStr(() => (string)u.DriverModel),
                HardwareId = SafeStr(() => (string)u.DriverHardwareID),
                Manufacturer = SafeStr(() => (string)u.DriverManufacturer),
                DriverClass = SafeStr(() => (string)u.DriverClass),
                Date = date,
            });
        }
        return result;
    });

    private static string SafeStr(Func<string> f) { try { return f() ?? ""; } catch { return ""; } }

    /// <summary>Ordnet Windows-Update-Angebote den installierten Treibern zu und setzt die Ampel.</summary>
    public static List<WuDriverUpdate> ApplyWindowsUpdate(IEnumerable<DriverItem> drivers, List<WuDriverUpdate> updates)
    {
        var unmatched = new List<WuDriverUpdate>(updates);
        foreach (var d in drivers)
        {
            if (d.DeviceClass == "DISPLAY" && d.DeviceName.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase))
                continue; // NVIDIA wird separat geprüft
            var match = updates.FirstOrDefault(u =>
                (u.HardwareId.Length > 0 && d.HardwareId.Length > 0 &&
                 (d.HardwareId.StartsWith(u.HardwareId, StringComparison.OrdinalIgnoreCase) ||
                  u.HardwareId.StartsWith(d.HardwareId, StringComparison.OrdinalIgnoreCase))) ||
                (u.Model.Length > 0 && string.Equals(u.Model, d.DeviceName, StringComparison.OrdinalIgnoreCase)));
            if (match == null && IsInbox(d))
            {
                d.Status = Ampel.Grau;
                d.StatusText = "Windows-Standardtreiber – wird mit Windows selbst aktualisiert";
            }
            else if (match != null)
            {
                unmatched.Remove(match);
                d.Status = Ampel.Gelb;
                d.StatusText = $"Update über Windows Update angeboten: {match.Title}";
                d.Link = "ms-settings:windowsupdate-optionalupdates";
            }
            else if (d.OlderThanYear)
            {
                d.Status = Ampel.Gelb;
                d.StatusText = "Kein Update über Windows Update angeboten, aber älter als 1 Jahr – ggf. Herstellerseite prüfen";
            }
            else
            {
                d.Status = Ampel.Gruen;
                d.StatusText = "Kein Update über Windows Update angeboten";
            }
        }
        return unmatched;
    }

    // ───────────────────────── NVIDIA ─────────────────────────
    // Es gibt keine offizielle, dokumentierte API. Die NVIDIA-Treibersuche (nvidia.com/drivers) verwendet
    // intern die beiden Endpunkte unten. Diese sind inoffiziell; sie werden deshalb in der App als
    // „inoffizielle Abfrage“ gekennzeichnet. Schlägt etwas fehl, wird NICHTS behauptet (Ampel grau).

    private const string LookupUrl = "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3";
    private const string DriverUrl =
        "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php" +
        "?func=DriverManualLookup&psid={0}&pfid={1}&osID={2}&languageCode=1031&isWHQL=1&dch=1&sort1=0&numberOfResults=1";

    /// <summary>Wandelt die Windows-Treiberversion (z. B. 32.0.15.6214) in die NVIDIA-Version (562.14) um.</summary>
    public static string ToNvidiaVersion(string windowsVersion)
    {
        var digits = new string(windowsVersion.Where(char.IsDigit).ToArray());
        if (digits.Length < 5) return windowsVersion;
        var last5 = digits[^5..];
        return $"{last5[..3]}.{last5[3..]}";
    }

    public async Task<NvidiaCheckResult> CheckNvidiaAsync(string gpuName, string installedNvidiaVersion, CancellationToken ct)
    {
        var r = new NvidiaCheckResult { DetailsUrl = NvidiaDriverPage };
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

            var xml = await http.GetStringAsync(LookupUrl, ct);
            var wanted = NormalizeGpuName(gpuName);
            bool laptop = gpuName.Contains("Laptop", StringComparison.OrdinalIgnoreCase);
            (string psid, string pfid)? hit = null;
            // NVIDIA liefert Zeilenumbrüche (\r) zwischen den Tags → \s* zulassen.
            foreach (Match m in Regex.Matches(xml, "<LookupValue ParentID=\"(\\d+)\">\\s*<Name>([^<]+)</Name>\\s*<Value>(\\d+)</Value>"))
            {
                var name = m.Groups[2].Value;
                if (name.Contains("Laptop", StringComparison.OrdinalIgnoreCase) != laptop) continue;
                if (NormalizeGpuName(name) == wanted) { hit = (m.Groups[1].Value, m.Groups[3].Value); break; }
            }
            if (hit is null)
            {
                r.Message = $"Grafikkarte „{gpuName}“ wurde in der NVIDIA-Produktliste nicht gefunden – bitte manuell prüfen.";
                return r;
            }

            // osID 135 = Windows 11 64-bit, 57 = Windows 10 64-bit
            string osId = Environment.OSVersion.Version.Build >= 22000 ? "135" : "57";
            var json = await http.GetStringAsync(string.Format(CultureInfo.InvariantCulture, DriverUrl, hit.Value.psid, hit.Value.pfid, osId), ct);
            using var doc = JsonDocument.Parse(json);
            var info = doc.RootElement.GetProperty("IDS")[0].GetProperty("downloadInfo");
            r.LatestVersion = info.GetProperty("Version").GetString() ?? "";
            if (info.TryGetProperty("DetailsURL", out var du) && du.GetString() is { Length: > 0 } url) r.DetailsUrl = url;
            if (info.TryGetProperty("ReleaseDateTime", out var rd) &&
                DateTime.TryParseExact(rd.GetString(), "ddd MMM dd, yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
                r.ReleaseDate = d;

            if (string.IsNullOrEmpty(r.LatestVersion)) { r.Message = "NVIDIA hat keine Version geliefert."; return r; }
            r.Checked = true;
            int cmp = CompareVersions(installedNvidiaVersion, r.LatestVersion);
            r.IsCurrent = cmp >= 0;
            r.Message = r.IsCurrent == true
                ? $"Aktuell – neueste Game-Ready-Version laut NVIDIA: {r.LatestVersion}"
                : $"Update verfügbar: {r.LatestVersion}" + (r.ReleaseDate is { } rel ? $" vom {rel:dd.MM.yyyy}" : "");
            return r;
        }
        catch (OperationCanceledException) { r.Message = "Abfrage abgebrochen."; return r; }
        catch (Exception ex)
        {
            ErrorLog.Write("NVIDIA-Versionsprüfung fehlgeschlagen.", ex);
            r.Message = "Online-Prüfung nicht möglich (keine Verbindung oder NVIDIA hat die Abfrage geändert). Bitte manuell prüfen.";
            return r;
        }
    }

    internal static string NormalizeGpuName(string n) =>
        Regex.Replace(n.ToLowerInvariant().Replace("nvidia", "").Replace("geforce", ""), @"\s+", " ").Trim();

    internal static int CompareVersions(string a, string b)
    {
        static double V(string s) => double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0;
        return V(a).CompareTo(V(b));
    }
}
