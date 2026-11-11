using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

public sealed record StorageTarget(string Path, string Label);

/// <summary>Seite „Speicher“: Kachelkarte, welche Ordner wie viel Platz belegen. Liest nur, ändert nichts.</summary>
public sealed partial class StorageViewModel : ObservableObject
{
    private CancellationTokenSource? _cts;

    public ObservableCollection<StorageTarget> Targets { get; } = new();
    public ObservableCollection<DiskNode> Breadcrumb { get; } = new();
    public ObservableCollection<DiskNode> Entries { get; } = new();

    [ObservableProperty] private StorageTarget? _selectedTarget;
    [ObservableProperty] private DiskNode? _root;
    [ObservableProperty] private DiskNode? _current;
    [ObservableProperty] private DiskNode? _hoverNode;
    [ObservableProperty] private DiskNode? _selectedEntry;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _status = "Wähle ein Laufwerk oder einen Ordner und klicke auf „Analysieren“. Es wird nur gelesen, nichts verändert.";
    [ObservableProperty] private string _hoverText = "";

    public bool HasMap => Root != null;

    public StorageViewModel() => LoadTargets();

    private void LoadTargets()
    {
        Targets.Clear();
        foreach (var d in DriveInfo.GetDrives())
        {
            try
            {
                if (!d.IsReady || d.DriveType is not (DriveType.Fixed or DriveType.Removable)) continue;
                var label = string.IsNullOrWhiteSpace(d.VolumeLabel) ? "Laufwerk" : d.VolumeLabel;
                Targets.Add(new StorageTarget(d.RootDirectory.FullName,
                    $"{d.Name.TrimEnd('\\')}  {label} – {Format.Bytes(d.TotalFreeSpace)} frei von {Format.Bytes(d.TotalSize)}"));
            }
            catch { }
        }
        var profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        Targets.Add(new StorageTarget(profile, $"Benutzerordner ({profile})"));
        SelectedTarget = Targets.FirstOrDefault();
    }

    partial void OnRootChanged(DiskNode? value) => OnPropertyChanged(nameof(HasMap));

    partial void OnIsBusyChanged(bool value)
    {
        AnalyzeCommand.NotifyCanExecuteChanged();
        CancelCommand.NotifyCanExecuteChanged();
    }

    partial void OnHoverNodeChanged(DiskNode? value) =>
        HoverText = value == null ? "" : $"{value.Name}  ·  {value.SizeText}  ·  {value.ShareText} von „{value.Parent?.Name}“" +
                                         (value.Detail.Length > 0 ? "  ·  " + value.Detail : "");

    partial void OnCurrentChanged(DiskNode? value)
    {
        Breadcrumb.Clear();
        Entries.Clear();
        HoverNode = null;
        if (value == null) return;
        foreach (var n in value.PathFromRoot()) Breadcrumb.Add(n);
        foreach (var c in value.Children.Take(200)) Entries.Add(c);
    }

    private bool CanAnalyze() => !IsBusy;

    [RelayCommand(CanExecute = nameof(CanAnalyze))]
    private async Task AnalyzeAsync()
    {
        var target = SelectedTarget?.Path;
        if (string.IsNullOrEmpty(target) || !Directory.Exists(target))
        {
            Status = "Ordner nicht gefunden.";
            return;
        }
        IsBusy = true;
        _cts = new CancellationTokenSource();
        var progress = new DiskMapProgress();
        var sw = Stopwatch.StartNew();
        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        timer.Tick += (_, _) =>
            Status = $"Lese {target} … {Interlocked.Read(ref progress.Files):N0} Dateien, {Format.Bytes(Interlocked.Read(ref progress.Bytes))}  ·  {progress.Current}";
        timer.Start();
        try
        {
            var svc = new DiskMapService();
            var ct = _cts.Token;
            var root = await Task.Run(() => svc.Scan(target, progress, ct), ct);
            Root = root;
            Current = root;
            Status = $"Fertig in {sw.Elapsed.TotalSeconds:0.0} s: {root.FileCount:N0} Dateien, {Format.Bytes(root.Size)}" +
                     (root.Unreadable > 0 ? $" · {root.Unreadable:N0} Ordner ohne Zugriff (z. B. Systemordner)" : "") +
                     (svc.CloudOnlyBytes > 0 ? $" · {Format.Bytes(svc.CloudOnlyBytes)} nur online (OneDrive, belegt keinen Platz)" : "") +
                     (svc.SkippedLinks > 0 ? $" · {svc.SkippedLinks} verknüpfte Ordner übersprungen" : "") +
                     ". Klicke auf eine Kachel, um hineinzuzoomen.";
        }
        catch (OperationCanceledException) { Status = "Abgebrochen."; }
        catch (Exception ex)
        {
            ErrorLog.Write("Speicherplatz-Analyse fehlgeschlagen.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally
        {
            timer.Stop();
            IsBusy = false;
            _cts?.Dispose();
            _cts = null;
        }
    }

    private bool CanCancel() => IsBusy;

    [RelayCommand(CanExecute = nameof(CanCancel))]
    private void Cancel() => _cts?.Cancel();

    [RelayCommand]
    private void Browse()
    {
        var d = new OpenFolderDialog { Title = "Ordner für die Speicherplatz-Karte wählen" };
        if (d.ShowDialog() != true) return;
        var t = Targets.FirstOrDefault(x => string.Equals(x.Path, d.FolderName, StringComparison.OrdinalIgnoreCase))
                ?? new StorageTarget(d.FolderName, d.FolderName);
        if (!Targets.Contains(t)) Targets.Add(t);
        SelectedTarget = t;
        _ = AnalyzeAsync();
    }

    /// <summary>Kachel oder Listeneintrag geöffnet: Ordner → hineinzoomen, Datei → in der Liste markieren.</summary>
    [RelayCommand]
    private void Open(DiskNode? node)
    {
        if (node == null) return;
        if (node.CanOpen) { Current = node; return; }
        SelectedEntry = Entries.FirstOrDefault(e => ReferenceEquals(e, node));
    }

    [RelayCommand]
    private void Up()
    {
        if (Current?.Parent != null) Current = Current.Parent;
    }

    [RelayCommand]
    private void ShowInExplorer(DiskNode? node)
    {
        node ??= SelectedEntry ?? Current;
        if (node == null) return;
        if (node.IsDirectory && !node.IsGroup) Shell.Open(node.FullPath);
        else if (node.IsGroup) Shell.Open(node.FullPath);
        else Shell.ShowInExplorer(node.FullPath);
    }
}
