using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Data;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.Views;

namespace PCAufraeumer.ViewModels;

// ═════════════════════════ Teil C: Erzwungene Deinstallation ═════════════════════════

public sealed partial class ForcedUninstallViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly UninstallViewModel _uninstall;
    private readonly ProgramsViewModel _list;

    public ObservableCollection<InstalledProgram> Matches { get; } = new();

    [ObservableProperty] private string _query = "";
    [ObservableProperty] private string _folder = "";
    [ObservableProperty] private string _exeFile = "";
    [ObservableProperty] private InstalledProgram? _selectedMatch;
    [ObservableProperty] private string _info = "Gib einen Programmnamen ein, wähle einen Ordner oder eine .exe-Datei – auch für Programme, die schon gelöscht sind.";

    public ForcedUninstallViewModel(SettingsService settings, UninstallViewModel uninstall, ProgramsViewModel list)
    {
        _settings = settings;
        _uninstall = uninstall;
        _list = list;
    }

    partial void OnQueryChanged(string value)
    {
        Matches.Clear();
        if (value.Trim().Length < 2) return;
        foreach (var p in _list.Programs.Where(p => p.Name.Contains(value.Trim(), StringComparison.OrdinalIgnoreCase)).Take(30)) Matches.Add(p);
    }

    partial void OnSelectedMatchChanged(InstalledProgram? value)
    {
        if (value == null) return;
        if (value.InstallLocation.Length > 0) Folder = value.InstallLocation;
        Info = value.UninstallString.Length > 0 || value.ProductCode.Length > 0 || value.PackageFullName.Length > 0
            ? $"Für „{value.Name}“ ist ein Deinstaller eingetragen – er wird zuerst angeboten."
            : $"Für „{value.Name}“ ist kein Deinstaller vorhanden – es geht direkt zur Restesuche.";
    }

    [RelayCommand]
    private void PickFolder()
    {
        var d = new OpenFolderDialog { Title = "Ordner des Programms wählen" };
        if (d.ShowDialog() == true)
        {
            Folder = d.FolderName;
            if (Query.Trim().Length == 0) Query = Path.GetFileName(d.FolderName);
        }
    }

    [RelayCommand]
    private void PickExe()
    {
        var d = new OpenFileDialog { Title = "Programmdatei (.exe) wählen", Filter = "Programme (*.exe)|*.exe" };
        if (d.ShowDialog() != true) return;
        ExeFile = d.FileName;
        Folder = Path.GetDirectoryName(d.FileName) ?? "";
        try
        {
            var vi = FileVersionInfo.GetVersionInfo(d.FileName);
            if (Query.Trim().Length == 0) Query = vi.ProductName is { Length: > 0 } pn ? pn : Path.GetFileNameWithoutExtension(d.FileName);
        }
        catch { if (Query.Trim().Length == 0) Query = Path.GetFileNameWithoutExtension(d.FileName); }
    }

    [RelayCommand]
    private async Task StartAsync()
    {
        var name = (SelectedMatch?.Name ?? Query).Trim();
        if (name.Length == 0 && Folder.Length == 0)
        {
            MessageBox.Show(Application.Current.MainWindow, "Bitte einen Programmnamen, Ordner oder eine .exe angeben.", "Erzwungene Deinstallation");
            return;
        }
        if (name.Length == 0) name = Path.GetFileName(Folder.TrimEnd('\\'));

        InstalledProgram fake = SelectedMatch ?? new InstalledProgram
        {
            Id = "forced:" + name, Name = name, InstallLocation = Folder, MainExe = ExeFile,
        };
        if (SelectedMatch == null)
        {
            try { if (ExeFile.Length > 0) fake.Publisher = FileVersionInfo.GetVersionInfo(ExeFile).CompanyName ?? ""; } catch { }
        }
        else if (Folder.Length > 0 && SelectedMatch.InstallLocation.Length == 0) fake.InstallLocation = Folder;

        var footprint = LeftoverScanner.Footprint(fake, InstallRecorder.FindFor(fake));
        InstalledProgram? withUninstaller = null;
        if (SelectedMatch is { } m && !m.IsLocked && (m.UninstallString.Length > 0 || m.ProductCode.Length > 0 || m.PackageFullName.Length > 0 || m.LauncherUri.Length > 0))
        {
            var a = MessageBox.Show(Application.Current.MainWindow,
                $"Für „{m.Name}“ ist noch ein Deinstaller vorhanden.\n\nJa = zuerst den Deinstaller ausführen, danach Restesuche\nNein = direkt zur Restesuche",
                "Erzwungene Deinstallation", MessageBoxButton.YesNoCancel, MessageBoxImage.Question);
            if (a == MessageBoxResult.Cancel) return;
            if (a == MessageBoxResult.Yes) withUninstaller = m;
        }
        else if (!ConfirmDialog.Show(Application.Current.MainWindow, $"Reste von „{name}“ suchen?",
                     (_settings.Current.Programs.CreateRestorePoint ? "🛡 Vorher wird ein Wiederherstellungspunkt erstellt. " : "") + "Danach wählst du den Suchmodus.",
                     "Gesucht wird nach Ordnern, Dateien, Registry-Einträgen, Diensten, Aufgaben und Autostart-Einträgen, die zu diesem Programm gehören. " +
                     "Gelöscht wird nur, was du danach selbst auswählst.",
                     new[] { $"Name: {name}", $"Ordner: {(Folder.Length > 0 ? Folder : "–")}", $"Programmdatei: {(ExeFile.Length > 0 ? ExeFile : "–")}" },
                     "Weiter", requireCheckbox: null)) return;

        await _uninstall.StartForcedAsync(footprint, withUninstaller);
        await _list.ReloadAsync();
    }
}

