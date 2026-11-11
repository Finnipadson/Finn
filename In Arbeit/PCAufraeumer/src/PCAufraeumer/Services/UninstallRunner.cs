using System.ComponentModel;
using System.Diagnostics;
using System.Management;
using System.Text.RegularExpressions;
using Microsoft.Win32;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

public enum UninstallOutcome { Erfolgreich, Abgebrochen, Fehlgeschlagen, ImLauncher, KeinDeinstaller }

public sealed class UninstallResult
{
    public UninstallOutcome Outcome { get; set; }
    public string Message { get; set; } = "";
    public int? ExitCode { get; set; }
}

/// <summary>
/// Startet den eigenen Deinstaller eines Programms und wartet, bis er wirklich fertig ist –
/// auch wenn er Unterprozesse startet (z. B. Inno/NSIS kopieren sich nach %TEMP% und starten neu).
/// Spiele werden immer über ihren Launcher deinstalliert.
/// </summary>
public static class UninstallRunner
{
    /// <summary>Befehl in Programm + Argumente zerlegen; MSI immer mit /x (deinstallieren).</summary>
    public static (string exe, string args) BuildCommand(InstalledProgram p)
    {
        if (p.ProductCode.Length > 0) return ("msiexec.exe", $"/x {p.ProductCode}");
        var cmd = p.UninstallString.Trim();
        if (cmd.Length == 0) return ("", "");
        var msi = Regex.Match(cmd, @"msiexec(\.exe)?\s+/[IX]\s*(\{[0-9A-Fa-f\-]{36}\})", RegexOptions.IgnoreCase);
        if (msi.Success) return ("msiexec.exe", $"/x {msi.Groups[2].Value}");
        var exe = ProgramInventory.ExeFromCommand(cmd);
        var rest = cmd.StartsWith('"') ? cmd[(cmd.IndexOf('"', 1) + 1)..].Trim() : cmd[Math.Min(cmd.Length, exe.Length)..].Trim();
        return (exe, rest);
    }

    public static async Task<UninstallResult> RunAsync(InstalledProgram p, IProgress<string> progress, CancellationToken ct)
    {
        if (p.IsLocked) return new UninstallResult { Outcome = UninstallOutcome.Fehlgeschlagen, Message = "Von Windows gesperrt (nicht entfernbar)." };

        // Store- und Windows-Apps
        if (p.PackageFullName.Length > 0)
        {
            progress.Report("App wird entfernt …");
            try
            {
                await Task.Run(() => ProgramInventory.RunPowerShell($"Remove-AppxPackage -Package '{p.PackageFullName.Replace("'", "''")}'", 300000), ct);
                return new UninstallResult { Outcome = UninstallOutcome.Erfolgreich, Message = "App entfernt." };
            }
            catch (Exception ex) { return new UninstallResult { Outcome = UninstallOutcome.Fehlgeschlagen, Message = ex.Message }; }
        }

        // Launcher-Spiele: Launcher öffnen, Benutzer bestätigt dort
        if (p.Kind == ProgramKind.Spiel && p.LauncherUri.Length > 0)
        {
            Shell.Open(p.LauncherUri);
            return new UninstallResult { Outcome = UninstallOutcome.ImLauncher, Message = p.LauncherHint.Length > 0 ? p.LauncherHint : "Bitte im Launcher deinstallieren." };
        }

        var (exe, args) = BuildCommand(p);
        if (exe.Length == 0) return new UninstallResult { Outcome = UninstallOutcome.KeinDeinstaller, Message = "Kein Deinstaller eingetragen." };
        if (!exe.Equals("msiexec.exe", StringComparison.OrdinalIgnoreCase) && !File.Exists(exe))
            return new UninstallResult { Outcome = UninstallOutcome.KeinDeinstaller, Message = $"Deinstaller nicht gefunden: {exe}" };

        progress.Report("Deinstaller läuft – bitte im Fenster des Deinstallers bestätigen …");
        Process? proc;
        var started = DateTime.Now;
        try
        {
            proc = Process.Start(new ProcessStartInfo(exe, args) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(exe) ?? "" });
        }
        catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            return new UninstallResult { Outcome = UninstallOutcome.Abgebrochen, Message = "Adminrechte für den Deinstaller abgelehnt." };
        }
        if (proc == null) return new UninstallResult { Outcome = UninstallOutcome.Fehlgeschlagen, Message = "Deinstaller konnte nicht gestartet werden." };

        int rootPid = proc.Id;
        int? exit = null;
        await proc.WaitForExitAsync(ct);
        try { exit = proc.ExitCode; } catch { }
        proc.Dispose();

        // Auf Unterprozesse warten (Nachfahren des Deinstallers + typische Deinstaller-Kopien in %TEMP%)
        progress.Report("Warte, bis alle Teile des Deinstallers fertig sind …");
        await WaitForDescendantsAsync(rootPid, started, ct);

        bool stillThere = StillInstalled(p);
        if (!stillThere)
            return new UninstallResult { Outcome = UninstallOutcome.Erfolgreich, ExitCode = exit, Message = "Deinstalliert." };
        if (exit is 1602 or 1223)
            return new UninstallResult { Outcome = UninstallOutcome.Abgebrochen, ExitCode = exit, Message = "Deinstallation abgebrochen." };
        return new UninstallResult
        {
            Outcome = UninstallOutcome.Fehlgeschlagen, ExitCode = exit,
            Message = $"Der Deinstaller ist beendet, aber der Programmeintrag existiert noch (Code {exit?.ToString() ?? "?"}). " +
                      "Vielleicht wurde abgebrochen – oder die erzwungene Deinstallation hilft.",
        };
    }

