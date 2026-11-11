using System.ComponentModel;
using System.Diagnostics;
using System.Management;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace PCAufraeumer.Services;

/// <summary>Eine Aufgabe für den Admin-Helfer. Nur die unten aufgeführten Arten sind erlaubt.</summary>
public sealed class AdminOp
{
    public string Kind { get; set; } = "";
    public string Target { get; set; } = "";
    public string Extra { get; set; } = "";
}

public sealed class AdminResult
{
    public string Kind { get; set; } = "";
    public string Target { get; set; } = "";
    public bool Success { get; set; }
    public string Message { get; set; } = "";
}

/// <summary>
/// Führt Aktionen aus, die Adminrechte brauchen. Die App selbst läuft ohne Adminrechte;
/// erst wenn nötig wird sie selbst mit „--admin-job“ per UAC gestartet (ein UAC-Fenster pro Sammelauftrag).
/// Erlaubte Arten: restorepoint, enableprotection, regdelete, recycle, servicedelete, servicestart,
///                 taskdelete, taskenable, taskdisable, firewalldelete, regsetbinary.
/// </summary>
public static class AdminHelper
{
    public static bool IsAdmin => TempService.IsAdmin;

    private static readonly HashSet<string> Allowed = new(StringComparer.OrdinalIgnoreCase)
    {
        "restorepoint", "enableprotection", "regdelete", "recycle", "servicedelete", "servicestart",
        "taskdelete", "taskenable", "taskdisable", "firewalldelete", "regsetbinary",
    };

