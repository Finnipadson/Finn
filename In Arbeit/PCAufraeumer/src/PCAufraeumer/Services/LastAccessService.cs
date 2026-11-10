using System.Diagnostics;
using Microsoft.Win32;

namespace PCAufraeumer.Services;

/// <summary>
/// Prüft, ob Windows das Datum „Letzter Zugriff“ (LastAccessTime) überhaupt aktualisiert
/// (Registry NtfsDisableLastAccessUpdate bzw. „fsutil behavior query disablelastaccess“).
/// </summary>
public sealed class LastAccessService
{
    public bool UpdatesEnabled { get; private set; }
    public bool Known { get; private set; }
    public string RegistryText { get; private set; } = "";
    public string FsutilText { get; private set; } = "";

    public string Summary => !Known
        ? "Unbekannt – als Grundlage wird das Änderungsdatum verwendet."
        : UpdatesEnabled
            ? "Windows aktualisiert „Letzter Zugriff“ – die App nutzt dieses Datum (bei Unstimmigkeiten das Änderungsdatum)."
            : "Windows aktualisiert „Letzter Zugriff“ NICHT – die App nutzt deshalb das Änderungsdatum.";

    public void Detect()
    {
        try
        {
            using var key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\FileSystem");
            var raw = key?.GetValue("NtfsDisableLastAccessUpdate");
            if (raw is int i)
            {
                uint v = unchecked((uint)i);
                Interpret(v);
            }
            else
            {
                // Wert fehlt: ältere Windows-Versionen → Aktualisierung aktiv (Standard bis Vista war aus).
                RegistryText = "Registry-Wert NtfsDisableLastAccessUpdate nicht vorhanden.";
                Known = false;
            }
        }
        catch (Exception ex)
        {
            RegistryText = "Registry konnte nicht gelesen werden: " + ex.Message;
            Known = false;
            ErrorLog.Write("NtfsDisableLastAccessUpdate konnte nicht gelesen werden.", ex);
        }

        FsutilText = QueryFsutil();
    }

    internal void Interpret(uint v)
    {
        // Bit 0: 1 = deaktiviert. Bit 31: 1 = vom System verwaltet (Windows 10 1803+).
        bool disabled = (v & 1) == 1;
        bool system = (v & 0x80000000) != 0;
        UpdatesEnabled = !disabled;
        Known = true;
        RegistryText = $"NtfsDisableLastAccessUpdate = 0x{v:X8} → " +
                       (system ? "vom System verwaltet, " : "vom Benutzer festgelegt, ") +
                       (disabled ? "Aktualisierung AUS" : "Aktualisierung AN");
    }

    private static System.Text.Encoding OemEncoding()
    {
        try
        {
            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
            return System.Text.Encoding.GetEncoding(System.Globalization.CultureInfo.CurrentCulture.TextInfo.OEMCodePage);
        }
        catch { return System.Text.Encoding.UTF8; }
    }

    private static string QueryFsutil()
    {
        try
        {
            var psi = new ProcessStartInfo("fsutil.exe", "behavior query disablelastaccess")
            {
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                // Konsolenprogramme schreiben in der OEM-Codepage (z. B. 850) – sonst fehlen Umlaute.
                StandardOutputEncoding = OemEncoding(),
            };
            using var p = Process.Start(psi)!;
            var output = p.StandardOutput.ReadToEnd().Trim();
            var err = p.StandardError.ReadToEnd().Trim();
            if (!p.WaitForExit(5000)) { try { p.Kill(); } catch { } return "fsutil: keine Antwort."; }
            if (p.ExitCode != 0 || output.Length == 0)
                return "fsutil: ohne Adminrechte nicht abfragbar (Registry-Wert oben ist maßgeblich).";
            return "fsutil: " + output.Replace("\r", "").Replace("\n", " ");
        }
        catch (Exception ex)
        {
            return "fsutil nicht ausführbar: " + ex.Message;
        }
    }

    /// <summary>
    /// Liefert das Datum, auf dem „nicht mehr geöffnet“ beruht.
    /// Fallback auf das Änderungsdatum, wenn LastAccess unzuverlässig ist.
    /// </summary>
    public (DateTime date, Models.DateBasis basis) UsageDate(DateTime lastAccess, DateTime lastWrite)
    {
        if (Known && UpdatesEnabled && lastAccess >= lastWrite && lastAccess.Year > 1980)
            return (lastAccess, Models.DateBasis.LastAccess);
        return (lastWrite, Models.DateBasis.LastWrite);
    }
}
