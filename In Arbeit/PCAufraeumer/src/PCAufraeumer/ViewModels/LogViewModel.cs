using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Data;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Löschprotokoll + Fehlerprotokoll, CSV-Export.</summary>
public sealed partial class LogViewModel : ObservableObject
{
    private readonly DeleteLogService _log;

    public ObservableCollection<DeleteLogEntry> Entries { get; } = new();
    public ObservableCollection<string> Errors { get; } = new();
    public ICollectionView View { get; }

    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private string _summary = "";

    public LogViewModel(DeleteLogService log)
    {
        _log = log;
        View = CollectionViewSource.GetDefaultView(Entries);
        View.Filter = o => o is DeleteLogEntry e &&
                           (string.IsNullOrWhiteSpace(SearchText) ||
                            e.Path.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                            e.Category.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
    }

    partial void OnSearchTextChanged(string value) => View.Refresh();

    [RelayCommand]
    public void Reload()
    {
        Entries.Clear();
        foreach (var e in _log.ReadAll()) Entries.Add(e);
        Errors.Clear();
        foreach (var e in ErrorLog.ReadRecent()) Errors.Add(e);
        // Löschungen und Desktop-Aktionen getrennt zählen
        bool IsDelete(DeleteLogEntry e) => e.Method == "Papierkorb" || e.Method.StartsWith("Direkt", StringComparison.Ordinal) ||
                                           e.Method.StartsWith("Rest entfernt", StringComparison.Ordinal);
        var deletes = Entries.Where(IsDelete).ToList();
        var ok = deletes.Where(e => e.Success).ToList();
        int desktop = Entries.Count(e => e.Method.StartsWith("Desktop", StringComparison.Ordinal));
        int programs = Entries.Count(e => e.Method.StartsWith("Programme", StringComparison.Ordinal) || e.Method.StartsWith("Autostart", StringComparison.Ordinal));
        Summary = $"{ok.Count:N0} erfolgreiche Löschungen, zusammen {Format.Bytes(ok.Sum(e => e.Size))} · " +
                  $"{deletes.Count - ok.Count:N0} nicht durchgeführt" +
                  (desktop > 0 ? $" · {desktop:N0} Desktop-Aufräumaktionen" : "") +
                  (programs > 0 ? $" · {programs:N0} Programm-/Autostart-Aktionen" : "");
    }

    [RelayCommand]
    private void ExportCsv()
    {
        var dlg = new SaveFileDialog
        {
            Title = "Protokoll als CSV exportieren", Filter = "CSV-Datei (*.csv)|*.csv",
            FileName = $"Loeschprotokoll {DateTime.Now:yyyy-MM-dd}.csv",
        };
        if (dlg.ShowDialog() != true) return;
        try
        {
            DeleteLogService.ExportCsv(View.Cast<DeleteLogEntry>(), dlg.FileName);
            MessageBox.Show($"Exportiert nach:\n{dlg.FileName}", "Protokoll", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            ErrorLog.Write("CSV-Export fehlgeschlagen.", ex);
            MessageBox.Show(ex.Message, "Export fehlgeschlagen", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    [RelayCommand] private void OpenRecycleBin() => Shell.Open("shell:RecycleBinFolder");
    [RelayCommand] private void ShowInExplorer(DeleteLogEntry? e) { if (e != null) Shell.ShowInExplorer(e.Path); }
}