    /// <summary>Führt Aufträge mit Adminrechten aus (UAC). Ist die App schon Admin, direkt.</summary>
    public static async Task<List<AdminResult>> RunElevatedAsync(IReadOnlyList<AdminOp> ops)
    {
        if (ops.Count == 0) return new();
        if (IsAdmin) return await Task.Run(() => Execute(ops));
        var job = Path.Combine(Path.GetTempPath(), $"pcaufraeumer-adminjob-{Guid.NewGuid():N}.json");
        var res = job.Replace("-adminjob-", "-adminresult-");
        File.WriteAllText(job, JsonSerializer.Serialize(ops));
        try
        {
            var psi = new ProcessStartInfo(Environment.ProcessPath!, $"--admin-job \"{job}\" \"{res}\"")
            {
                UseShellExecute = true, Verb = "runas",
            };
            using var p = Process.Start(psi) ?? throw new InvalidOperationException("Admin-Helfer konnte nicht gestartet werden.");
            await p.WaitForExitAsync();
            if (!File.Exists(res)) throw new InvalidOperationException("Der Admin-Helfer hat kein Ergebnis geliefert.");
            return JsonSerializer.Deserialize<List<AdminResult>>(File.ReadAllText(res)) ?? new();
        }
        catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            return ops.Select(o => new AdminResult { Kind = o.Kind, Target = o.Target, Success = false, Message = "Adminrechte abgelehnt." }).ToList();
        }
        finally
        {
            try { File.Delete(job); } catch { }
            try { File.Delete(res); } catch { }
        }
    }

    /// <summary>Einstieg im Helferprozess.</summary>
    public static int RunJobFile(string jobFile, string resultFile)
    {
        List<AdminResult> results;
        try
        {
            var ops = JsonSerializer.Deserialize<List<AdminOp>>(File.ReadAllText(jobFile)) ?? new();
            results = Execute(ops);
        }
        catch (Exception ex)
        {
            results = new() { new AdminResult { Kind = "job", Success = false, Message = ex.Message } };
        }
        File.WriteAllText(resultFile, JsonSerializer.Serialize(results));
        return 0;
    }

    /// <summary>Führt Aufträge im aktuellen Prozess aus (ohne Admin für Benutzerbereiche nutzbar).</summary>
    public static List<AdminResult> Execute(IEnumerable<AdminOp> ops)
    {
        var list = new List<AdminResult>();
        foreach (var op in ops)
        {
            var r = new AdminResult { Kind = op.Kind, Target = op.Target };
            try
            {
                if (!Allowed.Contains(op.Kind)) throw new InvalidOperationException("Unbekannte Aktion.");
                r.Message = op.Kind.ToLowerInvariant() switch
                {
                    "restorepoint" => CreateRestorePoint(op.Target),
                    "enableprotection" => EnableProtection(op.Target),
                    "regdelete" => RegDelete(op.Target, op.Extra),
                    "recycle" => Recycle(op.Target),
                    "servicedelete" => Run("sc.exe", $"delete \"{op.Target}\""),
                    "servicestart" => Run("sc.exe", $"config \"{op.Target}\" start= {op.Extra}"),
                    "taskdelete" => Run("schtasks.exe", $"/Delete /TN \"{op.Target}\" /F"),
                    "taskenable" => Run("schtasks.exe", $"/Change /TN \"{op.Target}\" /ENABLE"),
                    "taskdisable" => Run("schtasks.exe", $"/Change /TN \"{op.Target}\" /DISABLE"),
                    "firewalldelete" => Run("netsh.exe", $"advfirewall firewall delete rule name=\"{op.Target}\""),
                    "regsetbinary" => RegSetBinary(op.Target, op.Extra),
                    _ => throw new InvalidOperationException("Unbekannte Aktion."),
                };
                r.Success = !r.Message.StartsWith("FEHLER", StringComparison.Ordinal);
                if (!r.Success) r.Message = r.Message["FEHLER".Length..].TrimStart(':', ' ');
            }
            catch (Exception ex)
            {
                r.Success = false;
                r.Message = ex is UnauthorizedAccessException or System.Security.SecurityException ? "Kein Zugriff (Adminrechte nötig)." : ex.Message;
            }
            list.Add(r);
        }
        return list;
    }

    private static string Run(string exe, string args)
    {
        var psi = new ProcessStartInfo(exe, args)
        {
            CreateNoWindow = true, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true,
        };
        using var p = Process.Start(psi)!;
        var o = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
        p.WaitForExit(30000);
        return p.ExitCode == 0 ? "OK" : "FEHLER: " + o.Trim().Replace("\r", " ").Replace("\n", " ");
    }

    // ───────────── Registry ─────────────

    /// <summary>Registry-Pfad „HKEY_LOCAL_MACHINE\SOFTWARE\X“ → (Wurzel, Unterschlüssel).</summary>
    public static (RegistryKey root, string sub) SplitKey(string path)
    {
        var i = path.IndexOf('\\');
        var hive = i < 0 ? path : path[..i];
        var sub = i < 0 ? "" : path[(i + 1)..];
        RegistryKey root = hive.ToUpperInvariant() switch
        {
            "HKEY_LOCAL_MACHINE" or "HKLM" => RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64),
            "HKEY_CURRENT_USER" or "HKCU" => RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64),
            "HKEY_CLASSES_ROOT" or "HKCR" => RegistryKey.OpenBaseKey(RegistryHive.ClassesRoot, RegistryView.Registry64),
            "HKEY_USERS" or "HKU" => RegistryKey.OpenBaseKey(RegistryHive.Users, RegistryView.Registry64),
            _ => throw new InvalidOperationException("Unbekannter Registry-Bereich: " + hive),
        };
        return (root, sub);
    }

    /// <summary>Sicherheitsnetz im Helfer: keine Wurzeln, keine Systembereiche (außer einzelnen Diensten).</summary>
    public static void EnsureRegistryAllowed(string keyPath, bool isValue = false)
    {
        var p = keyPath.TrimEnd('\\');
        var parts = p.Split('\\');
        if (parts.Length < 3) throw new InvalidOperationException("Zu allgemeiner Registry-Pfad – gesperrt.");
        var hive = parts[0].ToUpperInvariant();
        var rel = string.Join('\\', parts.Skip(1)).ToLowerInvariant();
        if (hive == "HKEY_CLASSES_ROOT") rel = @"software\classes\" + rel;
        rel = rel.Replace(@"software\wow6432node\", @"software\");

        if (rel.StartsWith(@"system\"))
        {
            // Einzige Ausnahme: ein einzelner (verwaister) Dienst
            if (!isValue && rel.StartsWith(@"system\currentcontrolset\services\") && parts.Length == 5) return;
            throw new InvalidOperationException("Systembereich der Registry – gesperrt.");
        }

        // Ausnahmen innerhalb von Microsoft-Bereichen: einzelne Programm-Einträge
        string[] allowedUnder =
        {
            @"software\microsoft\windows\currentversion\uninstall\",
            @"software\microsoft\windows\currentversion\app paths\",
        };
        string[] allowedValueKeys =
        {
            @"software\microsoft\windows\currentversion\run", @"software\microsoft\windows\currentversion\runonce",
            @"software\microsoft\windows\currentversion\explorer\startupapproved\",
        };
        if (isValue && allowedValueKeys.Any(a => rel == a || rel.StartsWith(a))) return;
        if (!isValue && allowedUnder.Any(a => rel.StartsWith(a) && rel.Length > a.Length && !rel[a.Length..].Contains('\\'))) return;

        // Kontextmenü-Container: nur einzelne Einträge darunter (…\shell\Name bzw. …\shellex\ContextMenuHandlers\Name) erlaubt
        string[] containers =
        {
            @"software\classes\*", @"software\classes\directory", @"software\classes\directory\background",
            @"software\classes\folder", @"software\classes\drive", @"software\classes\allfilesystemobjects",
        };
        foreach (var c in containers.OrderByDescending(x => x.Length))
        {
            foreach (var sub in new[] { @"\shell\", @"\shellex\contextmenuhandlers\" })
            {
                var pre = c + sub;
                if (!isValue && rel.StartsWith(pre) && rel.Length > pre.Length && !rel[pre.Length..].Contains('\\')) return;
            }
            if (rel == c || rel.StartsWith(c + "\\") || c.StartsWith(rel + "\\"))
                throw new InvalidOperationException("Gemeinsam genutzter Registry-Bereich – gesperrt.");
        }

        string[] protectedRoots =
        {
            @"software\microsoft", @"software\classes\clsid", @"software\classes\interface", @"software\classes\typelib",
            @"software\classes\appid", @"software\policies", @"software\classes\installer", @"software\classes\local settings",
            @"software\clients", @"software\registeredapplications", @"software\odbc",
        };
        foreach (var r in protectedRoots)
            if (rel == r || rel.StartsWith(r + "\\") || r.StartsWith(rel + "\\") || rel is "software" or @"software\classes")
                throw new InvalidOperationException("Geschützter Registry-Bereich – gesperrt.");
    }

    /// <summary>Schlüssel (oder Wert „Schlüssel|Wertname“) löschen – vorher als .reg-Datei sichern.</summary>
    private static string RegDelete(string target, string backupFile)
    {
        var bar = target.IndexOf('|');
        var keyPath = bar < 0 ? target : target[..bar];
        var value = bar < 0 ? null : target[(bar + 1)..];
        EnsureRegistryAllowed(keyPath, isValue: value != null);
        if (!string.IsNullOrEmpty(backupFile))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(backupFile)!);
            var exp = Run("reg.exe", $"export \"{keyPath}\" \"{backupFile}\" /y /reg:64");
            if (!exp.StartsWith("OK")) return "FEHLER: Sicherung fehlgeschlagen – nichts gelöscht. " + exp;
        }
        var (root, sub) = SplitKey(keyPath);
        using (root)
        {
            if (value != null)
            {
                using var k = root.OpenSubKey(sub, writable: true) ?? throw new InvalidOperationException("Schlüssel nicht gefunden.");
                k.DeleteValue(value, throwOnMissingValue: false);
            }
            else root.DeleteSubKeyTree(sub, throwOnMissingSubKey: false);
        }
        return "OK";
    }

    private static string RegSetBinary(string target, string hex)
    {
        var bar = target.IndexOf('|');
        EnsureRegistryAllowed(target[..bar], isValue: true);
        var (root, sub) = SplitKey(target[..bar]);
        using (root)
        {
            using var k = root.CreateSubKey(sub, writable: true);
            k.SetValue(target[(bar + 1)..], Convert.FromHexString(hex), RegistryValueKind.Binary);
        }
        return "OK";
    }

    // ───────────── Dateien ─────────────

    private static string Recycle(string path)
    {
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (ProtectionService.IsUnder(path, win) || Path.GetPathRoot(path)?.TrimEnd('\\').Length == path.TrimEnd('\\').Length)
            return "FEHLER: Geschützter Ort.";
        if (!File.Exists(path) && !Directory.Exists(path)) return "OK"; // schon weg
        var op = new NativeMethods.SHFILEOPSTRUCT
        {
            wFunc = NativeMethods.FO_DELETE, pFrom = path + "\0",
            fFlags = (ushort)(NativeMethods.FOF_ALLOWUNDO | NativeMethods.FOF_NOCONFIRMATION | NativeMethods.FOF_SILENT |
                              NativeMethods.FOF_NOERRORUI | NativeMethods.FOF_WANTNUKEWARNING),
        };
        int rc = NativeMethods.SHFileOperation(ref op);
        if (op.fAnyOperationsAborted) return "FEHLER: Abgebrochen.";
        if (rc != 0) return $"FEHLER: Windows meldet 0x{rc:X} (in Benutzung oder kein Zugriff).";
        return File.Exists(path) || Directory.Exists(path) ? "FEHLER: Noch vorhanden (in Benutzung?)." : "OK";
    }

    // ───────────── Wiederherstellungspunkt ─────────────

    /// <summary>Ist der Computerschutz eingeschaltet? (lesbar ohne Adminrechte, nicht 100 % genau pro Laufwerk)</summary>
    public static bool? ProtectionEnabled()
    {
        try
        {
            using var k = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore");
            if (k == null) return null;
            if (k.GetValue("DisableSR") is int d && d == 1) return false;
            if (k.GetValue("RPSessionInterval") is int i) return i != 0;
            return null;
        }
        catch { return null; }
    }

    private static List<DateTime> RestorePoints()
    {
        var list = new List<DateTime>();
        using var s = new ManagementObjectSearcher(@"root\default", "SELECT CreationTime FROM SystemRestore");
        foreach (ManagementObject o in s.Get())
            if (o["CreationTime"] is string t) list.Add(ManagementDateTimeConverter.ToDateTime(t));
        return list;
    }

    /// <summary>Ergebnis: „CREATED“, „SKIPPED24H|letzter Punkt“, „DISABLED“ oder FEHLER.</summary>
    private static string CreateRestorePoint(string description)
    {
        if (ProtectionEnabled() == false) return "FEHLER: DISABLED";
        var before = RestorePoints();
        using var cls = new ManagementClass(@"\\.\root\default", "SystemRestore", null);
        var inp = cls.GetMethodParameters("CreateRestorePoint");
        inp["Description"] = description.Length > 60 ? description[..60] : description;
        inp["RestorePointType"] = 1;   // APPLICATION_UNINSTALL
        inp["EventType"] = 100;        // BEGIN_SYSTEM_CHANGE
        var outp = cls.InvokeMethod("CreateRestorePoint", inp, null);
        var rc = Convert.ToInt32(outp?["ReturnValue"] ?? -1);
        var after = RestorePoints();
        if (after.Count > before.Count) return "CREATED";
        var last = before.Count > 0 ? before.Max() : (DateTime?)null;
        if (last is { } l && (DateTime.Now - l).TotalHours < 24) return $"FEHLER: SKIPPED24H|{l:dd.MM.yyyy HH:mm}";
        if (rc == 1058) return "FEHLER: DISABLED";
        return $"FEHLER: Windows hat keinen Wiederherstellungspunkt erstellt (Code {rc}).";
    }

    private static string EnableProtection(string drive)
    {
        using var cls = new ManagementClass(@"\\.\root\default", "SystemRestore", null);
        var inp = cls.GetMethodParameters("Enable");
        inp["Drive"] = string.IsNullOrEmpty(drive) ? @"C:\" : drive;
        var outp = cls.InvokeMethod("Enable", inp, null);
        var rc = Convert.ToInt32(outp?["ReturnValue"] ?? -1);
        return rc == 0 ? "OK" : $"FEHLER: Computerschutz konnte nicht eingeschaltet werden (Code {rc}).";
    }
}
