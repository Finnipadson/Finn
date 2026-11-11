using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using Xunit.Abstractions;

namespace PCAufraeumer.Tests;

/// <summary>
/// Harmloses Test-Programm „PCA-Testprogramm“ (nur Benutzerbereich, keine Adminrechte):
/// Dateien in %LOCALAPPDATA%\Programs, AppData-Daten, HKCU-Registry, Autostart-Eintrag, Startmenü-Verknüpfung.
/// Sein Deinstaller entfernt absichtlich nur einen Teil – der Rest sind „Reste“ für die Restesuche.
/// </summary>
public sealed class TestProgram : IDisposable
{
    public const string Name = "PCA-Testprogramm";
    public const string Publisher = "PCA Testfirma";
    public const string Neighbor = "PCA-Nachbarprogramm";
    public static string Local => Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    public static string Roaming => Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    public static string InstallDir => Path.Combine(Local, "Programs", Name);
    public static string NeighborDir => Path.Combine(Local, "Programs", Neighbor);
    public static string StartMenuDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), Name);
    public const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\" + Name;
    public const string NeighborKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\" + Neighbor;
    public const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public void Install(bool withNeighbor = true)
    {
        Cleanup();
        Directory.CreateDirectory(InstallDir);
        File.WriteAllBytes(Path.Combine(InstallDir, "PCATestApp.exe"), new byte[2048]);
        File.WriteAllText(Path.Combine(InstallDir, "daten.dat"), "Testdaten");
        File.WriteAllText(Path.Combine(InstallDir, "uninstall.cmd"),
            "@echo off\r\n" +
            $"del /q \"{InstallDir}\\PCATestApp.exe\"\r\n" +
            $"reg delete \"HKCU\\{UninstallKey}\" /f >nul\r\n" +
            "exit /b 0\r\n");
        var cfg = Path.Combine(Roaming, Publisher, Name);
        Directory.CreateDirectory(cfg);
        File.WriteAllText(Path.Combine(cfg, "einstellungen.ini"), "[x]\r\na=1");
        Directory.CreateDirectory(Path.Combine(Local, Name, "Cache"));
        File.WriteAllText(Path.Combine(Local, Name, "Cache", "c.bin"), "c");
        using (var k = Registry.CurrentUser.CreateSubKey(UninstallKey))
        {
            k.SetValue("DisplayName", Name);
            k.SetValue("DisplayVersion", "1.2.3");
            k.SetValue("Publisher", Publisher);
            k.SetValue("InstallLocation", InstallDir);
            k.SetValue("DisplayIcon", Path.Combine(InstallDir, "PCATestApp.exe"));
            k.SetValue("UninstallString", $"cmd.exe /c \"\"{Path.Combine(InstallDir, "uninstall.cmd")}\"\"");
            k.SetValue("EstimatedSize", 3, RegistryValueKind.DWord);
        }
        using (var k = Registry.CurrentUser.CreateSubKey($@"Software\{Publisher}\{Name}")) k.SetValue("Sprache", "de");
        using (var k = Registry.CurrentUser.CreateSubKey($@"Software\{Name}")) k.SetValue("Zuletzt", "heute");
        using (var k = Registry.CurrentUser.CreateSubKey(RunKey)) k.SetValue(Name, $"\"{Path.Combine(InstallDir, "PCATestApp.exe")}\" --tray");
        Directory.CreateDirectory(StartMenuDir);
        StaTask.Run(() => { ShortcutResolver.CreateLnk(Path.Combine(StartMenuDir, Name + ".lnk"), Path.Combine(InstallDir, "PCATestApp.exe")); return 0; }).Wait();

        if (withNeighbor)
        {
            Directory.CreateDirectory(NeighborDir);
            File.WriteAllBytes(Path.Combine(NeighborDir, "Nachbar.exe"), new byte[100]);
            Directory.CreateDirectory(Path.Combine(Roaming, Publisher, Neighbor));
            using var k = Registry.CurrentUser.CreateSubKey(NeighborKey);
            k.SetValue("DisplayName", Neighbor);
            k.SetValue("Publisher", Publisher);
            k.SetValue("InstallLocation", NeighborDir);
            k.SetValue("UninstallString", "cmd.exe /c exit");
        }
    }

    public static void Cleanup()
    {
        foreach (var d in new[] { InstallDir, NeighborDir, Path.Combine(Roaming, Publisher), Path.Combine(Local, Name), StartMenuDir })
            try { if (Directory.Exists(d)) Directory.Delete(d, true); } catch { }
        foreach (var k in new[] { UninstallKey, NeighborKey, $@"Software\{Publisher}", $@"Software\{Name}" })
            try { Registry.CurrentUser.DeleteSubKeyTree(k, false); } catch { }
        try { using var r = Registry.CurrentUser.OpenSubKey(RunKey, true); r?.DeleteValue(Name, false); } catch { }
    }

    public void Dispose() => Cleanup();
}

