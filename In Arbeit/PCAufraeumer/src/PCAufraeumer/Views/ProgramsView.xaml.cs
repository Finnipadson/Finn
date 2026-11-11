using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using PCAufraeumer.Models;
using PCAufraeumer.ViewModels;

namespace PCAufraeumer.Views;

public partial class ProgramsView : UserControl
{
    private UninstallViewModel? _wizard;

    public ProgramsView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) =>
        {
            if (_wizard != null) _wizard.PropertyChanged -= WizardChanged;
            _wizard = (DataContext as ProgramsPageViewModel)?.Uninstall;
            if (_wizard != null) { _wizard.PropertyChanged += WizardChanged; UpdateStage(); }
        };
    }

    private void WizardChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(UninstallViewModel.Stage)) UpdateStage();
    }

    private void UpdateStage()
    {
        if (_wizard == null) return;
        ModePanel.Visibility = _wizard.Stage == UninstallStage.Moduswahl ? Visibility.Visible : Visibility.Collapsed;
        ResultPanel.Visibility = _wizard.Stage == UninstallStage.Ergebnis ? Visibility.Visible : Visibility.Collapsed;
        // In der Ergebnisansicht braucht die Warteschlange keinen Platz mehr
        QueueList.Visibility = _wizard.Stage == UninstallStage.Ergebnis ? Visibility.Collapsed : Visibility.Visible;
    }

    /// <summary>Symbole nur für sichtbare Zeilen laden.</summary>
    private void ProgramGrid_LoadingRow(object? sender, DataGridRowEventArgs e)
    {
        if (e.Row.Item is InstalledProgram p && DataContext is ProgramsPageViewModel vm) vm.List.RequestIcon(p);
    }
}
