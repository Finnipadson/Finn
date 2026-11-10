using System.Windows;

namespace PCAufraeumer.Views;

/// <summary>Bestätigungsdialog mit Zusammenfassung (Anzahl, Größe, Liste). Optional mit Pflicht-Häkchen.</summary>
public partial class ConfirmDialog : Window
{
    private readonly bool _needsCheck;

    private ConfirmDialog(string headline, string summary, string explanation, IReadOnlyList<string> lines,
        string okText, string? checkboxText)
    {
        InitializeComponent();
        SourceInitialized += (_, _) => Services.ThemeManager.ApplyTitleBar(this);
        Title = headline;
        Headline.Text = headline;
        SummaryText.Text = summary;
        Explanation.Text = explanation;
        Lines.ItemsSource = lines;
        OkButton.Content = okText;
        _needsCheck = checkboxText != null;
        if (_needsCheck)
        {
            Understood.Visibility = Visibility.Visible;
            UnderstoodText.Text = checkboxText;
            OkButton.Style = (Style)FindResource("DangerButton");
            OkButton.IsEnabled = false;
        }
        else
        {
            OkButton.Style = (Style)FindResource("PrimaryButton");
        }
        // Absichtlich ist „Abbrechen“ die Standardtaste (Enter löscht nie versehentlich).
    }

    public static bool Show(Window? owner, string headline, string summary, string explanation,
        IReadOnlyList<string> lines, string okText, string? requireCheckbox)
    {
        var dlg = new ConfirmDialog(headline, summary, explanation, lines, okText, requireCheckbox);
        if (owner != null && owner.IsVisible) dlg.Owner = owner;
        return dlg.ShowDialog() == true;
    }

    private void Understood_Changed(object sender, RoutedEventArgs e) => OkButton.IsEnabled = Understood.IsChecked == true;

    private void Ok_Click(object sender, RoutedEventArgs e)
    {
        if (_needsCheck && Understood.IsChecked != true) return;
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;
}
