using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.Win32;

namespace PCAufraeumer.Services;

public enum AutostartSource { RunKey, RunOnce, StartupFolder, Task, StoreApp, Service }

/// <summary>Ein Programm, das mit Windows startet.</summary>
public sealed partial class AutostartEntry : ObservableObject
{
    public string Name { get; set; } = "";
    public string Publisher { get; set; } = "";
    public string Command { get; set; } = "";
    public string Exe { get; set; } = "";
    public string Location { get; set; } = "";
    public AutostartSource Source { get; set; }
    public bool? Signed { get; set; }
    public bool FileExists { get; set; } = true;
    public bool IsLocked { get; set; }
    public string LockReason { get; set; } = "";
    public bool NeedsAdmin { get; set; }
    public bool CanToggle { get; set; } = true;
    public bool IsAdvanced => Source == AutostartSource.Service;

    // Technische Angaben zum Schalten/Entfernen
    public string RegKey { get; set; } = "";
    public string ValueName { get; set; } = "";
    public string ApprovedKey { get; set; } = "";
    public string FilePath { get; set; } = "";
    public string TaskPath { get; set; } = "";
    public string StoreStateKey { get; set; } = "";
    public string ServiceName { get; set; } = "";

    [ObservableProperty] private bool _enabled;
    public ImageSource? Icon { get; set; }

    public string StatusText => Enabled ? "aktiv" : "deaktiviert";
    public string SignedText => Signed switch { true => "ja", false => "nein", _ => "–" };
    public string ExistsText => FileExists ? "ja" : "fehlt!";
    partial void OnEnabledChanged(bool value) => OnPropertyChanged(nameof(StatusText));
}

/// <summary>
/// Autostart-Manager: liest Run/RunOnce, Autostart-Ordner, geplante Aufgaben (Anmeldung/Start), Store-App-Autostarts
/// und – als „Fortgeschritten“ – automatisch startende Dienste. Schaltet wie der Task-Manager (StartupApproved),
/// also jederzeit umkehrbar und ohne Einträge zu löschen.
/// </summary>
public static class AutostartService
{
    private const string Approved = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved";

    /// <summary>Für Tests: nur diese Run-Schlüssel lesen.</summary>
    public static List<(string runKey, string approvedKey, string label, bool admin)>? RunKeysOverride { get; set; }

