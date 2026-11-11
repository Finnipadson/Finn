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

public sealed record AgeOption(int Days, string Name);

/// <summary>Seite „Downloads“: lose Dateien in Unterordner sortieren – Vorschau → Übernehmen → Rückgängig. Löscht nie etwas.</summary>
public sealed partial class DownloadsViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly DesktopApplier _applier;
    private readonly Action _logChanged;
    private readonly DispatcherTimer _replanTimer = new() { Interval = TimeSpan.FromMilliseconds(150) };
    private DownloadsPlanner? _planner;
    private DesktopPlan? _plan;
    private bool _loaded;

    /// <summary>Test-Modus: anderer Ordner statt des echten Downloads-Ordners (Umgebungsvariable PCA_DOWNLOADS_TEST).</summary>
    public string? TestFolder { get; } = Environment.GetEnvironmentVariable("PCA_DOWNLOADS_TEST");
    public bool IsTestMode => !string.IsNullOrEmpty(TestFolder);
    public string Folder => IsTestMode ? TestFolder! : KnownFolders.Downloads;

    public ObservableCollection<DesktopChange> Changes { get; } = new();
    public ObservableCollection<DesktopSnapshot> History { get; } = new();

    public static IReadOnlyList<AgeOption> AgeOptions { get; } = new[]
    {
        new AgeOption(0, "Alle Dateien"),
        new AgeOption(1, "Dateien von heute liegen lassen"),
        new AgeOption(7, "Nur älter als 7 Tage"),
        new AgeOption(30, "Nur älter als 30 Tage"),
    };

    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _status = "Noch nicht analysiert.";
    [ObservableProperty] private string _summary = "";
    [ObservableProperty] private string _infoText = "";
    [ObservableProperty] private bool _hasPlan;

    public DownloadsViewModel(SettingsService settings, DesktopApplier applier, Action logChanged)
    {
        _settings = settings;
        _applier = applier;
        _logChanged = logChanged;
        _replanTimer.Tick += (_, _) => { _replanTimer.Stop(); Replan(); };
    }

    public AgeOption SelectedAge
    {
        get => AgeOptions.FirstOrDefault(a => a.Days == _settings.Current.Downloads.MinAgeDays) ?? AgeOptions[1];
        set
        {
            if (value == null || value.Days == _settings.Current.Downloads.MinAgeDays) return;
            _settings.Current.Downloads.MinAgeDays = value.Days;
            _settings.Save();
            OnPropertyChanged();
            _ = AnalyzeAsync();
        }
    }

    partial void OnIsBusyChanged(bool value)
    {
        ApplyCommand.NotifyCanExecuteChanged();
        AnalyzeCommand.NotifyCanExecuteChanged();
    }

    public async Task EnsureLoadedAsync()
    {
        LoadHistory();
        if (_loaded) return;
        _loaded = true;
        await AnalyzeAsync();
    }

    private bool CanAnalyze() => !IsBusy;

    [RelayCommand(CanExecute = nameof(CanAnalyze))]
    private async Task AnalyzeAsync()
    {
        if (IsBusy) return;
        if (!Directory.Exists(Folder))
        {
            Status = $"Downloads-Ordner nicht gefunden: {Folder}";
            return;
        }
        IsBusy = true;
        Status = "Downloads-Ordner wird gelesen …";
        try
        {
            var planner = new DownloadsPlanner(_settings.Current.Desktop, Folder);
            _planner = planner;
            int minAge = _settings.Current.Downloads.MinAgeDays;
            var changes = await StaTask.Run(() =>
            {
                var files = planner.ReadFiles();
                foreach (var f in files) f.Icon = ShellIcons.Get(f.Path, 32);
                return planner.BuildChanges(files, minAge, DateTime.Now);
            });
            foreach (var c in Changes) c.PropertyChanged -= ChangeChanged;
            Changes.Clear();
            foreach (var c in changes) { c.PropertyChanged += ChangeChanged; Changes.Add(c); }
            int folders = planner.ExistingFolderNames().Count;
            InfoText = (IsTestMode ? "TESTMODUS – " : "") +
                       $"{Folder}  ·  {changes.Count} lose Dateien ({Format.Bytes(changes.Sum(c => c.Item.Size))}), {folders} Unterordner";
            Replan();
            Status = changes.Count == 0 ? "Der Downloads-Ordner ist schon aufgeräumt – keine losen Dateien." : "Vorschau bereit – noch wurde nichts verändert.";
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Downloads-Ordner konnte nicht gelesen werden.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsBusy = false; }
    }

    private void ChangeChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(DesktopChange.Target) or nameof(DesktopChange.IsEnabled))
        {
            _replanTimer.Stop();
            _replanTimer.Start();
        }
    }

    private void Replan()
    {
        if (_planner == null) return;
        _plan = _planner.Plan(Changes);
        int mv = _plan.Moves.Count;
        int stay = Changes.Count - mv;
        Summary = mv == 0
            ? "Nichts ausgewählt." + (stay > 0 ? $" {stay} Datei(en) bleiben liegen." : "")
            : $"Geplant: {mv} Dateien ({Format.Bytes(_plan.Moves.Sum(c => c.Item.Size))}) in Ordner verschieben, {_plan.NewFolders.Count} neue Ordner" +
              (stay > 0 ? $", {stay} bleiben liegen" : "") + ". Gelöscht wird nichts.";
        HasPlan = mv > 0;
        ApplyCommand.NotifyCanExecuteChanged();
    }

    private bool CanApply() => HasPlan && !IsBusy;

    [RelayCommand(CanExecute = nameof(CanApply))]
    private async Task ApplyAsync()
    {
        if (_plan == null || _plan.Moves.Count == 0) return;
        var lines = _plan.Moves.Select(c => $"{c.Item.FileName} {c.Description}").ToList();
        var ok = ConfirmDialog.Show(Application.Current.MainWindow, "Downloads jetzt aufräumen?", Summary,
            "Die Dateien werden nur in Unterordner des Downloads-Ordners verschoben. Es wird nichts gelöscht. " +
            "Mit „Rückgängig“ im Verlauf kommt alles wieder an seinen alten Platz.",
            lines, "Übernehmen", requireCheckbox: null);
        if (!ok) return;

        IsBusy = true;
        try
        {
            var progress = new Progress<string>(s => Status = s);
            var (res, _) = await _applier.ApplyAsync(null, _plan, Folder, progress, DesktopHistory.DownloadsArea);
            Status = $"Fertig: {res.Moved} Dateien verschoben, {res.FoldersCreated} Ordner neu." +
                     (res.Problems.Count > 0 ? $" {res.Problems.Count} Hinweis(e): " + string.Join("; ", res.Problems.Take(3)) : "");
            _logChanged();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Downloads aufräumen fehlgeschlagen.", ex);
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
            "• neu erstellte Ordner werden nur entfernt, wenn sie leer sind",
            "Rückgängig machen", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (r != MessageBoxResult.Yes) return;

        IsBusy = true;
        try
        {
            var res = await _applier.UndoAsync(null, snap, new Progress<string>(s => Status = s));
            Status = $"Rückgängig gemacht: {res.Moved} Dateien zurück, {res.FoldersRemoved} leere Ordner entfernt." +
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
    private void SelectAll()
    {
        foreach (var c in Changes.Where(c => c.CanEnable)) c.IsEnabled = true;
    }

    [RelayCommand]
    private void SelectNone()
    {
        foreach (var c in Changes) c.IsEnabled = false;
    }

    [RelayCommand]
    private void OpenFolder() => Shell.Open(Folder);

    private void LoadHistory()
    {
        History.Clear();
        foreach (var h in DesktopHistory.Load(DesktopHistory.DownloadsArea)) History.Add(h);
    }
}
