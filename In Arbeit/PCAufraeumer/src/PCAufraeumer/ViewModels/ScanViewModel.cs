using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Scan starten/abbrechen, Fortschritt anzeigen.</summary>
public sealed partial class ScanViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly ScanService _scan;
    private readonly LastAccessService _lastAccess;
    private readonly ResultsViewModel _results;
    private readonly Action _showResults;
    private CancellationTokenSource? _cts;

    public SettingsViewModel Config { get; }

    [ObservableProperty] private bool _isScanning;
    [ObservableProperty] private string _phase = "Bereit";
    [ObservableProperty] private string _currentPath = "";
    [ObservableProperty] private double _percent;
    [ObservableProperty] private bool _indeterminate;
    [ObservableProperty] private string _counters = "";
    [ObservableProperty] private string _lastSummary = "";

    public string LastAccessSummary => _lastAccess.Summary;
    public string LastAccessRegistry => _lastAccess.RegistryText;
    public string LastAccessFsutil => _lastAccess.FsutilText;
    public bool LastAccessEnabled => _lastAccess.Known && _lastAccess.UpdatesEnabled;

    public ScanViewModel(SettingsService settings, SettingsViewModel config, ScanService scan,
        LastAccessService lastAccess, ResultsViewModel results, Action showResults)
    {
        _settings = settings;
        Config = config;
        _scan = scan;
        _lastAccess = lastAccess;
        _results = results;
        _showResults = showResults;
    }

    public void RefreshLastAccess()
    {
        OnPropertyChanged(nameof(LastAccessSummary));
        OnPropertyChanged(nameof(LastAccessRegistry));
        OnPropertyChanged(nameof(LastAccessFsutil));
        OnPropertyChanged(nameof(LastAccessEnabled));
    }

    [RelayCommand]
    private async Task StartAsync()
    {
        if (IsScanning) return;
        var s = _settings.Current;
        bool fileCats = s.CategoryVideos || s.CategoryDuplicates || s.CategoryDownloads || s.CategoryRecordings;
        if (!fileCats && !s.CategoryTemp)
        {
            Phase = "Bitte mindestens eine Kategorie einschalten.";
            return;
        }
        if (s.CategoryVideos || s.CategoryDuplicates)
        {
            if (!s.ScanFolders.Any(Directory.Exists) && !s.CategoryDownloads && !s.CategoryTemp && !s.CategoryRecordings)
            {
                Phase = "Bitte zuerst mindestens einen Ordner zum Durchsuchen hinzufügen.";
                return;
            }
        }

        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        IsScanning = true;
        Indeterminate = true;
        Percent = 0;
        LastSummary = "";
        var progress = new Progress<ScanProgress>(p =>
        {
            Phase = p.Phase;
            CurrentPath = p.CurrentPath;
            Indeterminate = p.Percent < 0;
            if (p.Percent >= 0) Percent = p.Percent;
            Counters = $"{p.FilesSeen:N0} Dateien geprüft · {p.Found:N0} Funde";
        });

        try
        {
            ScanResult? fileResult = null;
            if (fileCats)
                fileResult = await _scan.ScanAsync(s, progress, ct);

            List<TempTarget> temps = new();
            if (s.CategoryTemp && !ct.IsCancellationRequested)
            {
                Phase = "Temp-/Cache-Bereiche werden gemessen";
                Indeterminate = true;
                temps = await Task.Run(() =>
                {
                    var list = TempService.BuildTargets();
                    foreach (var t in list)
                    {
                        if (ct.IsCancellationRequested) break;
                        ((IProgress<ScanProgress>)progress).Report(new ScanProgress { Phase = "Temp-/Cache-Bereiche werden gemessen", CurrentPath = t.Name });
                        try { TempService.Measure(t, ct); } catch (OperationCanceledException) { break; }
                    }
                    return list;
                });
            }

            bool cancelled = ct.IsCancellationRequested || fileResult?.Cancelled == true;
            var candidates = fileResult?.Candidates ?? new List<FileCandidate>();
            _results.Load(new SavedScanResult
            {
                ScanDate = DateTime.Now,
                ScannedFolders = s.ScanFolders.ToList(),
                Candidates = candidates,
                TempTargets = temps,
                LastAccessInfo = _lastAccess.Summary,
            }, partial: cancelled);

            var st = fileResult?.Stats;
            Phase = cancelled ? "Abgebrochen – bisherige Funde werden angezeigt" : "Fertig";
            Indeterminate = false;
            Percent = 100;
            CurrentPath = "";
            LastSummary = st == null ? $"{temps.Count(t => t.FileCount > 0)} Temp-/Cache-Bereiche gemessen." :
                $"{st.FilesSeen:N0} Dateien in {st.FoldersSeen:N0} Ordnern geprüft ({Format.Duration(st.Duration)}{(st.Duration.TotalMinutes < 1 ? $", {st.Duration.TotalSeconds:0} s" : "")}). " +
                $"{candidates.Count:N0} Funde. Übersprungen: {st.SkippedProtected:N0} geschützte Orte, {st.SkippedSystem:N0} Systemdateien, " +
                $"{st.SkippedCloudOnly:N0} „Nur online“-Dateien, {st.SkippedLocked:N0} geöffnete Dateien, {st.SkippedExceptions:N0} Ausnahmen; {st.Errors:N0} ohne Zugriff.";
            _showResults();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Scan fehlgeschlagen.", ex);
            Phase = "Fehler beim Scan: " + ex.Message;
        }
        finally
        {
            IsScanning = false;
            _cts.Dispose();
            _cts = null;
        }
    }

    [RelayCommand]
    private void Cancel()
    {
        _cts?.Cancel();
        Phase = "Wird abgebrochen …";
    }
}
