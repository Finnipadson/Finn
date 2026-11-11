using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Seite „Programme“ – Tab „Deinstallieren“: Programmliste mit Filter, Gruppierung, Kategorien.</summary>
public sealed partial class ProgramsViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly ProgramInventory _inventory = new();
    private CancellationTokenSource? _sizeCts;
    private bool _loaded;

    public ObservableCollection<InstalledProgram> Programs { get; } = new();
    public ICollectionView View { get; }

    public static IReadOnlyList<string> TypeFilters { get; } = new[] { "Alle Typen", "Programme", "Store-Apps", "Windows-Apps", "Spiele" };
    public ObservableCollection<string> CategoryFilters { get; } = new();
    public IReadOnlyList<string> Categories => _settings.Current.Desktop.Categories;

    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private string _typeFilter = "Alle Typen";
    [ObservableProperty] private string _categoryFilter = "Alle Kategorien";
    [ObservableProperty] private bool _showHidden;
    [ObservableProperty] private bool _groupByCategory;
    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private string _status = "";
    [ObservableProperty] private InstalledProgram? _selected;
    [ObservableProperty] private int _checkedCount;

    /// <summary>Wird von der Deinstallations-Logik gesetzt (Teil B).</summary>
    public UninstallViewModel Uninstall { get; }

    public ProgramsViewModel(SettingsService settings, UninstallViewModel uninstall)
    {
        _settings = settings;
        Uninstall = uninstall;
        _showHidden = settings.Current.Programs.ShowSystemComponents;
        _groupByCategory = settings.Current.Programs.GroupByCategory;
        View = CollectionViewSource.GetDefaultView(Programs);
        View.Filter = Filter;
        View.SortDescriptions.Add(new SortDescription(nameof(InstalledProgram.Name), ListSortDirection.Ascending));
        ApplyGrouping();
    }

    public async Task EnsureLoadedAsync()
    {
        if (_loaded) return;
        _loaded = true;
        await ReloadAsync();
    }

    [RelayCommand]
    public async Task ReloadAsync()
    {
        if (IsLoading) return;
        IsLoading = true;
        Status = "Programme werden gelesen …";
        _sizeCts?.Cancel();
        try
        {
            var list = await Task.Run(() => _inventory.ReadAll());
            var cat = new DesktopCategorizer(_settings.Current.Desktop);
            var recorded = InstallRecorder.RecordedProgramIds();
            foreach (var p in Programs) p.PropertyChanged -= ProgramChanged;
            Programs.Clear();
            foreach (var p in list)
            {
                p.Category = cat.CategorizeProgram(p);
                p.IsRecorded = recorded.Contains(p.Id) || recorded.Contains(DesktopCategorizer.NameKey(p.Name));
                p.PropertyChanged += ProgramChanged;
                Programs.Add(p);
            }
            CategoryFilters.Clear();
            CategoryFilters.Add("Alle Kategorien");
            foreach (var c in Categories) CategoryFilters.Add(c);
            if (!CategoryFilters.Contains(CategoryFilter)) CategoryFilter = "Alle Kategorien";
            UpdateStatus();
            _ = ComputeMissingSizesAsync();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Programmliste konnte nicht geladen werden.", ex);
            Status = "Fehler: " + ex.Message;
        }
        finally { IsLoading = false; }
    }

    private void UpdateStatus()
    {
        var visible = View.Cast<InstalledProgram>().ToList();
        Status = $"{visible.Count} Einträge angezeigt · {Programs.Count(p => p.HiddenByDefault)} Systemkomponenten/Updates " +
                 (ShowHidden ? "eingeblendet" : "ausgeblendet") +
                 $" · zusammen {Format.Bytes(visible.Sum(p => p.Size ?? 0))}";
        CheckedCount = Programs.Count(p => p.IsChecked);
    }

    private void ProgramChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (sender is not InstalledProgram p) return;
        if (e.PropertyName == nameof(InstalledProgram.IsChecked)) CheckedCount = Programs.Count(x => x.IsChecked);
        if (e.PropertyName == nameof(InstalledProgram.Category) && _loaded && !IsLoading)
        {
            // Kategorie merken – gilt auch fürs Desktop-Aufräumen
            new DesktopCategorizer(_settings.Current.Desktop).RememberProgramCategory(p, p.Category);
            _settings.Save();
            if (GroupByCategory) View.Refresh();
        }
    }

    /// <summary>Größe für Einträge ohne EstimatedSize im Hintergrund ermitteln.</summary>
    private async Task ComputeMissingSizesAsync()
    {
        _sizeCts = new CancellationTokenSource();
        var ct = _sizeCts.Token;
        foreach (var p in Programs.Where(p => p.Size == null && p.InstallLocation.Length > 0).ToList())
        {
            if (ct.IsCancellationRequested) return;
            try
            {
                var size = await Task.Run(() => ProgramInventory.FolderSize(p.InstallLocation, ct), ct);
                if (size is > 0) { p.Size = size; p.SizeIsEstimate = true; }
            }
            catch (OperationCanceledException) { return; }
        }
        UpdateStatus();
    }

    private bool Filter(object o)
    {
        if (o is not InstalledProgram p) return false;
        if (!ShowHidden && p.HiddenByDefault) return false;
        switch (TypeFilter)
        {
            case "Programme" when p.Kind != ProgramKind.Programm: return false;
            case "Store-Apps" when p.Kind != ProgramKind.StoreApp: return false;
            case "Windows-Apps" when p.Kind != ProgramKind.WindowsApp: return false;
            case "Spiele" when p.Kind != ProgramKind.Spiel: return false;
        }
        if (CategoryFilter != "Alle Kategorien" && p.Category != CategoryFilter) return false;
        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var q = SearchText.Trim();
            return p.Name.Contains(q, StringComparison.OrdinalIgnoreCase) || p.Publisher.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                   p.InstallLocation.Contains(q, StringComparison.OrdinalIgnoreCase);
        }
        return true;
    }

    partial void OnSearchTextChanged(string value) { View.Refresh(); UpdateStatus(); }
    partial void OnTypeFilterChanged(string value) { View.Refresh(); UpdateStatus(); }
    partial void OnCategoryFilterChanged(string value) { View.Refresh(); UpdateStatus(); }
    partial void OnShowHiddenChanged(bool value)
    {
        _settings.Current.Programs.ShowSystemComponents = value;
        _settings.Save();
        View.Refresh();
        UpdateStatus();
    }
    partial void OnGroupByCategoryChanged(bool value)
    {
        _settings.Current.Programs.GroupByCategory = value;
        _settings.Save();
        ApplyGrouping();
    }

    private void ApplyGrouping()
    {
        View.GroupDescriptions.Clear();
        if (GroupByCategory) View.GroupDescriptions.Add(new PropertyGroupDescription(nameof(InstalledProgram.Category)));
    }

    /// <summary>Symbol laden (nur für sichtbare Zeilen).</summary>
    public void RequestIcon(InstalledProgram p)
    {
        if (p.Icon != null) return;
        try
        {
            var src = p.DisplayIcon.Length > 0 ? p.DisplayIcon : p.MainExe;
            var exe = ProgramInventory.ExeFromIcon(src);
            if (src.EndsWith(".png", StringComparison.OrdinalIgnoreCase) || src.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase))
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.DecodePixelWidth = 32;
                bi.UriSource = new Uri(src);
                bi.EndInit();
                bi.Freeze();
                p.Icon = bi;
            }
            else if (exe.Length > 0 && File.Exists(exe)) p.Icon = ShellIcons.Get(exe, 32);
            else if (src.EndsWith(".ico", StringComparison.OrdinalIgnoreCase) && File.Exists(src)) p.Icon = ShellIcons.Get(src, 32);
            else if (p.InstallLocation.Length > 0 && Directory.Exists(p.InstallLocation)) p.Icon = ShellIcons.Get(p.InstallLocation, 32);
        }
        catch { /* kein Symbol */ }
    }

    // ───────────── Rechtsklick-Menü ─────────────

    [RelayCommand]
    private void OpenFolder(InstalledProgram? p)
    {
        p ??= Selected;
        if (p == null) return;
        if (p.InstallLocation.Length > 0 && Directory.Exists(p.InstallLocation)) Shell.Open(p.InstallLocation);
        else if (p.MainExe.Length > 0 && File.Exists(p.MainExe)) Shell.ShowInExplorer(p.MainExe);
        else MessageBox.Show(Application.Current.MainWindow, "Für diesen Eintrag ist kein Installationsordner bekannt.", "Programme");
    }

    [RelayCommand]
    private void ShowRegistry(InstalledProgram? p)
    {
        p ??= Selected;
        if (p == null || p.RegistryPath.Length == 0)
        {
            MessageBox.Show(Application.Current.MainWindow, "Dieser Eintrag hat keinen Registry-Eintrag (Store-App oder Launcher-Spiel).", "Programme");
            return;
        }
        try
        {
            // Der Registrierungs-Editor öffnet beim zuletzt angezeigten Schlüssel.
            using var k = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Applets\Regedit");
            k.SetValue("LastKey", @"Computer\" + p.RegistryPath);
            Shell.Open("regedit.exe");
        }
        catch (Exception ex) { ErrorLog.Write("Registrierungs-Editor konnte nicht geöffnet werden.", ex); }
    }

    [RelayCommand]
    private void SearchWeb(InstalledProgram? p)
    {
        p ??= Selected;
        if (p == null) return;
        Shell.Open("https://www.bing.com/search?q=" + Uri.EscapeDataString($"{p.Name} {p.Publisher}".Trim()));
    }

    [RelayCommand]
    private async Task RemoveOrphanAsync(InstalledProgram? p)
    {
        p ??= Selected;
        if (p == null) return;
        if (!p.IsOrphaned)
        {
            MessageBox.Show(Application.Current.MainWindow,
                "Nur verwaiste Einträge (Programm und Deinstaller existieren nicht mehr) können aus der Liste entfernt werden.", "Programme");
            return;
        }
        if (MessageBox.Show(Application.Current.MainWindow,
                $"Den verwaisten Eintrag „{p.Name}“ aus der Programmliste entfernen?\n\n" +
                $"Dabei wird nur der Registry-Eintrag gelöscht:\n{p.RegistryPath}\n\nVorher wird er als .reg-Datei gesichert.",
                "Eintrag entfernen", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        var res = await Uninstall.RemoveRegistryEntriesAsync(new[] { p.RegistryPath }, p.Name);
        if (res) Programs.Remove(p);
        UpdateStatus();
    }

    [RelayCommand]
    private void SelectNone()
    {
        foreach (var p in Programs) p.IsChecked = false;
    }

    // ───────────── Deinstallieren ─────────────

    [RelayCommand]
    private async Task UninstallSelectedAsync(InstalledProgram? p)
    {
        p ??= Selected;
        if (p == null) return;
        await Uninstall.StartAsync(new[] { p });
        await ReloadAfterUninstall();
    }

    [RelayCommand]
    private async Task UninstallCheckedAsync()
    {
        var list = Programs.Where(x => x.IsChecked && !x.IsLocked).ToList();
        if (list.Count == 0) return;
        await Uninstall.StartAsync(list);
        await ReloadAfterUninstall();
    }

    private async Task ReloadAfterUninstall()
    {
        _loaded = true;
        await ReloadAsync();
    }
}