    /// <summary>Ist der Uninstall-Eintrag noch da?</summary>
    public static bool StillInstalled(InstalledProgram p)
    {
        if (p.RegistryPath.Length == 0) return p.InstallLocation.Length > 0 && Directory.Exists(p.InstallLocation);
        try
        {
            var (root, sub) = AdminHelper.SplitKey(p.RegistryPath);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                return k != null;
            }
        }
        catch { return false; }
    }

    private static readonly Regex UninstallerName = new(@"^(au_|un_a|_iu|unins|uninst|uninstall|setup)", RegexOptions.IgnoreCase);

    public static async Task WaitForDescendantsAsync(int rootPid, DateTime started, CancellationToken ct)
    {
        var tracked = new HashSet<int> { rootPid };
        int quiet = 0;
        for (int i = 0; i < 60 * 60 * 2 && quiet < 4; i++) // höchstens ~1 Stunde
        {
            ct.ThrowIfCancellationRequested();
            var alive = Snapshot();
            // Nachfahren aufnehmen
            bool added;
            do
            {
                added = false;
                foreach (var pr in alive)
                    if (!tracked.Contains(pr.pid) && tracked.Contains(pr.parent) && pr.created >= started.AddSeconds(-2))
                    { tracked.Add(pr.pid); added = true; }
            } while (added);
            // Typische Deinstaller-Kopien, die nach dem Start entstanden sind (Elternprozess evtl. schon beendet)
            foreach (var pr in alive.Where(a => a.created >= started && UninstallerName.IsMatch(a.name)))
                tracked.Add(pr.pid);
            bool running = alive.Any(a => tracked.Contains(a.pid));
            quiet = running ? 0 : quiet + 1;
            await Task.Delay(500, ct);
        }
    }

    private static List<(int pid, int parent, string name, DateTime created)> Snapshot()
    {
        var list = new List<(int, int, string, DateTime)>();
        try
        {
            using var s = new ManagementObjectSearcher("SELECT ProcessId, ParentProcessId, Name, CreationDate FROM Win32_Process");
            foreach (ManagementObject o in s.Get())
            {
                DateTime c = DateTime.MinValue;
                if (o["CreationDate"] is string cd) { try { c = ManagementDateTimeConverter.ToDateTime(cd); } catch { } }
                list.Add((Convert.ToInt32(o["ProcessId"]), Convert.ToInt32(o["ParentProcessId"]), (o["Name"] as string ?? "").ToLowerInvariant(), c));
            }
        }
        catch { }
        return list;
    }
}