    public static List<(string runKey, string approvedKey, string label, bool admin)> RunKeys() => RunKeysOverride ?? new()
    {
        (@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKEY_CURRENT_USER\" + Approved + @"\Run", "Registry (Benutzer)", false),
        (@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", @"HKEY_LOCAL_MACHINE\" + Approved + @"\Run", "Registry (alle Benutzer)", true),
        (@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run", @"HKEY_LOCAL_MACHINE\" + Approved + @"\Run32", "Registry (alle Benutzer, 32-Bit)", true),
    };

    public static List<AutostartEntry> ReadAll(bool includeServices)
    {
        var list = new List<AutostartEntry>();
        void Safe(Action a, string what) { try { a(); } catch (Exception ex) { ErrorLog.Write($"Autostart: {what} nicht lesbar.", ex); } }
        Safe(() => ReadRun(list), "Run-Schlüssel");
        if (RunKeysOverride == null)
        {
            Safe(() => ReadRunOnce(list), "RunOnce");
            Safe(() => ReadStartupFolders(list), "Autostart-Ordner");
            Safe(() => ReadTasks(list), "Geplante Aufgaben");
            Safe(() => ReadStoreApps(list), "Store-App-Autostarts");
            if (includeServices) Safe(() => ReadServices(list), "Dienste");
        }
        foreach (var e in list) Finish(e);
        return list.OrderBy(e => e.IsAdvanced).ThenBy(e => e.Name, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    private static void Finish(AutostartEntry e)
    {
        if (e.Exe.Length > 0)
        {
            e.FileExists = File.Exists(e.Exe);
            if (e.FileExists)
            {
                try
                {
                    var vi = FileVersionInfo.GetVersionInfo(e.Exe);
                    if (e.Publisher.Length == 0) e.Publisher = vi.CompanyName ?? "";
                }
                catch { }
                e.Signed = Authenticode.IsSigned(e.Exe);
            }
        }
        // Windows-eigene und sicherheitsrelevante Einträge sind gesperrt
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        bool windowsFile = e.Exe.Length > 0 && ProtectionService.IsUnder(e.Exe, win) && e.Publisher.Contains("Microsoft", StringComparison.OrdinalIgnoreCase);
        bool security = new[] { "SecurityHealth", "Windows Defender", "MsMpEng", "WindowsDefender", "Windows Security" }
            .Any(s => e.Name.Contains(s, StringComparison.OrdinalIgnoreCase) || e.Command.Contains(s, StringComparison.OrdinalIgnoreCase));
        if (windowsFile || security || e.TaskPath.StartsWith(@"\Microsoft\", StringComparison.OrdinalIgnoreCase))
        {
            e.IsLocked = true;
            e.LockReason = security ? "Sicherheitsrelevant (Windows-Sicherheit)" : "Windows-eigener Eintrag";
        }
    }

    // ───────────── Registry Run ─────────────

    private static void ReadRun(List<AutostartEntry> list)
    {
        foreach (var (runKey, approvedKey, label, admin) in RunKeys())
        {
            foreach (var (name, data) in ReadValues(runKey))
            {
                var exe = ProgramInventory.ResolveExe(ProgramInventory.ExeFromCommand(data));
                list.Add(new AutostartEntry
                {
                    Name = name, Command = data, Exe = exe, Location = label, Source = AutostartSource.RunKey,
                    RegKey = runKey, ValueName = name, ApprovedKey = approvedKey, NeedsAdmin = admin,
                    Enabled = IsApproved(approvedKey, name),
                });
            }
        }
    }

    private static void ReadRunOnce(List<AutostartEntry> list)
    {
        foreach (var (key, label, admin) in new[]
                 {
                     (@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "Einmalig beim nächsten Start (Benutzer)", false),
                     (@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "Einmalig beim nächsten Start (alle)", true),
                 })
            foreach (var (name, data) in ReadValues(key))
                list.Add(new AutostartEntry
                {
                    Name = name, Command = data, Exe = ProgramInventory.ResolveExe(ProgramInventory.ExeFromCommand(data)), Location = label, Source = AutostartSource.RunOnce,
                    RegKey = key, ValueName = name, NeedsAdmin = admin, Enabled = true, CanToggle = false,
                });
    }

    private static List<(string name, string data)> ReadValues(string keyPath)
    {
        var list = new List<(string, string)>();
        try
        {
            var (root, sub) = AdminHelper.SplitKey(keyPath);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                if (k != null)
                    foreach (var n in k.GetValueNames())
                        if (k.GetValue(n) is string s && n.Length > 0) list.Add((n, Environment.ExpandEnvironmentVariables(s)));
            }
        }
        catch { }
        return list;
    }

    /// <summary>StartupApproved: erstes Byte gerade (02/06) = aktiv, ungerade (03/07) = deaktiviert, fehlt = aktiv.</summary>
    public static bool IsApproved(string approvedKey, string valueName)
    {
        try
        {
            var (root, sub) = AdminHelper.SplitKey(approvedKey);
            using (root)
            {
                using var k = root.OpenSubKey(sub);
                if (k?.GetValue(valueName) is byte[] b && b.Length > 0) return (b[0] & 1) == 0;
            }
        }
        catch { }
        return true;
    }

    public static string ApprovedBytes(bool enabled)
    {
        var b = new byte[12];
        b[0] = (byte)(enabled ? 0x02 : 0x03);
        if (!enabled) BitConverter.GetBytes(DateTime.Now.ToFileTime()).CopyTo(b, 4);
        return Convert.ToHexString(b);
    }

    // ───────────── Autostart-Ordner ─────────────

    private static void ReadStartupFolders(List<AutostartEntry> list)
    {
        foreach (var (folder, approved, label, admin) in new[]
                 {
                     (Environment.GetFolderPath(Environment.SpecialFolder.Startup), @"HKEY_CURRENT_USER\" + Approved + @"\StartupFolder", "Autostart-Ordner (Benutzer)", false),
                     (Environment.GetFolderPath(Environment.SpecialFolder.CommonStartup), @"HKEY_LOCAL_MACHINE\" + Approved + @"\StartupFolder", "Autostart-Ordner (alle)", true),
                 })
        {
            if (!Directory.Exists(folder)) continue;
            foreach (var f in Directory.GetFiles(folder))
            {
                var fn = Path.GetFileName(f);
                if (fn.Equals("desktop.ini", StringComparison.OrdinalIgnoreCase)) continue;
                var target = f.EndsWith(".lnk", StringComparison.OrdinalIgnoreCase)
                    ? StaTask.Run(() => ShortcutResolver.Resolve(f)).GetAwaiter().GetResult() : null;
                list.Add(new AutostartEntry
                {
                    Name = Path.GetFileNameWithoutExtension(f), Command = target != null ? (target.Target + " " + target.Arguments).Trim() : f,
                    Exe = target?.Target ?? f, Location = label, Source = AutostartSource.StartupFolder, FilePath = f,
                    ApprovedKey = approved, ValueName = fn, NeedsAdmin = admin, Enabled = IsApproved(approved, fn),
                });
            }
        }
    }

    // ───────────── Geplante Aufgaben ─────────────

    private static void ReadTasks(List<AutostartEntry> list)
    {
        var t = Type.GetTypeFromProgID("Schedule.Service");
        if (t == null) return;
        dynamic svc = Activator.CreateInstance(t)!;
        svc.Connect();
        void Walk(dynamic folder)
        {
            try
            {
                foreach (dynamic task in folder.GetTasks(1))
                {
                    try
                    {
                        string path = task.Path;
                        bool startup = false;
                        foreach (dynamic trig in task.Definition.Triggers)
                        {
                            int type = trig.Type;
                            if (type is 8 or 9) { startup = true; break; } // 8 = Systemstart, 9 = Anmeldung
                        }
                        if (!startup) continue;
                        string exe = "", args = "";
                        foreach (dynamic a in task.Definition.Actions)
                            if ((int)a.Type == 0) { exe = ProgramInventory.ResolveExe(Environment.ExpandEnvironmentVariables((string)a.Path).Trim('"')); args = a.Arguments ?? ""; break; }
                        list.Add(new AutostartEntry
                        {
                            Name = (string)task.Name, Command = (exe + " " + args).Trim(), Exe = exe, Location = "Geplante Aufgabe",
                            Source = AutostartSource.Task, TaskPath = path, Enabled = (bool)task.Enabled,
                            NeedsAdmin = !path.Contains(Environment.UserName, StringComparison.OrdinalIgnoreCase),
                        });
                    }
                    catch { }
                }
                foreach (dynamic sub in folder.GetFolders(0)) Walk(sub);
            }
            catch { }
        }
        Walk(svc.GetFolder("\\"));
    }

    // ───────────── Store-Apps ─────────────

    private const string AppModel = @"HKEY_CURRENT_USER\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData";

    /// <summary>Für die Anzeige: Paketfamilie → App-Name (aus der Programmliste).</summary>
    public static Func<string, string?>? StoreNameLookup { get; set; }

    private static void ReadStoreApps(List<AutostartEntry> list)
    {
        var (root, sub) = AdminHelper.SplitKey(AppModel);
        using (root)
        {
            using var k = root.OpenSubKey(sub);
            if (k == null) return;
            foreach (var pfn in k.GetSubKeyNames())
            {
                using var pk = k.OpenSubKey(pfn);
                if (pk == null) continue;
                foreach (var taskId in pk.GetSubKeyNames())
                {
                    using var tk = pk.OpenSubKey(taskId);
                    if (tk?.GetValue("State") is not int state) continue;
                    // 0/1 = aus (1 = vom Benutzer), 2 = an, 3/4 = per Richtlinie festgelegt
                    list.Add(new AutostartEntry
                    {
                        Name = StoreNameLookup?.Invoke(pfn) ?? pfn.Split('_')[0], Command = $"{pfn} ({taskId})", Location = "Store-App",
                        Source = AutostartSource.StoreApp, StoreStateKey = $@"{AppModel}\{pfn}\{taskId}", Enabled = state is 2 or 4,
                        IsLocked = state is 3 or 4, LockReason = state is 3 or 4 ? "Per Richtlinie festgelegt" : "",
                    });
                }
            }
        }
    }

    // ───────────── Dienste (Fortgeschritten) ─────────────

    private static void ReadServices(List<AutostartEntry> list)
    {
        using var k = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services");
        if (k == null) return;
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var disabledByUs = DisabledServices();
        foreach (var name in k.GetSubKeyNames())
        {
            using var s = k.OpenSubKey(name);
            if (s == null) continue;
            int type = s.GetValue("Type") is int t ? t : 0;
            int start = s.GetValue("Start") is int st ? st : 4;
            if ((type & 0x30) == 0) continue; // nur Win32-Dienste (keine Treiber)
            var img = Environment.ExpandEnvironmentVariables(s.GetValue("ImagePath") as string ?? "");
            var exe = ProgramInventory.ResolveExe(ProgramInventory.ExeFromCommand(img));
            if (exe.Length == 0 || ProtectionService.IsUnder(exe, win)) continue; // Windows-Dienste ausblenden
            if (start != 2 && !disabledByUs.Contains(name)) continue;
            var display = s.GetValue("DisplayName") as string ?? name;
            if (display.StartsWith('@')) display = name;
            list.Add(new AutostartEntry
            {
                Name = display, Command = img, Exe = exe, Location = "Dienst (Fortgeschritten)", Source = AutostartSource.Service,
                ServiceName = name, Enabled = start == 2, NeedsAdmin = true,
            });
        }
    }

    private static string DisabledServicesFile => Path.Combine(AppPaths.BaseDir, "autostart-dienste.json");

    public static HashSet<string> DisabledServices()
    {
        try
        {
            if (File.Exists(DisabledServicesFile))
                return new HashSet<string>(System.Text.Json.JsonSerializer.Deserialize<List<string>>(File.ReadAllText(DisabledServicesFile)) ?? new(), StringComparer.OrdinalIgnoreCase);
        }
        catch { }
        return new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    }

    public static void RememberServiceDisabled(string name, bool disabled)
    {
        var set = DisabledServices();
        if (disabled) set.Add(name); else set.Remove(name);
        Json.WriteAtomic(DisabledServicesFile, set.ToList());
    }

    // ───────────── Schalten / Entfernen ─────────────

    /// <summary>Schaltet einen Eintrag um. Benutzer-Einträge direkt, alles andere über den Admin-Helfer (🛡).</summary>
    public static async Task<string?> SetEnabledAsync(AutostartEntry e, bool enabled)
    {
        if (e.IsLocked) return "Gesperrt: " + e.LockReason;
        if (!e.CanToggle) return "Dieser Eintrag lässt sich nicht abschalten (läuft nur einmal).";
        AdminOp op;
        switch (e.Source)
        {
            case AutostartSource.RunKey:
            case AutostartSource.StartupFolder:
                op = new AdminOp { Kind = "regsetbinary", Target = e.ApprovedKey + "|" + e.ValueName, Extra = ApprovedBytes(enabled) };
                break;
            case AutostartSource.StoreApp:
            {
                var (root, sub) = AdminHelper.SplitKey(e.StoreStateKey);
                using (root) { using var k = root.OpenSubKey(sub, writable: true); k?.SetValue("State", enabled ? 2 : 1, RegistryValueKind.DWord); }
                return null;
            }
            case AutostartSource.Task:
                try
                {
                    dynamic svc = Activator.CreateInstance(Type.GetTypeFromProgID("Schedule.Service")!)!;
                    svc.Connect();
                    dynamic task = svc.GetFolder(Path.GetDirectoryName(e.TaskPath)?.Replace('/', '\\') is { Length: > 0 } f ? f : "\\").GetTask(Path.GetFileName(e.TaskPath));
                    task.Enabled = enabled;
                    return null;
                }
                catch { op = new AdminOp { Kind = enabled ? "taskenable" : "taskdisable", Target = e.TaskPath }; }
                break;
            case AutostartSource.Service:
                op = new AdminOp { Kind = "servicestart", Target = e.ServiceName, Extra = enabled ? "auto" : "demand" };
                break;
            default:
                return "Nicht unterstützt.";
        }

        var r = e.NeedsAdmin || e.Source is AutostartSource.Service or AutostartSource.Task
            ? (await AdminHelper.RunElevatedAsync(new[] { op }))[0]
            : AdminHelper.Execute(new[] { op })[0];
        if (r.Success && e.Source == AutostartSource.Service) RememberServiceDisabled(e.ServiceName, !enabled);
        return r.Success ? null : r.Message;
    }

    /// <summary>Verwaisten Eintrag entfernen (Datei fehlt). Registry wird vorher gesichert, Verknüpfungen gehen in den Papierkorb.</summary>
    public static async Task<string?> RemoveOrphanAsync(AutostartEntry e)
    {
        if (e.IsLocked) return "Gesperrt: " + e.LockReason;
        if (e.FileExists) return "Nur Einträge, deren Programmdatei fehlt, können entfernt werden.";
        var backup = Path.Combine(LeftoverDeleter.BackupDir, DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-autostart.reg");
        var ops = new List<AdminOp>();
        switch (e.Source)
        {
            case AutostartSource.RunKey:
            case AutostartSource.RunOnce:
                ops.Add(new AdminOp { Kind = "regdelete", Target = e.RegKey + "|" + e.ValueName, Extra = backup });
                break;
            case AutostartSource.StartupFolder:
                ops.Add(new AdminOp { Kind = "recycle", Target = e.FilePath });
                break;
            case AutostartSource.Task:
                ops.Add(new AdminOp { Kind = "taskdelete", Target = e.TaskPath });
                break;
            default:
                return "Für diesen Eintrag nicht unterstützt.";
        }
        var r = e.NeedsAdmin || e.Source == AutostartSource.Task ? (await AdminHelper.RunElevatedAsync(ops))[0] : AdminHelper.Execute(ops)[0];
        return r.Success ? null : r.Message;
    }
}

/// <summary>Prüfung der digitalen Signatur (Authenticode) einer Datei.</summary>
public static class Authenticode
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WINTRUST_FILE_INFO
    {
        public uint cbStruct; public string pcwszFilePath; public IntPtr hFile; public IntPtr pgKnownSubject;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WINTRUST_DATA
    {
        public uint cbStruct; public IntPtr pPolicyCallbackData; public IntPtr pSIPClientData; public uint dwUIChoice;
        public uint fdwRevocationChecks; public uint dwUnionChoice; public IntPtr pFile; public uint dwStateAction;
        public IntPtr hWVTStateData; public IntPtr pwszURLReference; public uint dwProvFlags; public uint dwUIContext; public IntPtr pSignatureSettings;
    }

    [DllImport("wintrust.dll", CharSet = CharSet.Unicode)]
    private static extern int WinVerifyTrust(IntPtr hwnd, [MarshalAs(UnmanagedType.LPStruct)] Guid action, ref WINTRUST_DATA data);

    private static readonly Guid GenericVerifyV2 = new("00AAC56B-CD44-11d0-8CC2-00C04FC295EE");

    public static bool? IsSigned(string file)
    {
        try
        {
            var fi = new WINTRUST_FILE_INFO { cbStruct = (uint)Marshal.SizeOf<WINTRUST_FILE_INFO>(), pcwszFilePath = file };
            var pFile = Marshal.AllocHGlobal(Marshal.SizeOf(fi));
            try
            {
                Marshal.StructureToPtr(fi, pFile, false);
                var data = new WINTRUST_DATA
                {
                    cbStruct = (uint)Marshal.SizeOf<WINTRUST_DATA>(), dwUIChoice = 2 /* keine UI */, fdwRevocationChecks = 0,
                    dwUnionChoice = 1 /* Datei */, pFile = pFile, dwStateAction = 0, dwProvFlags = 0x40 /* nur Cache, kein Netz */,
                };
                return WinVerifyTrust(new IntPtr(-1), GenericVerifyV2, ref data) == 0;
            }
            finally
            {
                Marshal.DestroyStructure<WINTRUST_FILE_INFO>(pFile);
                Marshal.FreeHGlobal(pFile);
            }
        }
        catch { return null; }
    }
}
