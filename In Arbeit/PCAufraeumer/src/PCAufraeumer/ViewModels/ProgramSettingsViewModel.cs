using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Bereich „Programme“ in den Einstellungen. Jede Änderung wird sofort gespeichert.</summary>
public sealed partial class ProgramSettingsViewModel : ObservableObject
{
    private readonly SettingsService _svc;
    private ProgramSettings S => _svc.Current.Programs;

    public IReadOnlyList<string> Modes { get; } = new[] { "Sicher", "Moderat", "Erweitert" };
    public ObservableCollection<string> ProtectedPaths { get; } = new();

    [ObservableProperty] private string _defaultMode;
    [ObservableProperty] private bool _showSystemComponents;
    [ObservableProperty] private bool _createRestorePoint;
    [ObservableProperty] private string _recordingsFolder;
    [ObservableProperty] private string _newProtectedPath = "";
    [ObservableProperty] private string? _selectedProtectedPath;

    public ProgramSettingsViewModel(SettingsService svc)
    {
        _svc = svc;
        _defaultMode = S.DefaultMode.ToString();
        _showSystemComponents = S.ShowSystemComponents;
        _createRestorePoint = S.CreateRestorePoint;
        _recordingsFolder = InstallRecorder.Folder(S);
        foreach (var p in S.ProtectedPaths) ProtectedPaths.Add(p);
    }

    partial void OnDefaultModeChanged(string value)
    {
        if (Enum.TryParse<LeftoverMode>(value, out var m)) { S.DefaultMode = m; _svc.Save(); }
    }

    partial void OnShowSystemComponentsChanged(bool value) { S.ShowSystemComponents = value; _svc.Save(); }
    partial void OnCreateRestorePointChanged(bool value) { S.CreateRestorePoint = value; _svc.Save(); }

    [RelayCommand]
    private void PickRecordingsFolder()
    {
        var d = new OpenFolderDialog { Title = "Ordner für Installationsaufzeichnungen" };
        if (d.ShowDialog() != true) return;
        S.RecordingsFolder = d.FolderName;
        _svc.Save();
        RecordingsFolder = InstallRecorder.Folder(S);
    }

    [RelayCommand]
    private void AddProtectedFolder()
    {
        var d = new OpenFolderDialog { Title = "Ordner, der nie als Rest vorgeschlagen wird" };
        if (d.ShowDialog() == true) Add(d.FolderName);
    }

    [RelayCommand]
    private void AddProtectedText()
    {
        var p = NewProtectedPath.Trim().Replace("HKLM\\", "HKEY_LOCAL_MACHINE\\").Replace("HKCU\\", "HKEY_CURRENT_USER\\");
        if (p.Length > 0) Add(p);
        NewProtectedPath = "";
    }

    private void Add(string p)
    {
        if (ProtectedPaths.Contains(p, StringComparer.OrdinalIgnoreCase)) return;
        ProtectedPaths.Add(p);
        S.ProtectedPaths = ProtectedPaths.ToList();
        _svc.Save();
    }

    [RelayCommand]
    private void RemoveProtected()
    {
        if (SelectedProtectedPath == null) return;
        ProtectedPaths.Remove(SelectedProtectedPath);
        S.ProtectedPaths = ProtectedPaths.ToList();
        _svc.Save();
    }

    [RelayCommand]
    private void OpenBackups() => Shell.Open(LeftoverDeleter.BackupDir);
}
