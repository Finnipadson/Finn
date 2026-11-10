using System.Windows.Controls;
using PCAufraeumer.Models;
using PCAufraeumer.ViewModels;

namespace PCAufraeumer.Views;

public partial class ResultsView : UserControl
{
    public ResultsView()
    {
        InitializeComponent();
    }

    /// <summary>Vorschaubilder nur für Zeilen erzeugen, die gerade sichtbar werden (Virtualisierung).</summary>
    private void Grid_LoadingRow(object? sender, DataGridRowEventArgs e)
    {
        if (e.Row.Item is FileCandidate c && DataContext is ResultsViewModel vm)
            vm.RequestThumbnail(c);
    }
}
