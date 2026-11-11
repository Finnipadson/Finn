using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.Views;

namespace PCAufraeumer.ViewModels;

/// <summary>Seite „Programme“ – Tab „Updates“: neuere Versionen über winget finden und ausgewählte installieren.</summary>
public sealed partial class UpdatesViewModel : ObservableObject
{
    private readonly DeleteLogService _log;
    private readonly Action _logChanged;
    private readonly ProgramsViewModel _list;
    private CancellationTokenSource? _cts;
    private bool _loaded;

    public ObservableCollection<WingetUpdate> Updates { get; } = new();

    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private bool _isUpdating;
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private int _checkedCount;
    [ObservableProperty] private WingetUpdate? _selected;

    public UpdatesViewModel(DeleteLogService log, Action logChanged, ProgramsViewModel list)
    {
        _log = log;
        _logChanged = logChanged;
        _list = list;
    }

    private bool IsBusy => IsLoading || IsUpdating;

    partial void OnIsLoadingChanged(bool value) => NotifyCommands();
    partial void OnIsUpdatingChanged(bool value) => NotifyCommands();
    partial void OnCheckedCountChanged(int value) => UpdateCheckedCommand.NotifyCanExecuteChanged();

    private void NotifyCommands()
    {
        ReloadCommand.NotifyCanExecuteChanged();
        UpdateCheckedCommand.NotifyCanExecuteChanged();
        CancelCommand.NotifyCanExecuteChanged();
    }

    public async Task EnsureLoadedAsync()
    {
        if (_loaded) return;
        _loaded = true;
        await ReloadAsync();
    }

    private bool CanReload() => !IsBusy;

    [RelayCommand(CanExecute = nameof(CanReload))]
    private async Task ReloadAsync()
    {
        IsLoading = true;
        Status = "Suche nach Updates (winget) … das kann bis zu einer Minute dauern.";
        try
        {
            var list = await WingetService.ListUpdatesAsync();
            foreach (var u in Updates) u.PropertyChanged -= ItemChanged;
            Updates.Clear();
            foreach (var u in list) { u.PropertyChanged += ItemChanged; Updates.Add(u); }
            CheckedCount = 0;
            Status = list.Count == 0
                ? "Alles aktuell – winget kennt für keines deiner Programme eine neuere Version."
                : $"{list.Count} Update(s) verfügbar. Nichts ist ausgewählt – hake an, was aktualisiert werden soll.";
        }
        catch (FileNotFoundException ex) { Status = ex.Message; }
        catch (Exception ex)
        {
            ErrorLog.Write("Update-Liste (winget) konnte nicht gelesen werden.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsLoading = false; }
    }

    private void ItemChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(WingetUpdate.IsChecked)) CheckedCount = Updates.Count(u => u.IsChecked);
    }

    [RelayCommand]
    private void SelectAll()
    {
        foreach (var u in Updates.Where(u => u.CanCheck && u.State != UpdateState.Fertig)) u.IsChecked = true;
    }

    [RelayCommand]
    private void SelectNone()
    {
        foreach (var u in Updates) u.IsChecked = false;
    }

    private bool CanUpdate() => !IsBusy && CheckedCount > 0;

    [RelayCommand(CanExecute = nameof(CanUpdate))]
    private async Task UpdateCheckedAsync()
    {
        var todo = Updates.Where(u => u.IsChecked && u.CanCheck).ToList();
        if (todo.Count == 0) return;
        var ok = ConfirmDialog.Show(Application.Current.MainWindow, $"{todo.Count} Programm(e) aktualisieren?",
            "Die Updates werden nacheinander über winget heruntergeladen und installiert.",
            "Bitte die betroffenen Programme vorher schließen – laufende Programme werden vom Installer evtl. beendet. " +
            "Manche Installer brauchen Adminrechte; dann fragt Windows nach (🛡). Deine Einstellungen und Daten in den Programmen bleiben erhalten.",
            todo.Select(u => $"{u.Name}: {u.Version} → {u.Available}").ToList(), "Aktualisieren", requireCheckbox: null);
        if (!ok) return;

        IsUpdating = true;
        _cts = new CancellationTokenSource();
        int done = 0, failed = 0;
        try
        {
            foreach (var u in todo)
            {
                if (_cts.IsCancellationRequested) break;
                u.State = UpdateState.Laeuft;
                u.Result = "Wird aktualisiert …";
                Status = $"Aktualisiere {u.Name} ({done + failed + 1}/{todo.Count}) …";
                bool success;
                string msg;
                // Kein Abbruch mitten im Installer – abgebrochen wird erst vor dem nächsten Paket.
                try { (success, msg) = await WingetService.UpgradeAsync(u); }
                catch (OperationCanceledException) { success = false; msg = "Abgebrochen."; }
                catch (Exception ex) { success = false; msg = ex.Message; }
                u.State = success ? UpdateState.Fertig : UpdateState.Fehler;
                u.Result = msg;
                u.IsChecked = false;
                if (success) done++; else failed++;
                _log.Append(new[]
                {
                    new DeleteLogEntry
                    {
                        Timestamp = DateTime.Now, Path = u.Name, Method = "Update (winget)", Category = "Programme",
                        Success = success, Error = $"{u.Version} → {u.Available}: {msg}",
                    },
                });
            }
            Status = $"Fertig: {done} aktualisiert" + (failed > 0 ? $", {failed} fehlgeschlagen (Grund in der Spalte „Ergebnis“)" : "") +
                     (_cts.IsCancellationRequested ? " – Rest abgebrochen." : ".");
            _logChanged();
            if (done > 0) _ = _list.ReloadAsync();
        }
        finally
        {
            IsUpdating = false;
            _cts.Dispose();
            _cts = null;
        }
    }

    private bool CanCancel() => IsUpdating;

    /// <summary>Bricht nach dem gerade laufenden Update ab (ein laufender Installer wird nicht mittendrin gestoppt).</summary>
    [RelayCommand(CanExecute = nameof(CanCancel))]
    private void Cancel()
    {
        _cts?.Cancel();
        Status = "Wird abgebrochen …";
    }
}
