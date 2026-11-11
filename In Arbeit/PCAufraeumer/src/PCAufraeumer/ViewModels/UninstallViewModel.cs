using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.Views;

namespace PCAufraeumer.ViewModels;

public enum UninstallStage { Vorbereitung, Deinstallation, Moduswahl, Suche, Ergebnis, Fertig }

/// <summary>Ein Programm in der Deinstallations-Warteschlange.</summary>
public sealed partial class QueueItem : ObservableObject
{
    public InstalledProgram? Program { get; init; }
    public ProgramFootprint Footprint { get; init; } = new();
    public string Name => Footprint.Name;
    [ObservableProperty] private string _state = "wartet";
    [ObservableProperty] private string _detail = "";
    [ObservableProperty] private bool _isRunning;
    [ObservableProperty] private bool _waitsForUser;
    /// <summary>Restesuche für dieses Programm durchführen?</summary>
    [ObservableProperty] private bool _scanLeftovers = true;
    public TaskCompletionSource<bool>? UserDone { get; set; }
}

/// <summary>
/// Deinstallations-Assistent (Teil B/C): Wiederherstellungspunkt → Warteschlange → Suchmodus → Restesuche → Auswahl → Löschen.
/// Wird als Überlagerung auf der Seite „Programme“ angezeigt.
/// </summary>
public sealed partial class UninstallViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly DeleteLogService _log;
    private readonly Action _logChanged;
    private TaskCompletionSource<bool>? _closed;
    private TaskCompletionSource<LeftoverMode?>? _modeChosen;
    private CancellationTokenSource? _cts;

    public ObservableCollection<QueueItem> Queue { get; } = new();
    public ObservableCollection<LeftoverNode> RegistryTree { get; } = new();
    public ObservableCollection<LeftoverNode> FileTree { get; } = new();
    public List<Leftover> Found { get; } = new();

    [ObservableProperty] private bool _isOpen;
    [ObservableProperty] private UninstallStage _stage;
    [ObservableProperty] private string _title = "";
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private string _restoreInfo = "";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _selectionSummary = "";
    [ObservableProperty] private LeftoverMode _mode;
    [ObservableProperty] private string _resultInfo = "";

    public UninstallViewModel(SettingsService settings, DeleteLogService log, Action logChanged)
    {
        _settings = settings;
        _log = log;
        _logChanged = logChanged;
    }

    private Window? Owner => Application.Current?.MainWindow;

    // ───────────── Start ─────────────

    /// <summary>Normale Deinstallation eines oder mehrerer Programme. Endet, wenn der Assistent geschlossen wird.</summary>
    public async Task StartAsync(IReadOnlyList<InstalledProgram> programs)
    {
        var list = programs.Where(p => !p.IsLocked).ToList();
        if (list.Count == 0) return;
        var lines = list.Select(p => $"{p.Name}   ({p.TypeLabel}{(p.Kind == ProgramKind.Spiel ? " – über den Launcher" : "")})").ToList();
        if (!ConfirmDialog.Show(Owner, list.Count == 1 ? $"„{list[0].Name}“ deinstallieren?" : $"{list.Count} Programme deinstallieren?",
                (_settings.Current.Programs.CreateRestorePoint ? "🛡 Vorher wird ein Wiederherstellungspunkt erstellt. " : "") +
                "Die Programme werden nacheinander deinstalliert.",
                "Es startet jeweils der eigene Deinstaller des Programms – bitte dort die Fragen beantworten. " +
                "Spiele werden über ihren Launcher deinstalliert. Danach kannst du nach Resten suchen lassen; gelöscht wird nur, was du auswählst.",
                lines, "Deinstallieren", requireCheckbox: null)) return;

        var items = list.Select(p => new QueueItem { Program = p, Footprint = LeftoverScanner.Footprint(p, InstallRecorder.FindFor(p)) }).ToList();
        await RunWizardAsync(items, list.Count == 1 ? $"Deinstallieren: {list[0].Name}" : $"{list.Count} Programme deinstallieren", runUninstallers: true);
    }

    /// <summary>Erzwungene Deinstallation (Teil C): optional Deinstaller, dann direkt Restesuche.</summary>
    public async Task StartForcedAsync(ProgramFootprint footprint, InstalledProgram? withUninstaller)
    {
        var item = new QueueItem { Program = withUninstaller, Footprint = footprint };
        await RunWizardAsync(new List<QueueItem> { item }, $"Erzwungene Deinstallation: {footprint.Name}", runUninstallers: withUninstaller != null);
    }

    private async Task RunWizardAsync(List<QueueItem> items, string title, bool runUninstallers)
    {
        Queue.Clear();
        foreach (var i in items) Queue.Add(i);
        RegistryTree.Clear(); FileTree.Clear(); Found.Clear();
        Title = title;
        RestoreInfo = "";
        ResultInfo = "";
        SelectionSummary = "";
        Mode = _settings.Current.Programs.DefaultMode;
        Stage = UninstallStage.Vorbereitung;
        IsOpen = true;
        _closed = new TaskCompletionSource<bool>();
        _cts = new CancellationTokenSource();
        try
        {
            if (_settings.Current.Programs.CreateRestorePoint && !await CreateRestorePointAsync(title))
            {
                Status = "Abgebrochen – es wurde nichts deinstalliert.";
                Stage = UninstallStage.Fertig;
                await _closed.Task;
                return;
            }

            Stage = UninstallStage.Deinstallation;
            foreach (var q in Queue)
            {
                if (_cts.IsCancellationRequested) break;
                if (!runUninstallers || q.Program == null) { q.State = "übersprungen"; q.Detail = "Direkt zur Restesuche"; continue; }
                await UninstallOneAsync(q, _cts.Token);
            }

            Stage = UninstallStage.Moduswahl;
            Status = "Wie gründlich soll nach Resten gesucht werden?";
            _modeChosen = new TaskCompletionSource<LeftoverMode?>();
            var mode = await _modeChosen.Task;
            if (mode == null) { Stage = UninstallStage.Fertig; Status = "Fertig – ohne Restesuche."; await _closed.Task; return; }
            Mode = mode.Value;

            await ScanAsync(mode.Value, _cts.Token);
            Stage = UninstallStage.Ergebnis;
            await _closed.Task;
        }
        catch (OperationCanceledException)
        {
            Status = "Abgebrochen.";
            Stage = UninstallStage.Fertig;
            await _closed.Task;
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Deinstallations-Assistent: Fehler.", ex);
            Status = "Fehler: " + ex.Message;
            Stage = UninstallStage.Fertig;
            await _closed.Task;
        }
        finally
        {
            IsOpen = false;
            _logChanged();
        }
    }

    // ───────────── Wiederherstellungspunkt ─────────────

    /// <returns>false = Benutzer hat abgebrochen.</returns>
    private async Task<bool> CreateRestorePointAsync(string title)
    {
        IsBusy = true;
        Status = "🛡 Wiederherstellungspunkt wird erstellt – Windows fragt nach Adminrechten …";
        try
        {
            var r = (await AdminHelper.RunElevatedAsync(new[] { new AdminOp { Kind = "restorepoint", Target = "PC Aufräumer: " + title } }))[0];
            while (true)
            {
                if (r.Success && r.Message == "CREATED")
                {
                    RestoreInfo = $"✔ Wiederherstellungspunkt erstellt ({DateTime.Now:dd.MM.yyyy HH:mm}).";
                    Log("Wiederherstellungspunkt erstellt", true, title);
                    return true;
                }
                if (r.Message.StartsWith("DISABLED"))
                {
                    var a = MessageBox.Show(Owner,
                        "Der Computerschutz (Systemwiederherstellung) ist auf Laufwerk C: ausgeschaltet – deshalb kann kein Wiederherstellungspunkt erstellt werden.\n\n" +
                        "Ja = Computerschutz jetzt einschalten und Punkt erstellen (🛡)\nNein = ohne Wiederherstellungspunkt weitermachen\nAbbrechen = nichts deinstallieren",
                        "Computerschutz ist aus", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning);
                    if (a == MessageBoxResult.Cancel) return false;
                    if (a == MessageBoxResult.No) { RestoreInfo = "⚠ Ohne Wiederherstellungspunkt (Computerschutz ist aus)."; return true; }
                    var rr = await AdminHelper.RunElevatedAsync(new[]
                    {
                        new AdminOp { Kind = "enableprotection", Target = @"C:\" },
                        new AdminOp { Kind = "restorepoint", Target = "PC Aufräumer: " + title },
                    });
                    if (!rr[0].Success) { MessageBox.Show(Owner, rr[0].Message, "Computerschutz", MessageBoxButton.OK, MessageBoxImage.Warning); }
                    r = rr[^1];
                    continue;
                }
                if (r.Message.StartsWith("SKIPPED24H"))
                {
                    var when = r.Message.Split('|').ElementAtOrDefault(1) ?? "in den letzten 24 Stunden";
                    var a = MessageBox.Show(Owner,
                        $"Windows hat KEINEN neuen Wiederherstellungspunkt erstellt.\n\nGrund: Windows erlaubt standardmäßig nur einen Punkt pro 24 Stunden – der letzte wurde am {when} erstellt.\n" +
                        "Auf diesen Punkt kannst du im Notfall trotzdem zurückgehen.\n\nTrotzdem mit der Deinstallation weitermachen?",
                        "Kein neuer Wiederherstellungspunkt", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                    if (a != MessageBoxResult.Yes) return false;
                    RestoreInfo = $"⚠ Kein neuer Wiederherstellungspunkt (24-Stunden-Sperre) – letzter Punkt: {when}.";
                    Log("Kein neuer Wiederherstellungspunkt (24-Stunden-Sperre)", false, title);
                    return true;
                }
                // Abgelehnt oder anderer Fehler
                var b = MessageBox.Show(Owner,
                    $"Der Wiederherstellungspunkt konnte nicht erstellt werden:\n{r.Message}\n\nTrotzdem weitermachen?",
                    "Wiederherstellungspunkt", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (b != MessageBoxResult.Yes) return false;
                RestoreInfo = "⚠ Ohne Wiederherstellungspunkt: " + r.Message;
                return true;
            }
        }
        finally { IsBusy = false; }
    }

    // ───────────── Deinstallieren ─────────────

    private async Task UninstallOneAsync(QueueItem q, CancellationToken ct)
    {
        var p = q.Program!;
        q.IsRunning = true;
        q.State = "läuft";
        Status = $"Deinstalliere „{p.Name}“ …";
        var progress = new Progress<string>(s => q.Detail = s);
        var res = await UninstallRunner.RunAsync(p, progress, ct);

        if (res.Outcome == UninstallOutcome.ImLauncher)
        {
            q.State = "im Launcher";
            q.Detail = res.Message + " Danach hier auf „Fertig“ klicken.";
            q.WaitsForUser = true;
            q.UserDone = new TaskCompletionSource<bool>();
            // Automatisch weiter, sobald der Spielordner verschwunden ist
            var watch = Task.Run(async () =>
            {
                while (!q.UserDone.Task.IsCompleted && !ct.IsCancellationRequested)
                {
                    await Task.Delay(2000, ct);
                    if (p.InstallLocation.Length > 3 && !Directory.Exists(p.InstallLocation)) { q.UserDone.TrySetResult(true); break; }
                }
            }, ct);
            var done = await q.UserDone.Task;
            q.WaitsForUser = false;
            q.State = done ? "im Launcher deinstalliert" : "übersprungen";
            q.ScanLeftovers = done;
            Log(done ? "Über Launcher deinstalliert" : "Deinstallation übersprungen", done, p.Name);
        }
        else
        {
            q.State = res.Outcome switch
            {
                UninstallOutcome.Erfolgreich => "deinstalliert",
                UninstallOutcome.Abgebrochen => "abgebrochen",
                UninstallOutcome.KeinDeinstaller => "kein Deinstaller",
                _ => "fehlgeschlagen",
            };
            q.Detail = res.Message;
            // Bei Abbruch keine Restesuche vorschlagen (Programm ist ja noch da)
            q.ScanLeftovers = res.Outcome != UninstallOutcome.Abgebrochen && !(res.Outcome == UninstallOutcome.Fehlgeschlagen && UninstallRunner.StillInstalled(p));
            Log("Deinstallation: " + q.State + (res.Message.Length > 0 ? " – " + res.Message : ""), res.Outcome == UninstallOutcome.Erfolgreich, p.Name);
        }
        q.IsRunning = false;
    }

    [RelayCommand]
    private void QueueItemDone(QueueItem? q) => q?.UserDone?.TrySetResult(true);

    [RelayCommand]
    private void QueueItemSkip(QueueItem? q) => q?.UserDone?.TrySetResult(false);

    // ───────────── Restesuche ─────────────

    [RelayCommand]
    private void ChooseMode(string? mode)
    {
        _modeChosen?.TrySetResult(mode switch
        {
            "Sicher" => LeftoverMode.Sicher,
            "Moderat" => LeftoverMode.Moderat,
            "Erweitert" => LeftoverMode.Erweitert,
            _ => null,
        });
    }

    private async Task ScanAsync(LeftoverMode mode, CancellationToken ct)
    {
        Stage = UninstallStage.Suche;
        IsBusy = true;
        Status = "Suche nach Resten …";
        try
        {
            var remaining = await Task.Run(() => new ProgramInventory().ReadAll(ct), ct);
            var scanner = new LeftoverScanner(_settings.Current.Programs, remaining);
            var progress = new Progress<string>(s => Status = s);
            foreach (var q in Queue.Where(q => q.ScanLeftovers))
            {
                ct.ThrowIfCancellationRequested();
                // Das Programm selbst zählt nicht mehr als „installiert“ – außer es wurde nicht deinstalliert
                var found = await StaTask.Run(() => scanner.Scan(q.Footprint, mode, progress, ct));
                Found.AddRange(found);
            }
            BuildTrees();
            int safe = Found.Count(f => f.IsSafe);
            ResultInfo = Found.Count == 0
                ? "Keine Reste gefunden – sauber!"
                : $"{Found.Count} Funde ({safe} sicher). Nichts ist ausgewählt – wähle aus, was weg soll. Fett = sicher, grau = unsicher (Grund steht dabei).";
            Status = "";
        }
        finally { IsBusy = false; UpdateSelection(); }
    }

    private void BuildTrees()
    {
        RegistryTree.Clear();
        FileTree.Clear();
        foreach (var g in Found.GroupBy(f => f.Program))
        {
            var reg = new LeftoverNode { Title = g.Key };
            var files = new LeftoverNode { Title = g.Key };
            foreach (var l in g)
            {
                l.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(Leftover.IsChecked)) UpdateSelection(); };
                (l.IsFileSystem ? files : reg).Children.Add(new LeftoverNode { Title = l.Display, Item = l });
            }
            if (reg.Children.Count > 0) RegistryTree.Add(reg);
            if (files.Children.Count > 0) FileTree.Add(files);
        }
    }

    private void UpdateSelection()
    {
        var sel = Found.Where(f => f.IsChecked).ToList();
        SelectionSummary = sel.Count == 0 ? "Nichts ausgewählt"
            : $"{sel.Count} ausgewählt · {sel.Count(s => s.IsFileSystem)} Dateien/Ordner ({Format.Bytes(sel.Sum(s => s.Size))}), {sel.Count(s => !s.IsFileSystem)} Registry/System";
        DeleteSelectedCommand.NotifyCanExecuteChanged();
    }

    [RelayCommand]
    private void SelectAllSafe() { foreach (var f in Found.Where(f => f.IsSafe && f.Status.Length == 0)) f.IsChecked = true; }

    [RelayCommand]
    private void SelectNone() { foreach (var f in Found) f.IsChecked = false; }

    private bool CanDelete() => Found.Any(f => f.IsChecked) && !IsBusy;

    [RelayCommand(CanExecute = nameof(CanDelete))]
    private async Task DeleteSelectedAsync()
    {
        var sel = Found.Where(f => f.IsChecked).ToList();
        var lines = sel.Select(s => $"[{s.KindLabel}] {s.Display}").ToList();
        bool needsAdmin = sel.Any(s => !(s.IsFileSystem && ProtectionService.IsUnder(s.Path, Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)))
                                       && !s.Path.StartsWith("HKEY_CURRENT_USER", StringComparison.OrdinalIgnoreCase));
        if (!ConfirmDialog.Show(Owner, $"{sel.Count} Reste entfernen?",
                $"{sel.Count(s => s.IsFileSystem)} Dateien/Ordner ({Format.Bytes(sel.Sum(s => s.Size))}) · {sel.Count(s => !s.IsFileSystem)} Registry-Einträge/Systemobjekte",
                "Dateien und Ordner kommen in den Papierkorb. Registry-Einträge werden gelöscht – vorher wird jeder als .reg-Datei gesichert " +
                "(zusätzlich zum Wiederherstellungspunkt). " + (needsAdmin ? "🛡 Für Einträge außerhalb deines Benutzerbereichs fragt Windows nach Adminrechten." : ""),
                lines, "Entfernen", requireCheckbox: null)) return;

        IsBusy = true;
        try
        {
            var (ok, failed, backup) = await new LeftoverDeleter(_log).DeleteAsync(sel, new Progress<string>(s => Status = s));
            foreach (var s in sel) s.IsChecked = false;
            ResultInfo = $"{ok} Reste entfernt" + (failed > 0 ? $", {failed} nicht möglich (siehe Liste/Protokoll)" : "") +
                         $". Registry-Sicherungen: {backup}";
            Status = "";
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Reste konnten nicht entfernt werden.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsBusy = false; UpdateSelection(); _logChanged(); }
    }

    [RelayCommand]
    private void OpenBackupFolder() => Shell.Open(LeftoverDeleter.BackupDir);

    [RelayCommand]
    private void Close()
    {
        if (Stage is UninstallStage.Deinstallation or UninstallStage.Suche)
        {
            if (MessageBox.Show(Owner, "Den Vorgang abbrechen? Ein laufender Deinstaller wird nicht beendet.", "Abbrechen",
                    MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
            _cts?.Cancel();
            foreach (var q in Queue) q.UserDone?.TrySetResult(false);
        }
        _modeChosen?.TrySetResult(null);
        _closed?.TrySetResult(true);
    }

    // ───────────── Hilfen ─────────────

    /// <summary>Verwaiste Uninstall-Einträge entfernen (mit .reg-Sicherung, ggf. Adminrechte).</summary>
    public async Task<bool> RemoveRegistryEntriesAsync(IEnumerable<string> keys, string program)
    {
        var items = keys.Select(k => new Leftover { Kind = LeftoverKind.RegistrySchluessel, Path = k, Display = k, Program = program }).ToList();
        var (ok, failed, _) = await new LeftoverDeleter(_log).DeleteAsync(items, null);
        _logChanged();
        if (failed > 0) MessageBox.Show(Owner, string.Join("\n", items.Select(i => i.Status)), "Eintrag entfernen", MessageBoxButton.OK, MessageBoxImage.Warning);
        return failed == 0 && ok > 0;
    }

    private void Log(string what, bool ok, string program) => _log.Append(new[]
    {
        new DeleteLogEntry { Timestamp = DateTime.Now, Path = program, Category = $"Programm: {program}", Method = "Programme: " + what, Success = ok },
    });
}
