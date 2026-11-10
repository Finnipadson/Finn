using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Interop;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.Views;

namespace PCAufraeumer.ViewModels;

/// <summary>Seite „Desktop aufräumen“: Analyse → Vorschau (Vorher/Nachher + Änderungsliste) → Übernehmen → Rückgängig.</summary>
public sealed partial class DesktopViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly DesktopApplier _applier;
    private readonly Action _logChanged;
    private readonly DispatcherTimer _replanTimer = new() { Interval = TimeSpan.FromMilliseconds(150) };
    private List<DesktopItem> _items = new();
    private List<ViewMonitor> _monitors = new();
    private POINT _spacing = new(100, 100);
    private DesktopPlanner? _planner;
    private bool _loaded;

    /// <summary>Test-Modus: statt des echten Desktops ein Explorer-Fenster mit diesem Ordner (Umgebungsvariable PCA_DESKTOP_TEST).</summary>
    public string? TestFolder { get; } = Environment.GetEnvironmentVariable("PCA_DESKTOP_TEST");
    public bool IsTestMode => !string.IsNullOrEmpty(TestFolder);

    public ObservableCollection<DesktopChange> Changes { get; } = new();
    public ObservableCollection<DesktopSnapshot> History { get; } = new();

    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _status = "Noch nicht analysiert.";
    [ObservableProperty] private bool _autoArrangeOn;
    [ObservableProperty] private string _infoText = "";
    [ObservableProperty] private string _warnings = "";
    [ObservableProperty] private string _summary = "";
    [ObservableProperty] private bool _hasPlan;
    [ObservableProperty] private bool _allOnPrimary;

    // Daten für die Vorher/Nachher-Ansicht (werden von DesktopView gezeichnet)
    public IReadOnlyList<PreviewIcon> BeforeIcons { get; private set; } = Array.Empty<PreviewIcon>();
    public IReadOnlyList<PreviewIcon> AfterIcons { get; private set; } = Array.Empty<PreviewIcon>();
    public IReadOnlyList<PreviewGroup> AfterGroups { get; private set; } = Array.Empty<PreviewGroup>();
    public IReadOnlyList<ViewMonitor> Monitors => _monitors;
    public POINT Spacing => _spacing;
    public event EventHandler? PreviewChanged;

    public DesktopViewModel(SettingsService settings, DesktopApplier applier, Action logChanged)
    {
        _settings = settings;
        _applier = applier;
        _logChanged = logChanged;
        _allOnPrimary = settings.Current.Desktop.AllOnPrimary;
        _replanTimer.Tick += (_, _) => { _replanTimer.Stop(); Replan(); };
    }

    private DesktopSettings S => _settings.Current.Desktop;

    partial void OnIsBusyChanged(bool value) => ApplyCommand.NotifyCanExecuteChanged();

    public async Task EnsureLoadedAsync()
    {
        LoadHistory();
        if (_loaded) return;
        _loaded = true;
        await AnalyzeAsync();
    }

    private DesktopShellView OpenView()
    {
        if (IsTestMode)
        {
            var v = DesktopShellView.OpenExplorerWindow(TestFolder!)
                    ?? throw new InvalidOperationException($"Testmodus: Bitte zuerst ein Explorer-Fenster mit „{TestFolder}“ öffnen.");
            return v;
        }
        return DesktopShellView.OpenDesktop();
    }

    private string UserDesktop => IsTestMode ? TestFolder! : KnownFolders.Desktop;
    private string? PublicDesktop => IsTestMode ? null : KnownFolders.PublicDesktop;

    [RelayCommand]
    private async Task AnalyzeAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        Status = "Desktop wird gelesen …";
        try
        {
            List<ShellViewItem> shellItems;
            using (var view = OpenView())
            {
                shellItems = view.GetItems();
                _monitors = view.GetMonitors();
                _spacing = view.Spacing;
                AutoArrangeOn = view.AutoArrange;
            }
            _planner = new DesktopPlanner(S, UserDesktop, PublicDesktop);
            var planner = _planner;
            // Dateien klassifizieren + Verknüpfungen auflösen im Hintergrund (eigener STA-Thread für die Shell)
            Status = "Verknüpfungen werden ausgewertet …";
            _items = await StaTask.Run(() =>
            {
                var items = planner.Classify(shellItems);
                planner.Categorize(items);
                foreach (var i in items) i.Icon = ShellIcons.Get(i.Path, 48);
                return items;
            });

            foreach (var c in Changes) c.PropertyChanged -= ChangeChanged;
            Changes.Clear();
            foreach (var c in planner.BuildChanges(_items, _monitors))
            {
                c.PropertyChanged += ChangeChanged;
                Changes.Add(c);
            }
            BeforeIcons = _items.Select(i => new PreviewIcon { Path = i.Path, Name = i.DisplayName, X = i.X, Y = i.Y }).ToList();

            int apps = _items.Count(i => i.Kind == DesktopItemKind.AppIcon);
            int files = _items.Count(i => i.Kind == DesktopItemKind.File);
            int folders = _items.Count(i => i.Kind == DesktopItemKind.Folder);
            int sys = _items.Count(i => i.Kind == DesktopItemKind.System);
            InfoText = (IsTestMode ? $"TESTMODUS – Ordner {TestFolder}. " : $"Desktop: {UserDesktop}  ·  Öffentlicher Desktop: {PublicDesktop}. ") +
                       $"{apps} App-Symbole, {files} lose Dateien, {folders} Ordner, {sys} Systemsymbole · " +
                       $"{_monitors.Count} Monitor(e), Rasterabstand {_spacing.X}×{_spacing.Y} px";
            Replan();
            Status = "Vorschau bereit – noch wurde nichts verändert.";
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Desktop konnte nicht gelesen werden.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsBusy = false; }
    }

    private void ChangeChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (sender is not DesktopChange c) return;
        if (e.PropertyName == nameof(DesktopChange.Target) && c.Kind == DesktopChangeKind.Position &&
            c.Item.Kind == DesktopItemKind.AppIcon && !string.IsNullOrWhiteSpace(c.Target))
        {
            // Eigene Zuordnung merken – gilt auch beim nächsten Mal.
            S.IconOverrides[c.Item.FileName] = c.Target;
            _settings.Save();
        }
        if (e.PropertyName is nameof(DesktopChange.Target) or nameof(DesktopChange.IsEnabled))
        {
            _replanTimer.Stop();
            _replanTimer.Start();
        }
    }

    partial void OnAllOnPrimaryChanged(bool value)
    {
        if (S.AllOnPrimary == value) return;
        S.AllOnPrimary = value;
        _settings.Save();
        if (_planner == null) return;
        foreach (var c in Changes) c.PropertyChanged -= ChangeChanged;
        Changes.Clear();
        foreach (var c in _planner.BuildChanges(_items, _monitors)) { c.PropertyChanged += ChangeChanged; Changes.Add(c); }
        Replan();
    }

    private DesktopPlan? _plan;

    private void Replan()
    {
        if (_planner == null) return;
        _plan = _planner.Plan(_items, Changes.ToList(), _monitors, _spacing);
        AfterIcons = _plan.After;
        AfterGroups = _plan.Groups;
        Warnings = string.Join("\n", _plan.Warnings);
        int pos = Changes.Count(c => c.IsEnabled && c.Kind == DesktopChangeKind.Position);
        int mv = _plan.Moves.Count;
        Summary = $"Geplant: {pos} Symbole/Ordner anordnen, {mv} Dateien in Ordner verschieben, {_plan.NewFolders.Count} neue Ordner. Gelöscht wird nichts.";
        HasPlan = pos + mv > 0;
        ApplyCommand.NotifyCanExecuteChanged();
        PreviewChanged?.Invoke(this, EventArgs.Empty);
    }

    /// <summary>Drag &amp; Drop in der Nachher-Ansicht: Symbol einer anderen Kategorie zuordnen.</summary>
    public void MoveToGroup(DesktopChange change, string group)
    {
        if (change.Item.Kind != DesktopItemKind.AppIcon || !S.Categories.Contains(group)) return;
        change.IsEnabled = true;
        change.Target = group;
    }

    public IReadOnlyList<string> Categories => S.Categories;
    public int GapColumns => S.GapColumns;

    private bool CanApply() => HasPlan && !IsBusy;

    [RelayCommand(CanExecute = nameof(CanApply))]
    private async Task ApplyAsync()
    {
        if (_plan == null) return;
        var lines = Changes.Where(c => c.IsEnabled).Select(c => c.Description).ToList();
        var ok = ConfirmDialog.Show(Application.Current.MainWindow, "Desktop jetzt aufräumen?", Summary,
            "Symbole werden nur neu angeordnet, lose Dateien in Ordner auf dem Desktop verschoben. Es wird nichts gelöscht. " +
            "Der jetzige Zustand wird vorher gespeichert – du kannst alles mit „Rückgängig machen“ wiederherstellen.",
            lines, "Übernehmen", requireCheckbox: null);
        if (!ok) return;

        IsBusy = true;
        ApplyCommand.NotifyCanExecuteChanged();
        try
        {
            using var view = OpenView();
            if (view.AutoArrange)
                Status = "Hinweis: „Symbole automatisch anordnen“ ist an – Windows wird die Positionen wieder umsortieren.";
            var progress = new Progress<string>(s => Status = s);
            var (res, _) = await _applier.ApplyAsync(view, _plan, IsTestMode ? TestFolder! : "Desktop", progress);
            Status = $"Fertig: {res.Positioned} Symbole angeordnet, {res.Moved} Dateien verschoben, {res.FoldersCreated} Ordner neu." +
                     (res.Problems.Count > 0 ? $" {res.Problems.Count} Hinweis(e): " + string.Join("; ", res.Problems.Take(3)) : "");
            _logChanged();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Desktop aufräumen fehlgeschlagen.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
            LoadHistory();
        }
        var keep = Status;
        await AnalyzeAsync();
        Status = keep;
    }

    [RelayCommand]
    private async Task UndoAsync(DesktopSnapshot? snap)
    {
        if (snap == null || snap.Undone || IsBusy) return;
        var r = MessageBox.Show(Application.Current.MainWindow,
            $"Aufräumaktion vom {snap.Date:dd.MM.yyyy HH:mm} rückgängig machen?\n\n" +
            $"• {snap.Moves.Count} Datei(en) werden an ihren alten Platz zurückgelegt\n" +
            $"• {snap.Positions.Count} Symbolpositionen werden wiederhergestellt\n" +
            $"• neu erstellte Ordner werden nur entfernt, wenn sie leer sind",
            "Rückgängig machen", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (r != MessageBoxResult.Yes) return;

        IsBusy = true;
        try
        {
            using var view = snap.ViewKind == "Desktop"
                ? (IsTestMode ? null : DesktopShellView.OpenDesktop())
                : DesktopShellView.OpenExplorerWindow(snap.ViewKind);
            var res = await _applier.UndoAsync(view, snap, new Progress<string>(s => Status = s));
            Status = $"Rückgängig gemacht: {res.Moved} Dateien zurück, {res.Positioned} Positionen wiederhergestellt, {res.FoldersRemoved} leere Ordner entfernt." +
                     (res.Problems.Count > 0 ? " Hinweise: " + string.Join("; ", res.Problems.Take(3)) : "");
            _logChanged();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Rückgängig machen fehlgeschlagen.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
            LoadHistory();
        }
        var keep = Status;
        await AnalyzeAsync();
        Status = keep;
    }

    [RelayCommand]
    private void DisableAutoArrange()
    {
        try
        {
            using var view = OpenView();
            view.AutoArrange = false;
            AutoArrangeOn = view.AutoArrange;
            Status = AutoArrangeOn ? "„Automatisch anordnen“ konnte nicht ausgeschaltet werden." : "„Symbole automatisch anordnen“ ist jetzt aus.";
        }
        catch (Exception ex) { Status = "Fehler: " + ex.Message; }
    }

    [RelayCommand]
    private void SelectAll(string? kind)
    {
        foreach (var c in Changes.Where(c => c.CanEnable))
            if (kind == null || (kind == "files") == (c.Kind == DesktopChangeKind.MoveFile)) c.IsEnabled = true;
    }

    [RelayCommand]
    private void SelectNone(string? kind)
    {
        foreach (var c in Changes)
            if (kind == null || (kind == "files") == (c.Kind == DesktopChangeKind.MoveFile)) c.IsEnabled = false;
    }

    [RelayCommand]
    private void OpenDesktopFolder() => Shell.Open(UserDesktop);

    private void LoadHistory()
    {
        History.Clear();
        foreach (var h in DesktopHistory.Load()) History.Add(h);
    }
}