[Collection("seq")]
public class ProgramTests : IDisposable
{
    private readonly ITestOutputHelper _out;
    private readonly TestFolder _t = new();
    public ProgramTests(ITestOutputHelper o) => _out = o;
    public void Dispose() { TestProgram.Cleanup(); _t.Dispose(); }

    private static InstalledProgram FindTestProgram() =>
        new ProgramInventory().ReadRegistry().Single(p => p.Name == TestProgram.Name);

    [Fact]
    public void Inventory_reads_test_program_with_all_details()
    {
        using var tp = new TestProgram();
        tp.Install();
        var p = FindTestProgram();
        Assert.Equal("1.2.3", p.Version);
        Assert.Equal(TestProgram.Publisher, p.Publisher);
        Assert.Equal(TestProgram.InstallDir, p.InstallLocation);
        Assert.Equal(3 * 1024, p.Size);
        Assert.EndsWith("PCATestApp.exe", p.MainExe);
        Assert.Equal(ProgramKind.Programm, p.Kind);
        Assert.False(p.IsOrphaned);
        Assert.StartsWith(@"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\", p.RegistryPath);
    }

    [Fact]
    public async Task Full_uninstall_finds_and_removes_leftovers_but_respects_shared_publisher_folder()
    {
        AppPaths.OverrideBaseDir(Path.Combine(_t.Root, "_appdata"));
        using var tp = new TestProgram();
        tp.Install(withNeighbor: true);
        var p = FindTestProgram();
        var footprint = LeftoverScanner.Footprint(p);
        Assert.Contains("PCATestApp.exe", footprint.ExeNames);

        // 1) Eigener Deinstaller des Programms
        var res = await UninstallRunner.RunAsync(p, new Progress<string>(), CancellationToken.None);
        _out.WriteLine($"Deinstaller: {res.Outcome} – {res.Message}");
        Assert.Equal(UninstallOutcome.Erfolgreich, res.Outcome);
        Assert.False(File.Exists(Path.Combine(TestProgram.InstallDir, "PCATestApp.exe")));

        // 2) Restesuche (Moderat) – mit der echten Programmliste als „noch installiert“
        var remaining = new ProgramInventory().ReadAll();
        var scanner = new LeftoverScanner(new ProgramSettings(), remaining);
        var found = await StaTask.Run(() => scanner.Scan(footprint, LeftoverMode.Moderat, null, CancellationToken.None));
        foreach (var f in found) _out.WriteLine($"{f.ConfidenceLabel,-15} {f.KindLabel,-10} {f.Display}   [{f.Reason}]");

        string Roam(string s) => Path.Combine(TestProgram.Roaming, s);
        Assert.Contains(found, f => f.Path == TestProgram.InstallDir && f.IsSafe);
        Assert.Contains(found, f => f.Path == Roam(Path.Combine(TestProgram.Publisher, TestProgram.Name)) && f.IsSafe);
        Assert.Contains(found, f => f.Path == Path.Combine(TestProgram.Local, TestProgram.Name) && f.IsSafe);
        Assert.Contains(found, f => f.Path == TestProgram.StartMenuDir && f.IsSafe);
        Assert.Contains(found, f => f.Path.EndsWith($@"SOFTWARE\{TestProgram.Publisher}\{TestProgram.Name}", StringComparison.OrdinalIgnoreCase) && f.IsSafe);
        Assert.Contains(found, f => f.Path.EndsWith($@"SOFTWARE\{TestProgram.Name}", StringComparison.OrdinalIgnoreCase) && f.IsSafe);
        Assert.Contains(found, f => f.Kind == LeftoverKind.RegistryWert && f.Path.EndsWith("|" + TestProgram.Name) && f.IsSafe);
        // Herstellerordner wird noch vom Nachbarprogramm genutzt → NIE vorschlagen
        Assert.DoesNotContain(found, f => f.Path.Equals(Roam(TestProgram.Publisher), StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(found, f => f.Path.EndsWith(@"SOFTWARE\" + TestProgram.Publisher, StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(found, f => f.Path.Contains(TestProgram.Neighbor));
        // Keine Fehlalarme auf dem echten System: jeder Fund gehört zum Testprogramm
        Assert.All(found, f => Assert.Contains("PCA", f.Path, StringComparison.OrdinalIgnoreCase));
        Assert.All(found, f => Assert.False(f.IsChecked)); // standardmäßig NICHTS ausgewählt

        // 3) Alle sicheren Funde entfernen (Benutzerbereich → keine Adminrechte nötig)
        var safe = found.Where(f => f.IsSafe).ToList();
        var log = new DeleteLogService();
        var (ok, failed, backup) = await new LeftoverDeleter(log).DeleteAsync(safe, null);
        foreach (var s in safe) _out.WriteLine($"{s.Status}: {s.Path}");
        Assert.Equal(0, failed);
        Assert.Equal(safe.Count, ok);
        Assert.False(Directory.Exists(TestProgram.InstallDir));
        Assert.False(Directory.Exists(Roam(Path.Combine(TestProgram.Publisher, TestProgram.Name))));
        Assert.True(Directory.Exists(Roam(Path.Combine(TestProgram.Publisher, TestProgram.Neighbor)))); // Nachbar unberührt
        Assert.Null(Registry.CurrentUser.OpenSubKey($@"Software\{TestProgram.Name}"));
        using (var run = Registry.CurrentUser.OpenSubKey(TestProgram.RunKey)) Assert.Null(run?.GetValue(TestProgram.Name));
        Assert.Contains(log.ReadAll(), e => e.Method.StartsWith("Rest entfernt") && e.Success);

        // 4) Registry-Sicherung lässt sich wieder einspielen
        var backups = Directory.GetFiles(backup, "*.reg");
        Assert.NotEmpty(backups);
        var keyBackup = backups.First(b => File.ReadAllText(b).Contains(@"\SOFTWARE\PCA-Testprogramm]", StringComparison.OrdinalIgnoreCase) ||
                                           File.ReadAllText(b).Contains(@"\Software\PCA-Testprogramm]", StringComparison.OrdinalIgnoreCase));
        var psi = new System.Diagnostics.ProcessStartInfo("reg.exe", $"import \"{keyBackup}\"") { CreateNoWindow = true, UseShellExecute = false };
        using (var pr = System.Diagnostics.Process.Start(psi)!) pr.WaitForExit(10000);
        Assert.NotNull(Registry.CurrentUser.OpenSubKey($@"Software\{TestProgram.Name}"));
    }

    [Fact]
    public void Protection_rules_never_offer_shared_or_system_locations()
    {
        var installed = new ProgramInventory().ReadAll();
        var scanner = new LeftoverScanner(new ProgramSettings { ProtectedPaths = { @"D:\MeinOrdner", @"HKEY_CURRENT_USER\Software\MeinSchutz" } }, installed);
        var f = new ProgramFootprint { Id = "x", Name = "Irgendwas" };
        string PF(string s) => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), s);
        string Roam(string s) => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), s);

        Assert.NotNull(scanner.FileBlockReason(@"C:\Windows\System32\drivers", f));
        Assert.NotNull(scanner.FileBlockReason(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), f));
        Assert.NotNull(scanner.FileBlockReason(PF(@"Common Files\Irgendwas"), f));
        Assert.NotNull(scanner.FileBlockReason(Roam(@"Microsoft\Irgendwas"), f));
        Assert.NotNull(scanner.FileBlockReason(PF("dotnet"), f));
        Assert.NotNull(scanner.FileBlockReason(PF("Microsoft Visual C++ 2015 Redistributable"), f));
        Assert.NotNull(scanner.FileBlockReason(Roam(""), f));
        Assert.NotNull(scanner.FileBlockReason(@"D:\MeinOrdner\Sub", f));
        // Ordner eines anderen installierten Programms (z. B. NVIDIA, Steam) sind tabu
        var other = installed.First(p => p.InstallLocation.Length > 3 && Directory.Exists(p.InstallLocation));
        Assert.NotNull(scanner.FileBlockReason(other.InstallLocation, f));
        _out.WriteLine("Geschützt als anderes Programm: " + other.InstallLocation);
        // Normale Programmordner sind erlaubt
        Assert.Null(scanner.FileBlockReason(Roam("IrgendwasNeues"), f));
        Assert.Null(scanner.FileBlockReason(Path.Combine(TestProgram.Local, "Programs", "IrgendwasNeues"), f));

        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Irgendwas", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Irgendwas", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Classes\CLSID\{00000000-0000-0000-0000-000000000000}", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Classes\*", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Classes\*\shell", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\MeinSchutz\X", false, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software", false, f));
        Assert.Null(scanner.RegistryBlockReason(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\IrgendeinDienst", false, f));
        Assert.Null(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Irgendwas", false, f));
        Assert.Null(scanner.RegistryBlockReason(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Irgendwas", false, f));
        Assert.Null(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Classes\*\shell\Irgendwas", false, f));
        Assert.Null(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", true, f));
        Assert.NotNull(scanner.RegistryBlockReason(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", false, f));
    }

    [Theory]
    [InlineData(LeftoverMode.Sicher)]
    [InlineData(LeftoverMode.Moderat)]
    [InlineData(LeftoverMode.Erweitert)]
    public async Task Real_programs_never_produce_shared_or_system_findings(LeftoverMode mode)
    {
        // Nur lesend: Restesuche für ein echtes, installiertes Programm (als wäre es weg) – darf nichts Gemeinsames vorschlagen.
        var installed = new ProgramInventory().ReadAll();
        var target = installed.FirstOrDefault(p => p.Name.StartsWith("Mozilla Firefox", StringComparison.OrdinalIgnoreCase)) ??
                     installed.First(p => p.Kind == ProgramKind.Programm && p.InstallLocation.Length > 3);
        var others = installed.Where(p => p.Id != target.Id).ToList();
        var scanner = new LeftoverScanner(new ProgramSettings(), others) { ScanSystemObjects = false };
        var found = await StaTask.Run(() => scanner.Scan(LeftoverScanner.Footprint(target), mode, null, CancellationToken.None));
        _out.WriteLine($"{target.Name}: {found.Count} Funde im Modus {mode}");
        foreach (var f in found.Take(60)) _out.WriteLine($"  {f.ConfidenceLabel,-15} {f.Display}");
        var win = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        foreach (var f in found)
        {
            Assert.False(f.IsFileSystem && ProtectionService.IsUnder(f.Path, win), f.Path);
            Assert.DoesNotContain(@"\Common Files", f.Path, StringComparison.OrdinalIgnoreCase);
            Assert.False(f.Path.Contains(@"\Microsoft\", StringComparison.OrdinalIgnoreCase) && !f.Path.Contains(@"\CurrentVersion\Uninstall\") &&
                         !f.Path.Contains(@"\CurrentVersion\Run") && !f.Path.Contains(@"\Start Menu\"), f.Path);
            // Nichts, was einem anderen installierten Programm gehört (Name, .exe oder Hersteller)
            var leaf = LeftoverScanner.Compact(f.IsFileSystem ? Path.GetFileNameWithoutExtension(f.Path) : f.Path.Split('|')[0].Split('\\')[^1]);
            // (Verknüpfungen werden über ihr Ziel geprüft – zeigen sie in den Ordner des Zielprogramms, gehören sie dazu.)
            if (f.Reason.StartsWith("Verknüpfung")) continue;
            Assert.False(others.Any(o => LeftoverScanner.Compact(LeftoverScanner.CleanName(o.Name)) == leaf ||
                                         (o.MainExe.Length > 0 && LeftoverScanner.Compact(Path.GetFileNameWithoutExtension(o.MainExe)) == leaf)) &&
                         f.Kind is not (LeftoverKind.RegistryWert) && !f.Path.EndsWith(target.RegistryPath.Split('\\')[^1]), $"gehört anderem Programm: {f.Path}");
            Assert.False(f.Path.StartsWith(@"HKEY_LOCAL_MACHINE\SYSTEM", StringComparison.OrdinalIgnoreCase), f.Path);
            Assert.False(others.Any(o => o.InstallLocation.Length > 3 && f.IsFileSystem && ProtectionService.IsUnder(f.Path, o.InstallLocation)), f.Path);
        }
    }

    [Fact]
    public async Task Recording_finds_exactly_what_the_setup_created_and_feeds_the_leftover_scan()
    {
        var root = Path.Combine(_t.Root, "Aufzeichnung");
        Directory.CreateDirectory(Path.Combine(root, "Vorhanden"));
        File.WriteAllText(Path.Combine(root, "Vorhanden", "alt.txt"), "alt");
        const string regRoot = @"Software\PCA-RecTest";
        Registry.CurrentUser.CreateSubKey(regRoot + @"\Vorhanden")!.Dispose();
        InstallRecorder.FileRootsOverride = new() { root };
        InstallRecorder.KeyRootsOverride = new() { @"HKEY_CURRENT_USER\" + regRoot };
        InstallRecorder.FolderOverride = Path.Combine(_t.Root, "Aufzeichnungen");
        try
        {
            var before = InstallRecorder.Take(null, CancellationToken.None);
            // „Setup“ legt an:
            Directory.CreateDirectory(Path.Combine(root, "RecTestApp", "bin"));
            File.WriteAllText(Path.Combine(root, "RecTestApp", "bin", "app.exe"), "x");
            File.WriteAllText(Path.Combine(root, "Vorhanden", "neu.cfg"), "neu");
            File.WriteAllText(Path.Combine(root, "Vorhanden", "alt.txt"), "geändert!");
            Registry.CurrentUser.CreateSubKey(regRoot + @"\RecTestApp\Settings")!.Dispose();
            var after = InstallRecorder.Take(null, CancellationToken.None);

            var rec = InstallRecorder.Diff(before, after, "RecTestApp-Setup.exe", "C:\\x\\RecTestApp-Setup.exe");
            Assert.Equal(new[] { Path.Combine(root, "RecTestApp") }, rec.NewDirectories);          // nur der oberste neue Ordner
            Assert.Equal(new[] { Path.Combine(root, "Vorhanden", "neu.cfg") }, rec.NewFiles);
            Assert.Contains(Path.Combine(root, "Vorhanden", "alt.txt"), rec.ChangedFiles);
            Assert.Equal(new[] { @"HKEY_CURRENT_USER\" + regRoot + @"\RecTestApp" }, rec.NewKeys);
            InstallRecorder.Save(rec);
            Assert.Single(InstallRecorder.LoadAll());

            // Restesuche mit Aufzeichnung: neu angelegte Dinge werden gefunden, vorhandene nicht
            var scanner = new LeftoverScanner(new ProgramSettings(), new List<InstalledProgram>())
            {
                RootsOverride = new(), RegistryRootsOverride = new(), ScanSystemObjects = false,
            };
            var fp = new ProgramFootprint { Id = "rec", Name = "RecTestApp", Recording = rec };
            var found = await StaTask.Run(() => scanner.Scan(fp, LeftoverMode.Sicher, null, CancellationToken.None));
            Assert.Contains(found, f => f.Path == Path.Combine(root, "RecTestApp") && f.IsSafe);
            Assert.Contains(found, f => f.Path == @"HKEY_CURRENT_USER\" + regRoot + @"\RecTestApp" && f.IsSafe);
            // neu.cfg passt nicht zum Namen → nur „wahrscheinlich“ (im Modus Sicher daher nicht dabei)
            Assert.DoesNotContain(found, f => f.Path.EndsWith("neu.cfg"));
            Assert.DoesNotContain(found, f => f.Path.EndsWith("alt.txt"));
        }
        finally
        {
            InstallRecorder.FileRootsOverride = null;
            InstallRecorder.KeyRootsOverride = null;
            InstallRecorder.FolderOverride = null;
            Registry.CurrentUser.DeleteSubKeyTree(regRoot, false);
        }
    }

    [Fact]
    public async Task Autostart_toggle_works_like_task_manager_and_is_reversible()
    {
        // Echter HKCU-Run-Eintrag (harmlos, wird danach entfernt) – genau wie der Task-Manager schaltet
        const string name = "PCA-Autostart-Test";
        var approved = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
        // Harmlose Dummy-Datei (wird nie gestartet) – eine Windows-Datei wie cmd.exe wäre korrekterweise gesperrt.
        var dummy = _t.File("PCA-Autostart-Dummy.exe", new byte[64]);
        using (var run = Registry.CurrentUser.CreateSubKey(TestProgram.RunKey)) run.SetValue(name, $"\"{dummy}\" --minimiert");
        try
        {
            var e = AutostartService.ReadAll(false).Single(x => x.Name == name);
            Assert.True(e.Enabled);
            Assert.Equal(AutostartSource.RunKey, e.Source);
            Assert.False(e.IsLocked);

            Assert.Null(await AutostartService.SetEnabledAsync(e, false));
            using (var k = Registry.CurrentUser.OpenSubKey(approved))
            {
                var b = (byte[])k!.GetValue(name)!;
                Assert.Equal(0x03, b[0]);         // deaktiviert (wie Task-Manager)
                Assert.Equal(12, b.Length);
            }
            Assert.False(AutostartService.ReadAll(false).Single(x => x.Name == name).Enabled);
            using (var run = Registry.CurrentUser.OpenSubKey(TestProgram.RunKey)) Assert.NotNull(run!.GetValue(name)); // nichts gelöscht

            Assert.Null(await AutostartService.SetEnabledAsync(e, true));
            Assert.True(AutostartService.ReadAll(false).Single(x => x.Name == name).Enabled);

            // Verwaister Eintrag (Datei fehlt) kann entfernt werden – vorhandener nicht
            Assert.NotNull(await AutostartService.RemoveOrphanAsync(e));
            using (var run = Registry.CurrentUser.CreateSubKey(TestProgram.RunKey)) run.SetValue(name, @"C:\gibtsnicht\weg.exe");
            var orphan = AutostartService.ReadAll(false).Single(x => x.Name == name);
            Assert.False(orphan.FileExists);
            Assert.Null(await AutostartService.RemoveOrphanAsync(orphan));
            using (var run = Registry.CurrentUser.OpenSubKey(TestProgram.RunKey)) Assert.Null(run!.GetValue(name));
        }
        finally
        {
            using (var run = Registry.CurrentUser.OpenSubKey(TestProgram.RunKey, true)) run?.DeleteValue(name, false);
            using (var k = Registry.CurrentUser.OpenSubKey(approved, true)) k?.DeleteValue(name, false);
        }
    }

    [Fact]
    public void Windows_security_autostart_is_locked()
    {
        var all = AutostartService.ReadAll(false);
        foreach (var e in all.Where(e => e.Name.Contains("SecurityHealth", StringComparison.OrdinalIgnoreCase)))
            Assert.True(e.IsLocked);
        foreach (var e in all.Where(e => e.TaskPath.StartsWith(@"\Microsoft\", StringComparison.OrdinalIgnoreCase)))
            Assert.True(e.IsLocked);
    }

    [Fact]
    public void Msi_and_quoted_uninstall_commands_are_built_correctly()
    {
        var msi = new InstalledProgram { ProductCode = "{11111111-2222-3333-4444-555555555555}" };
        Assert.Equal(("msiexec.exe", "/x {11111111-2222-3333-4444-555555555555}"), UninstallRunner.BuildCommand(msi));
        var msiI = new InstalledProgram { UninstallString = "MsiExec.exe /I{11111111-2222-3333-4444-555555555555}" };
        Assert.Equal(("msiexec.exe", "/x {11111111-2222-3333-4444-555555555555}"), UninstallRunner.BuildCommand(msiI));
        var q = new InstalledProgram { UninstallString = "\"C:\\Program Files\\App X\\unins000.exe\" /SILENT" };
        Assert.Equal((@"C:\Program Files\App X\unins000.exe", "/SILENT"), UninstallRunner.BuildCommand(q));
        var plain = new InstalledProgram { UninstallString = @"C:\Tools\uninst.exe /S" };
        Assert.Equal((@"C:\Tools\uninst.exe", "/S"), UninstallRunner.BuildCommand(plain));
    }

    [Fact]
    public void Program_category_change_also_applies_to_desktop_shortcuts()
    {
        var s = new DesktopSettings();
        var cat = new DesktopCategorizer(s);
        var p = new InstalledProgram { Name = "Wispr Flow", MainExe = @"C:\Users\x\AppData\Local\WisprFlow\Wispr Flow.exe" };
        cat.RememberProgramCategory(p, "Medien");
        var item = new DesktopItem { Path = @"C:\d\Wispr Flow.lnk", DisplayName = "Wispr Flow", Kind = DesktopItemKind.AppIcon };
        var info = new ShortcutResolver.Info(@"C:\Users\x\AppData\Local\WisprFlow\Wispr Flow.exe", "", "", "", "");
        Assert.Equal("Medien", cat.Categorize(item, info));
        Assert.Equal("Medien", cat.CategorizeProgram(p));
    }
}
