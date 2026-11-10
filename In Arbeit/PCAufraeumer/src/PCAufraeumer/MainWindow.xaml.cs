using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using PCAufraeumer.Services;
using PCAufraeumer.ViewModels;

namespace PCAufraeumer;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;

    public MainWindow()
    {
        _vm = new MainViewModel();
        ThemeManager.Apply(_vm.SettingsService.Current.DarkMode);
        InitializeComponent();
        DataContext = _vm;
        Loaded += async (_, _) =>
        {
            _vm.Cleanup.OwnerWindow = new WindowInteropHelper(this).Handle;
            ApplyTitleBar();
            await _vm.InitializeAsync();
        };
        _vm.Settings.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(SettingsViewModel.DarkMode)) ApplyTitleBar();
        };
        Closed += (_, _) => _vm.Thumbnails.Dispose();
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    /// <summary>Dunkle Windows-Titelleiste passend zum Design.</summary>
    private void ApplyTitleBar()
    {
        try
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            int dark = ThemeManager.IsDark ? 1 : 0;
            DwmSetWindowAttribute(hwnd, 20, ref dark, sizeof(int));
        }
        catch { /* ältere Windows-Version */ }
    }
}
