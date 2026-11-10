using System.Diagnostics;
using System.Windows;

namespace PCAufraeumer.Services;

public static class Shell
{
    /// <summary>Öffnet Datei/Ordner/URL mit dem Standardprogramm.</summary>
    public static void Open(string target)
    {
        try { Process.Start(new ProcessStartInfo(target) { UseShellExecute = true })?.Dispose(); }
        catch (Exception ex)
        {
            ErrorLog.Write($"Konnte nicht geöffnet werden: {target}", ex);
            MessageBox.Show($"Konnte nicht geöffnet werden:\n{target}\n\n{ex.Message}", "PC Aufräumer",
                MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    /// <summary>Zeigt die Datei im Explorer markiert an.</summary>
    public static void ShowInExplorer(string path)
    {
        try
        {
            if (File.Exists(path))
                Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true })?.Dispose();
            else if (Directory.Exists(Path.GetDirectoryName(path)))
                Open(Path.GetDirectoryName(path)!);
        }
        catch (Exception ex) { ErrorLog.Write($"Explorer konnte nicht geöffnet werden: {path}", ex); }
    }
}

/// <summary>Schaltet zwischen hellem und dunklem Design um (Farb-Dictionary austauschen).</summary>
public static class ThemeManager
{
    public static bool IsDark { get; private set; }

    public static void Apply(bool dark)
    {
        IsDark = dark;
        var app = Application.Current;
        if (app == null) return;
        var dicts = app.Resources.MergedDictionaries;
        var old = dicts.FirstOrDefault(d => d.Source?.OriginalString.Contains("/Themes/Colors.") == true);
        var fresh = new ResourceDictionary
        {
            Source = new Uri($"pack://application:,,,/PCAufraeumer;component/Themes/Colors.{(dark ? "Dark" : "Light")}.xaml"),
        };
        if (old != null) dicts[dicts.IndexOf(old)] = fresh; else dicts.Insert(0, fresh);
    }
}
