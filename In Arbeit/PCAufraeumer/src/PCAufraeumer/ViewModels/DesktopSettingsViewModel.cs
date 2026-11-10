using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Bereich „Desktop“ in den Einstellungen. Jede Änderung wird sofort gespeichert.</summary>
public sealed partial class DesktopSettingsViewModel : ObservableObject
{
    private readonly SettingsService _svc;
    private bool _loading;

    public ObservableCollection<string> Categories { get; } = new();
    public ObservableCollection<AppRule> AppRules { get; } = new();
    public ObservableCollection<FolderRule> FolderRules { get; } = new();
    public ObservableCollection<string> NeverTouch { get; } = new();

    [ObservableProperty] private string? _selectedCategory;
    [ObservableProperty] private string _categoryName = "";
    [ObservableProperty] private AppRule? _selectedAppRule;
    [ObservableProperty] private FolderRule? _selectedFolderRule;
    [ObservableProperty] private string? _selectedNeverTouch;
    [ObservableProperty] private string _neverTouchName = "";
    [ObservableProperty] private int _gapColumns;

    private DesktopSettings S => _svc.Current.Desktop;

    public DesktopSettingsViewModel(SettingsService svc)
    {
        _svc = svc;
        Reload();
        AppRules.CollectionChanged += (_, e) => { Hook(e); Save(); };
        FolderRules.CollectionChanged += (_, e) => { Hook(e); Save(); };
        NeverTouch.CollectionChanged += (_, _) => Save();
    }

    public void Reload()
    {
        _loading = true;
        Categories.Clear(); foreach (var c in S.Categories) Categories.Add(c);
        AppRules.Clear(); foreach (var r in S.AppRules) { r.PropertyChanged += RuleChanged; AppRules.Add(r); }
        FolderRules.Clear(); foreach (var r in S.FolderRules) { r.PropertyChanged += RuleChanged; FolderRules.Add(r); }
        NeverTouch.Clear(); foreach (var n in S.NeverTouch) NeverTouch.Add(n);
        GapColumns = S.GapColumns;
        _loading = false;
    }

    private void Hook(NotifyCollectionChangedEventArgs e)
    {
        if (e.NewItems != null) foreach (ObservableObject o in e.NewItems) o.PropertyChanged += RuleChanged;
        if (e.OldItems != null) foreach (ObservableObject o in e.OldItems) o.PropertyChanged -= RuleChanged;
    }

    private void RuleChanged(object? sender, PropertyChangedEventArgs e) => Save();

    partial void OnSelectedCategoryChanged(string? value) { if (value != null) CategoryName = value; }
    partial void OnGapColumnsChanged(int value) => Save();

    private void Save()
    {
        if (_loading) return;
        S.Categories = Categories.ToList();
        S.AppRules = AppRules.ToList();
        S.FolderRules = FolderRules.ToList();
        S.NeverTouch = NeverTouch.ToList();
        S.GapColumns = Math.Clamp(GapColumns, 0, 3);
        _svc.Save();
    }

    // ── Kategorien ──
    [RelayCommand]
    private void AddCategory()
    {
        var n = CategoryName.Trim();
        if (n.Length == 0 || Categories.Contains(n, StringComparer.OrdinalIgnoreCase)) return;
        // Vor „Sonstiges“ einfügen, damit „Sonstiges“ am Ende bleibt.
        int idx = Categories.IndexOf(DesktopSettings.Fallback);
        if (idx >= 0) Categories.Insert(idx, n); else Categories.Add(n);
        SelectedCategory = n;
        Save();
    }

    [RelayCommand]
    private void RenameCategory()
    {
        var old = SelectedCategory;
        var n = CategoryName.Trim();
        if (old == null || n.Length == 0 || old == n || Categories.Contains(n, StringComparer.OrdinalIgnoreCase)) return;
        Categories[Categories.IndexOf(old)] = n;
        foreach (var r in AppRules.Where(r => r.Category == old)) r.Category = n;
        foreach (var k in S.IconOverrides.Where(kv => kv.Value == old).Select(kv => kv.Key).ToList()) S.IconOverrides[k] = n;
        SelectedCategory = n;
        Save();
    }

    [RelayCommand]
    private void DeleteCategory()
    {
        var c = SelectedCategory;
        if (c == null) return;
        if (Categories.Count <= 1) { MessageBox.Show("Mindestens eine Kategorie muss bleiben.", "Desktop"); return; }
        if (MessageBox.Show($"Kategorie „{c}“ löschen?\nSymbole daraus landen danach in „{DesktopSettings.Fallback}“ (bzw. der letzten Kategorie).",
                "Kategorie löschen", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        Categories.Remove(c);
        foreach (var k in S.IconOverrides.Where(kv => kv.Value == c).Select(kv => kv.Key).ToList()) S.IconOverrides.Remove(k);
        Save();
    }

    [RelayCommand] private void MoveCategoryUp() => MoveCategory(-1);
    [RelayCommand] private void MoveCategoryDown() => MoveCategory(1);

    private void MoveCategory(int d)
    {
        var c = SelectedCategory;
        if (c == null) return;
        int i = Categories.IndexOf(c), j = i + d;
        if (j < 0 || j >= Categories.Count) return;
        Categories.Move(i, j);
        SelectedCategory = c;
        Save();
    }

    // ── Regeln ──
    [RelayCommand]
    private void AddAppRule()
    {
        var r = new AppRule("Programmname oder Pfadteil", SelectedCategory ?? Categories.FirstOrDefault() ?? DesktopSettings.Fallback);
        AppRules.Insert(0, r);
        SelectedAppRule = r;
    }

    [RelayCommand] private void RemoveAppRule() { if (SelectedAppRule != null) AppRules.Remove(SelectedAppRule); }

    [RelayCommand]
    private void AddFolderRule()
    {
        var r = new FolderRule("Neuer Ordner", ".xyz");
        FolderRules.Insert(Math.Max(0, FolderRules.Count - 1), r);
        SelectedFolderRule = r;
    }

    [RelayCommand] private void RemoveFolderRule() { if (SelectedFolderRule != null) FolderRules.Remove(SelectedFolderRule); }

    [RelayCommand]
    private void AddNeverTouch()
    {
        var n = NeverTouchName.Trim();
        if (n.Length > 0 && !NeverTouch.Contains(n, StringComparer.OrdinalIgnoreCase)) NeverTouch.Add(n);
        NeverTouchName = "";
    }

    [RelayCommand] private void RemoveNeverTouch() { if (SelectedNeverTouch != null) NeverTouch.Remove(SelectedNeverTouch); }

    [RelayCommand]
    private void ResetDesktopDefaults()
    {
        if (MessageBox.Show("Kategorien, Programm-Regeln und Ordner-Regeln auf die Standardwerte zurücksetzen?\n" +
                            "Deine „Nie anfassen“-Liste und gemerkten Zuordnungen bleiben erhalten.",
                "Standard wiederherstellen", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        S.Categories = DesktopSettings.DefaultCategories();
        S.AppRules = DesktopSettings.DefaultAppRules();
        S.FolderRules = DesktopSettings.DefaultFolderRules();
        _svc.Save();
        Reload();
    }
}
