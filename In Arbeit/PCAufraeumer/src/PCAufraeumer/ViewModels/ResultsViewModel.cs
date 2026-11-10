using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Data;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.Views;

namespace PCAufraeumer.ViewModels;

public sealed record CategoryFilter(string Label, FindingCategory? Category);

/// <summary>Ergebnisliste: Gruppen, Filter, Suche, Auswahl, Vorschau, Löschen.</summary>
public sealed partial class ResultsViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly SettingsViewModel _config;
    private readonly CleanupService _cleanup;
    private readonly ThumbnailService _thumbs;
    private readonly Action _logChanged;
    private SavedScanResult? _current;
    private bool _bulk;

    public ObservableCollection<FileCandidate> Items { get; } = new();
    public ObservableCollection<TempTarget> TempTargets { get; } = new();
    public ICollectionView View { get; }

    private static readonly CategoryFilter[] CategoryFilterList =
    {
        new CategoryFilter("Alle Kategorien", null),
        new CategoryFilter("Alte Videos/Clips", FindingCategory.Videos),
        new CategoryFilter("Doppelte Dateien", FindingCategory.Duplicates),
        new CategoryFilter("Alte Downloads/Installer", FindingCategory.Downloads),
    };

    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private CategoryFilter _categoryFilter = CategoryFilterList[0];
    [ObservableProperty] private string _typeFilter = "Alle Typen";
    [ObservableProperty] private bool _onlySelected;
    [ObservableProperty] private bool _hideDeleted = true;
    [ObservableProperty] private FileCandidate? _selectedItem;
    [ObservableProperty] private string _selectionSummary = "Nichts ausgewählt";
    [ObservableProperty] private long _selectionBytes;
    [ObservableProperty] private int _selectionCount;
    [ObservableProperty] private string _tempSummary = "";
    [ObservableProperty] private string _header = "Noch kein Scan durchgeführt.";
    [ObservableProperty] private bool _isWorking;
    [ObservableProperty] private string _workStatus = "";
    [ObservableProperty] private double _workPercent;
    [ObservableProperty] private bool _hasResult;
    [ObservableProperty] private string _totalSummary = "";
    [ObservableProperty] private string _tempHeader = "– eigener Bereich, wird direkt gelöscht (nicht Papierkorb)";

    private void UpdateTempHeader()
    {
        long size = TempTargets.Sum(t => t.Size);
        TempHeader = TempTargets.Count == 0
            ? "– nicht gescannt"
            : $"– {Format.Bytes(size)} · eigener Bereich, wird direkt gelöscht (kein Papierkorb)";
    }

    public IReadOnlyList<CategoryFilter> CategoryFilters => CategoryFilterList;
    public ObservableCollection<string> TypeFilters { get; } = new() { "Alle Typen" };

    public ResultsViewModel(SettingsService settings, SettingsViewModel config, CleanupService cleanup,
        ThumbnailService thumbs, Action logChanged)
    {
        _settings = settings;
        _config = config;
        _cleanup = cleanup;
        _thumbs = thumbs;
        _logChanged = logChanged;
        View = CollectionViewSource.GetDefaultView(Items);
        View.GroupDescriptions.Add(new PropertyGroupDescription(nameof(FileCandidate.GroupLabel)));
        View.SortDescriptions.Add(new SortDescription(nameof(FileCandidate.Category), ListSortDirection.Ascending));
        View.SortDescriptions.Add(new SortDescription(nameof(FileCandidate.GroupId), ListSortDirection.Ascending));
        View.SortDescriptions.Add(new SortDescription(nameof(FileCandidate.Size), ListSortDirection.Descending));
        View.Filter = Filter;
    }

    // ───────────── Laden / Speichern ─────────────

    public void Load(SavedScanResult r, bool partial = false)
    {
        _current = r;
        foreach (var c in Items) c.PropertyChanged -= ItemChanged;
        foreach (var t in TempTargets) t.PropertyChanged -= ItemChanged;
        Items.Clear();
        TempTargets.Clear();

        // Ausnahmen, die nach dem Speichern dazugekommen sind, nicht mehr anzeigen.
        foreach (var c in r.Candidates.Where(c => !_settings.IsException(c.FullPath)))
        {
            c.PropertyChanged += ItemChanged;
            Items.Add(c);
        }
        foreach (var t in r.TempTargets)
        {
            t.BrowserRunning = TempService.IsProcessRunning(t.BrowserProcess);
            t.Status = TempService.BuildStatus(t);
            t.PropertyChanged += ItemChanged;
            TempTargets.Add(t);
        }

        TypeFilters.Clear();
        TypeFilters.Add("Alle Typen");
        foreach (var t in Items.Select(i => i.TypeLabel).Distinct().OrderBy(x => x)) TypeFilters.Add(t);
        TypeFilter = "Alle Typen";

        HasResult = true;
        long total = Items.Where(i => !i.IsKeep && !i.IsDeleted).Sum(i => i.Size);
        Header = $"Scan vom {r.ScanDate:dd.MM.yyyy HH:mm}" + (partial ? " (abgebrochen, unvollständig)" : "") +
                 $" · {Items.Count:N0} Funde";
        TotalSummary = $"Möglich: {Format.Bytes(total)} in Funden (ohne behaltene Kopien) · " +
                       $"{Format.Bytes(TempTargets.Sum(t => t.Size))} in Temp/Cache";
        UpdateTempHeader();
        View.Refresh();
        UpdateSummary();
        AutoSave();
    }

    private void AutoSave()
    {
        if (_current == null) return;
        try
        {
            _current.Candidates = Items.ToList();
            _current.TempTargets = TempTargets.ToList();
            ResultStore.Save(_current, AppPaths.LastResultFile);
        }
        catch (Exception ex) { ErrorLog.Write("Ergebnisliste konnte nicht automatisch gespeichert werden.", ex); }
    }

    public bool TryLoadLast()
    {
        var r = ResultStore.Load(AppPaths.LastResultFile);
        if (r == null) return false;
        Load(r);
        return true;
    }

    [RelayCommand]
    private void SaveAs()
    {
        if (_current == null) return;
        var dlg = new SaveFileDialog
        {
            Title = "Ergebnisliste speichern", Filter = "Ergebnisliste (*.json)|*.json",
            InitialDirectory = AppPaths.ResultsDir, FileName = $"Scan {DateTime.Now:yyyy-MM-dd HH-mm}.json",
        };
        if (dlg.ShowDialog() != true) return;
        _current.Candidates = Items.ToList();
        _current.TempTargets = TempTargets.ToList();
        try { ResultStore.Save(_current, dlg.FileName); WorkStatus = "Gespeichert: " + dlg.FileName; }
        catch (Exception ex) { ShowError("Speichern fehlgeschlagen", ex); }
    }

    [RelayCommand]
    private void Open()
    {
        var dlg = new OpenFileDialog
        {
            Title = "Ergebnisliste öffnen", Filter = "Ergebnisliste (*.json)|*.json", InitialDirectory = AppPaths.ResultsDir,
        };
        if (dlg.ShowDialog() != true) return;
        var r = ResultStore.Load(dlg.FileName);
        if (r == null) { MessageBox.Show("Die Datei konnte nicht gelesen werden.", "PC Aufräumer"); return; }
        // Inzwischen gelöschte oder veränderte Dateien markieren.
        foreach (var c in r.Candidates)
            if (!File.Exists(c.FullPath)) c.IsDeleted = true;
        Load(r);
    }

    // ───────────── Filter / Auswahl ─────────────

    private bool Filter(object o)
    {
        if (o is not FileCandidate c) return false;
        if (HideDeleted && c.IsDeleted) return false;
        if (CategoryFilter.Category is { } cat && c.Category != cat) return false;
        if (TypeFilter != "Alle Typen" && c.TypeLabel != TypeFilter) return false;
        if (OnlySelected && !c.IsSelected) return false;
        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var q = SearchText.Trim();
            if (!c.FullPath.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                !c.Reason.Contains(q, StringComparison.OrdinalIgnoreCase) &&
                !c.TypeLabel.Contains(q, StringComparison.OrdinalIgnoreCase)) return false;
        }
        return true;
    }

    partial void OnSearchTextChanged(string value) => View.Refresh();
    partial void OnCategoryFilterChanged(CategoryFilter value) => View.Refresh();
    partial void OnTypeFilterChanged(string value) => View.Refresh();
    partial void OnOnlySelectedChanged(bool value) => View.Refresh();
    partial void OnHideDeletedChanged(bool value) => View.Refresh();

    private void ItemChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (_bulk) return;
        if (e.PropertyName is nameof(FileCandidate.IsSelected) or nameof(TempTarget.IsSelected) or nameof(FileCandidate.IsKeep))
            UpdateSummary();
    }

    private void UpdateSummary()
    {
        // Gleiche Datei kann in zwei Kategorien auftauchen (z. B. altes Video, das auch Duplikat ist) → nur einmal zählen.
        var files = Items.Where(i => i.IsSelected).GroupBy(i => i.FullPath, StringComparer.OrdinalIgnoreCase).Select(g => g.First()).ToList();
        var temps = TempTargets.Where(t => t.IsSelected).ToList();
        SelectionCount = files.Count;
        SelectionBytes = files.Sum(f => f.Size) + temps.Sum(t => t.Size);
        SelectionSummary = files.Count == 0 && temps.Count == 0
            ? "Nichts ausgewählt"
            : $"Du gibst {Format.Bytes(SelectionBytes)} frei";
        TempSummary = temps.Count == 0 ? "" : $"{temps.Count} Temp-/Cache-Bereich(e) ausgewählt ({Format.Bytes(temps.Sum(t => t.Size))})";
        DeleteSelectedCommand.NotifyCanExecuteChanged();
        CleanTempCommand.NotifyCanExecuteChanged();
    }

    /// <summary>„Alle in dieser Gruppe auswählen“ – behaltene Kopien bleiben immer abgewählt.</summary>
    [RelayCommand]
    private void ToggleGroup(object? groupItems)
    {
        if (groupItems is not System.Collections.IEnumerable items) return;
        var list = items.OfType<FileCandidate>().Where(c => c.CanSelect).ToList();
        if (list.Count == 0) return;
        bool select = list.Any(c => !c.IsSelected);
        _bulk = true;
        foreach (var c in list) c.IsSelected = select;
        _bulk = false;
        UpdateSummary();
    }

    [RelayCommand]
    private void SelectNone()
    {
        _bulk = true;
        foreach (var c in Items) c.IsSelected = false;
        foreach (var t in TempTargets) t.IsSelected = false;
        _bulk = false;
        UpdateSummary();
    }

    /// <summary>Bei Duplikaten: diese Kopie statt der vorgeschlagenen behalten.</summary>
    [RelayCommand]
    private void KeepThisCopy(FileCandidate? c)
    {
        if (c is not { Category: FindingCategory.Duplicates } || c.IsDeleted) return;
        var group = Items.Where(i => i.Category == FindingCategory.Duplicates && i.GroupId == c.GroupId).ToList();
        ScanService.SetKeep(group, c);
        UpdateSummary();
        AutoSave();
    }

    /// <summary>„Behalten / nie wieder vorschlagen“ → Ausnahmeliste.</summary>
    [RelayCommand]
    private void NeverSuggest(FileCandidate? c)
    {
        if (c == null) return;
        _config.AddException(c.FullPath);
        foreach (var same in Items.Where(i => string.Equals(i.FullPath, c.FullPath, StringComparison.OrdinalIgnoreCase)).ToList())
        {
            same.PropertyChanged -= ItemChanged;
            Items.Remove(same);
        }
        FixDuplicateGroupsAfterRemoval();
        UpdateSummary();
        AutoSave();
    }

    /// <summary>Bleibt in einer Gruppe nur noch eine Datei übrig, ist es kein Duplikat mehr.</summary>
    private void FixDuplicateGroupsAfterRemoval()
    {
        foreach (var g in Items.Where(i => i.Category == FindingCategory.Duplicates).GroupBy(i => i.GroupId).ToList())
        {
            var alive = g.Where(i => !i.IsDeleted).ToList();
            if (alive.Count <= 1 && !g.Any(i => i.IsDeleted))
            {
                foreach (var x in g) { x.PropertyChanged -= ItemChanged; Items.Remove(x); }
            }
            else if (!alive.Any(i => i.IsKeep) && alive.Count > 0)
            {
                ScanService.ApplyKeepSuggestion(alive);
            }
        }
    }

    [RelayCommand]
    private void ExcludeFolder(FileCandidate? c)
    {
        if (c == null) return;
        var r = MessageBox.Show($"Den Ordner\n{c.Directory}\nab sofort nie mehr durchsuchen?\n\n(Funde daraus werden aus der Liste entfernt.)",
            "Ordner ausschließen", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (r != MessageBoxResult.Yes) return;
        _config.AddExcluded(c.Directory);
        foreach (var x in Items.Where(i => ProtectionService.IsUnder(i.FullPath, c.Directory)).ToList())
        {
            x.PropertyChanged -= ItemChanged;
            Items.Remove(x);
        }
        FixDuplicateGroupsAfterRemoval();
        UpdateSummary();
        AutoSave();
    }

    [RelayCommand] private void ShowInExplorer(FileCandidate? c) { if (c != null) Shell.ShowInExplorer(c.FullPath); }
    [RelayCommand] private void OpenDefault(FileCandidate? c) { if (c != null) Shell.Open(c.FullPath); }

    public void RequestThumbnail(FileCandidate c) => _thumbs.Request(c);

    // ───────────── Löschen ─────────────

    private bool CanDelete() => !IsWorking && Items.Any(i => i.IsSelected);

    [RelayCommand(CanExecute = nameof(CanDelete))]
    private async Task DeleteSelectedAsync()
    {
        var files = Items.Where(i => i.IsSelected && i.CanSelect)
            .GroupBy(i => i.FullPath, StringComparer.OrdinalIgnoreCase).Select(g => g.First()).ToList();
        if (files.Count == 0) return;

        var problems = CleanupService.ValidateDuplicateGroups(files, Items);
        if (problems.Count > 0)
        {
            MessageBox.Show("Von jeder Duplikat-Gruppe muss mindestens eine Kopie erhalten bleiben:\n\n" + string.Join("\n", problems),
                "Nicht möglich", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        long bytes = files.Sum(f => f.Size);
        var ok = ConfirmDialog.Show(Application.Current.MainWindow,
            "In den Papierkorb verschieben?",
            $"{files.Count:N0} Datei(en) · {Format.Bytes(bytes)}",
            "Die Dateien werden in den Windows-Papierkorb verschoben und können von dort wiederhergestellt werden. " +
            "Jede Aktion wird im Protokoll gespeichert.",
            files.Select(f => $"{Format.Bytes(f.Size),10}   {f.FullPath}").ToList(),
            "In den Papierkorb verschieben",
            requireCheckbox: null);
        if (!ok) return;

        IsWorking = true;
        DeleteSelectedCommand.NotifyCanExecuteChanged();
        try
        {
            var progress = new Progress<(int done, int total, string path)>(p =>
            {
                WorkPercent = p.done * 100.0 / Math.Max(1, p.total);
                WorkStatus = $"Papierkorb {p.done}/{p.total}: {p.path}";
            });
            var entries = await _cleanup.RecycleAsync(files, Items, progress, CancellationToken.None);
            var okPaths = new HashSet<string>(entries.Where(e => e.Success).Select(e => e.Path), StringComparer.OrdinalIgnoreCase);
            foreach (var c in Items.Where(i => okPaths.Contains(i.FullPath))) c.IsDeleted = true;
            var failed = entries.Where(e => !e.Success).ToList();
            WorkStatus = $"{okPaths.Count:N0} Datei(en) in den Papierkorb verschoben ({Format.Bytes(entries.Where(e => e.Success).Sum(e => e.Size))})." +
                         (failed.Count > 0 ? $" {failed.Count} nicht möglich – siehe Protokoll." : "");
            if (failed.Count > 0)
                MessageBox.Show("Einige Dateien wurden NICHT gelöscht:\n\n" +
                                string.Join("\n", failed.Take(15).Select(f => $"• {Path.GetFileName(f.Path)}: {f.Error}")) +
                                (failed.Count > 15 ? $"\n… und {failed.Count - 15} weitere (siehe Protokoll)" : ""),
                    "Hinweis", MessageBoxButton.OK, MessageBoxImage.Information);
            View.Refresh();
            _logChanged();
        }
        catch (Exception ex) { ShowError("Löschen fehlgeschlagen", ex); }
        finally
        {
            IsWorking = false;
            UpdateSummary();
            AutoSave();
        }
    }

    private bool CanCleanTemp() => !IsWorking && TempTargets.Any(t => t.IsSelected);

    [RelayCommand(CanExecute = nameof(CanCleanTemp))]
    private async Task CleanTempAsync()
    {
        foreach (var t in TempTargets)
        {
            t.BrowserRunning = TempService.IsProcessRunning(t.BrowserProcess);
            t.Status = TempService.BuildStatus(t);
        }
        var targets = TempTargets.Where(t => t.IsSelected && t.CanSelect).ToList();
        if (targets.Count == 0)
        {
            MessageBox.Show("Die ausgewählten Bereiche können gerade nicht geleert werden (z. B. weil der Browser geöffnet ist).", "Hinweis");
            UpdateSummary();
            return;
        }

        var ok = ConfirmDialog.Show(Application.Current.MainWindow,
            "Temp-/Cache-Dateien ENDGÜLTIG löschen?",
            $"{targets.Count} Bereich(e) · ca. {Format.Bytes(targets.Sum(t => t.Size))} · {targets.Sum(t => t.FileCount):N0} Dateien",
            "Diese Dateien werden NICHT in den Papierkorb verschoben, sondern direkt gelöscht. Es handelt sich nur um " +
            "temporäre Dateien und Zwischenspeicher, die Windows und die Browser bei Bedarf neu anlegen. " +
            (targets.Any(t => t.RequiresAdmin && !TempService.IsAdmin) ? "Für Windows-Bereiche fragt Windows gleich nach Adminrechten. " : "") +
            "Gerade benutzte Dateien werden übersprungen.",
            targets.Select(t => $"{Format.Bytes(t.Size),10}   {t.Name}" + (t.RequiresAdmin ? "  [Admin]" : "")).ToList(),
            "Endgültig löschen",
            requireCheckbox: "Ich habe verstanden: Temp-/Cache-Dateien werden endgültig gelöscht (kein Papierkorb).");
        if (!ok) return;

        IsWorking = true;
        CleanTempCommand.NotifyCanExecuteChanged();
        try
        {
            WorkPercent = 0;
            var progress = new Progress<string>(s => WorkStatus = "Temp/Cache: " + s);
            var entries = await _cleanup.CleanTempAsync(targets, progress, CancellationToken.None);
            long freed = entries.Where(e => e.Success).Sum(e => e.Size);
            int okCount = entries.Count(e => e.Success);
            int skipped = entries.Count(e => !e.Success);
            WorkStatus = $"Temp/Cache: {okCount:N0} Dateien gelöscht ({Format.Bytes(freed)})" +
                         (skipped > 0 ? $", {skipped:N0} übersprungen (in Benutzung/kein Zugriff)." : ".");
            WorkPercent = 100;

            await Task.Run(() => { foreach (var t in targets) TempService.Measure(t, CancellationToken.None); });
            foreach (var t in targets) { t.IsSelected = false; t.Status = TempService.BuildStatus(t); }
            RefreshTempRows();
            _logChanged();
        }
        catch (Exception ex) { ShowError("Temp/Cache konnte nicht geleert werden", ex); }
        finally
        {
            IsWorking = false;
            UpdateSummary();
            AutoSave();
        }
    }

    private void RefreshTempRows()
    {
        var copy = TempTargets.ToList();
        TempTargets.Clear();
        foreach (var t in copy) TempTargets.Add(t);
        UpdateTempHeader();
    }

    [RelayCommand]
    private void RecheckBrowsers()
    {
        foreach (var t in TempTargets)
        {
            t.BrowserRunning = TempService.IsProcessRunning(t.BrowserProcess);
            t.Status = TempService.BuildStatus(t);
        }
        RefreshTempRows();
        UpdateSummary();
    }

    private static void ShowError(string title, Exception ex)
    {
        ErrorLog.Write(title, ex);
        MessageBox.Show(ex.Message, title, MessageBoxButton.OK, MessageBoxImage.Warning);
    }
}
