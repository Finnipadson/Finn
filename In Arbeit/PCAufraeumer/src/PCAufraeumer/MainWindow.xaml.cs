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
        SourceInitialized += (_, _) => ThemeManager.ApplyTitleBar(this);
        Loaded += async (_, _) =>
        {
            _vm.Cleanup.OwnerWindow = new WindowInteropHelper(this).Handle;
            await _vm.InitializeAsync();
        };
        _vm.Settings.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(SettingsViewModel.DarkMode)) ThemeManager.ApplyTitleBar(this);
        };
        Closed += (_, _) => _vm.Thumbnails.Dispose();
    }
}