// ═════════════════════════ Teil D: Installationen überwachen ═════════════════════════

public sealed partial class RecorderViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly ProgramsViewModel _list;
    private CancellationTokenSource? _cts;
    private TaskCompletionSource<bool>? _userDone;
    private readonly DispatcherTimer _watch = new() { Interval = TimeSpan.FromMinutes(1) };

    public ObservableCollection<InstallRecording> Recordings { get; } = new();

    [ObservableProperty] private InstallRecording? _selected;
    [ObservableProperty] private string _renameText = "";
    [ObservableProperty] private bool _isRecording;
    [ObservableProperty] private bool _waitingForSetup;
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private bool _watchNewInstalls;

    public string WatchHonesty =>
        "Ehrlich gesagt: Im Nachhinein ist nur noch erkennbar, dass ein neues Programm in der Programmliste aufgetaucht ist. " +
        "Was das Setup genau angelegt hat, lässt sich dann nur SCHÄTZEN (neue Ordner und Registry-Schlüssel rund um den Installationszeitpunkt, " +
        "deren Name passt). Solche Zuordnungen sind als „geschätzt“ markiert. Für eine exakte Liste: „Installation aufzeichnen“ verwenden.";

    public RecorderViewModel(SettingsService settings, ProgramsViewModel list)
    {
        _settings = settings;
        _list = list;
        _watchNewInstalls = settings.Current.Programs.WatchNewInstalls;
        _watch.Tick += async (_, _) => await CheckNewInstallsAsync();
        if (_watchNewInstalls) StartWatch();
    }

    public void Reload()
    {
        Recordings.Clear();
        foreach (var r in InstallRecorder.LoadAll()) Recordings.Add(r);
    }

    partial void OnSelectedChanged(InstallRecording? value) => RenameText = value?.Name ?? "";

    [RelayCommand]
    private async Task RecordAsync()
    {
        var d = new OpenFileDialog { Title = "Setup-Datei wählen", Filter = "Setup (*.exe;*.msi)|*.exe;*.msi" };
        if (d.ShowDialog() != true) return;
        var setup = d.FileName;
        if (!ConfirmDialog.Show(Application.Current.MainWindow, "Installation aufzeichnen?", Path.GetFileName(setup),
                "1. Die App merkt sich, wie die wichtigen Ordner und Registry-Bereiche jetzt aussehen (dauert etwas).\n" +
                "2. Dann startet das Setup – installiere ganz normal.\n" +
                "3. Wenn das Setup fertig ist (oder du auf „Fertig“ klickst), vergleicht die App und speichert alles Neue als Installationsprotokoll.\n\n" +
                "Tipp: Während der Aufzeichnung möglichst keine anderen Programme installieren oder benutzen.",
                new[] { setup }, "Aufzeichnung starten", requireCheckbox: null)) return;

        IsRecording = true;
        _cts = new CancellationTokenSource();
        var progress = new Progress<string>(s => Status = s);
        try
        {
            Status = "Schnappschuss vorher …";
            var before = await Task.Run(() => InstallRecorder.Take(progress, _cts.Token));

            Status = "Setup läuft – installiere ganz normal. Wenn es fertig ist, geht es automatisch weiter (oder klicke „Fertig“).";
            WaitingForSetup = true;
            _userDone = new TaskCompletionSource<bool>();
            var started = DateTime.Now;
            Process? p = setup.EndsWith(".msi", StringComparison.OrdinalIgnoreCase)
                ? Process.Start(new ProcessStartInfo("msiexec.exe", $"/i \"{setup}\"") { UseShellExecute = true })
                : Process.Start(new ProcessStartInfo(setup) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(setup) ?? "" });
            if (p != null)
            {
                var pid = p.Id;
                var waitSetup = Task.Run(async () =>
                {
                    await p.WaitForExitAsync(_cts.Token);
                    await UninstallRunner.WaitForDescendantsAsync(pid, started, _cts.Token);
                });
                await Task.WhenAny(waitSetup, _userDone.Task);
            }
            else await _userDone.Task;
            WaitingForSetup = false;

            Status = "Schnappschuss nachher und Vergleich …";
            await Task.Delay(1500);
            var after = await Task.Run(() => InstallRecorder.Take(progress, _cts.Token));
            var rec = InstallRecorder.Diff(before, after, Path.GetFileName(setup), setup);
            InstallRecorder.Save(rec);
            Reload();
            Selected = Recordings.FirstOrDefault(r => r.Id == rec.Id);
            Status = $"Aufgezeichnet: {rec.Name} – {rec.NewDirectories.Count} neue Ordner, {rec.NewFiles.Count} Dateien, {rec.NewKeys.Count} Registry-Schlüssel, {rec.ChangedFiles.Count} geänderte Dateien.";
            await _list.ReloadAsync();
        }
        catch (System.ComponentModel.Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            Status = "Setup wurde nicht gestartet (Adminrechte abgelehnt).";
        }
        catch (OperationCanceledException) { Status = "Aufzeichnung abgebrochen."; }
        catch (Exception ex)
        {
            ErrorLog.Write("Installation aufzeichnen fehlgeschlagen.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsRecording = false; WaitingForSetup = false; }
    }

    [RelayCommand] private void SetupDone() => _userDone?.TrySetResult(true);
    [RelayCommand] private void CancelRecording() { _cts?.Cancel(); _userDone?.TrySetResult(false); }

    [RelayCommand]
    private void Rename()
    {
        if (Selected == null || RenameText.Trim().Length == 0) return;
        Selected.Name = RenameText.Trim();
        InstallRecorder.Save(Selected);
        var id = Selected.Id;
        Reload();
        Selected = Recordings.FirstOrDefault(r => r.Id == id);
    }

    [RelayCommand]
    private void Delete()
    {
        if (Selected == null) return;
        if (MessageBox.Show(Application.Current.MainWindow, $"Aufzeichnung „{Selected.Name}“ löschen?\n(Das Programm selbst bleibt installiert.)",
                "Aufzeichnung löschen", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        InstallRecorder.Delete(Selected);
        Reload();
        _ = _list.ReloadAsync();
    }

    [RelayCommand]
    private void Show()
    {
        if (Selected is not { } r) return;
        var lines = r.NewDirectories.Select(x => "Ordner neu:  " + x)
            .Concat(r.NewFiles.Select(x => "Datei neu:   " + x))
            .Concat(r.NewKeys.Select(x => "Schlüssel neu: " + x))
            .Concat(r.NewValues.Select(x => "Wert neu:    " + x.Replace("|", " → ")))
            .Concat(r.ChangedFiles.Take(500).Select(x => "geändert:    " + x)).ToList();
        ConfirmDialog.Show(Application.Current.MainWindow, r.Name, r.Summary,
            r.IsEstimate ? "Diese Zuordnung ist GESCHÄTZT (nachträglich erkannt)." : $"Aufgezeichnet beim Ausführen von {r.SetupFile}. Geänderte Dateien dienen nur zur Info – beim Deinstallieren werden nur neu angelegte Dinge vorgeschlagen.",
            lines, "Schließen", requireCheckbox: null);
    }

    // ───────────── Hintergrund-Überwachung ─────────────

    partial void OnWatchNewInstallsChanged(bool value)
    {
        _settings.Current.Programs.WatchNewInstalls = value;
        _settings.Save();
        if (value) StartWatch(); else _watch.Stop();
    }

    private static string KnownFile => Path.Combine(AppPaths.BaseDir, "bekannte-programme.json");

    private void StartWatch()
    {
        if (!File.Exists(KnownFile))
            Json.WriteAtomic(KnownFile, new ProgramInventory().ReadRegistry().Select(p => p.Id).ToList());
        _watch.Start();
    }

    private bool _checking;

    private async Task CheckNewInstallsAsync()
    {
        if (_checking || IsRecording) return;
        _checking = true;
        try
        {
            var known = File.Exists(KnownFile)
                ? new HashSet<string>(System.Text.Json.JsonSerializer.Deserialize<List<string>>(File.ReadAllText(KnownFile)) ?? new())
                : new HashSet<string>();
            var now = await Task.Run(() => new ProgramInventory().ReadRegistry().ToList());
            var fresh = now.Where(p => !known.Contains(p.Id) && !p.HiddenByDefault).ToList();
            Json.WriteAtomic(KnownFile, now.Select(p => p.Id).ToList());
            foreach (var p in fresh)
            {
                var a = MessageBox.Show(Application.Current.MainWindow,
                    $"Gerade wurde „{p.Name}“ installiert.\n\nSoll die App diese Installation nachträglich zuordnen? " +
                    "Das ist eine SCHÄTZUNG (neue Ordner und Registry-Schlüssel mit passendem Namen rund um jetzt) – " +
                    "nicht so genau wie eine echte Aufzeichnung.",
                    "Neue Installation erkannt", MessageBoxButton.YesNo, MessageBoxImage.Question);
                if (a != MessageBoxResult.Yes) continue;
                // Erkannt wird spätestens eine Minute nach der Installation → Zeitfenster „letzte 20 Minuten“
                var rec = await Task.Run(() => InstallRecorder.EstimateFor(p, DateTime.Now.AddMinutes(-20)));
                InstallRecorder.Save(rec);
            }
            if (fresh.Count > 0) { Reload(); await _list.ReloadAsync(); }
        }
        catch (Exception ex) { ErrorLog.Write("Überwachung neuer Installationen fehlgeschlagen.", ex); }
        finally { _checking = false; }
    }
}

// ═════════════════════════ Teil E: Autostart ═════════════════════════

public sealed partial class AutostartViewModel : ObservableObject
{
    private readonly DeleteLogService _log;
    private readonly Action _logChanged;
    private bool _loaded;

    public ObservableCollection<AutostartEntry> Entries { get; } = new();
    public ICollectionView View { get; }

    [ObservableProperty] private bool _showAdvanced;
    [ObservableProperty] private bool _showWindows;
    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private AutostartEntry? _selected;

    public AutostartViewModel(DeleteLogService log, Action logChanged)
    {
        _log = log;
        _logChanged = logChanged;
        View = CollectionViewSource.GetDefaultView(Entries);
        View.Filter = o => o is AutostartEntry e && (ShowAdvanced || !e.IsAdvanced) && (ShowWindows || !e.IsLocked || e.Source != AutostartSource.Task);
        View.GroupDescriptions.Add(new PropertyGroupDescription(nameof(AutostartEntry.Location)));
    }

    partial void OnShowWindowsChanged(bool value) => View.Refresh();
    partial void OnShowAdvancedChanged(bool value) => _ = ReloadAsync();

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
            bool adv = ShowAdvanced;
            var list = await StaTask.Run(() => AutostartService.ReadAll(adv));
            Entries.Clear();
            foreach (var e in list)
            {
                if (e.Exe.Length > 0 && File.Exists(e.Exe)) e.Icon = ShellIcons.Get(e.Exe, 32);
                Entries.Add(e);
            }
            int active = list.Count(e => e.Enabled), orphan = list.Count(e => !e.FileExists);
            Status = $"{list.Count} Einträge · {active} aktiv · {list.Count - active} deaktiviert" + (orphan > 0 ? $" · {orphan} zeigen auf fehlende Dateien" : "");
        }
        catch (Exception ex) { ErrorLog.Write("Autostart konnte nicht gelesen werden.", ex); Status = "Fehler: " + ex.Message; }
        finally { IsLoading = false; }
    }

    [RelayCommand]
    private async Task ToggleAsync(AutostartEntry? e)
    {
        e ??= Selected;
        if (e == null) return;
        bool target = !e.Enabled;
        var err = await AutostartService.SetEnabledAsync(e, target);
        if (err == null)
        {
            e.Enabled = target;
            _log.Append(new[] { new DeleteLogEntry { Timestamp = DateTime.Now, Path = e.Name, Category = e.Location, Method = target ? "Autostart aktiviert" : "Autostart deaktiviert", Success = true, Error = e.Command } });
            _logChanged();
        }
        else MessageBox.Show(Application.Current.MainWindow, err, "Autostart", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    [RelayCommand]
    private async Task RemoveOrphanAsync(AutostartEntry? e)
    {
        e ??= Selected;
        if (e == null) return;
        if (MessageBox.Show(Application.Current.MainWindow,
                $"Den Autostart-Eintrag „{e.Name}“ entfernen?\n\nEr zeigt auf eine Datei, die es nicht mehr gibt:\n{e.Exe}\n\n" +
                "Registry-Einträge werden vorher gesichert, Verknüpfungen kommen in den Papierkorb.",
                "Verwaisten Eintrag entfernen", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        var err = await AutostartService.RemoveOrphanAsync(e);
        _log.Append(new[] { new DeleteLogEntry { Timestamp = DateTime.Now, Path = e.Name, Category = e.Location, Method = "Autostart: verwaisten Eintrag entfernt", Success = err == null, Error = err ?? e.Command } });
        _logChanged();
        if (err != null) MessageBox.Show(Application.Current.MainWindow, err, "Autostart", MessageBoxButton.OK, MessageBoxImage.Warning);
        else Entries.Remove(e);
    }

    [RelayCommand]
    private void OpenLocation(AutostartEntry? e)
    {
        e ??= Selected;
        if (e == null) return;
        if (e.FilePath.Length > 0) Shell.ShowInExplorer(e.FilePath);
        else if (e.Exe.Length > 0 && File.Exists(e.Exe)) Shell.ShowInExplorer(e.Exe);
    }
}
