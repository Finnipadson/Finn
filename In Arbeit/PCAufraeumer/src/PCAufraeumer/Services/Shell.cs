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

    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    /// <summary>Windows-Titelleiste passend zum Design (dunkel/hell) einfärben.</summary>
    public static void ApplyTitleBar(Window w)
    {
        try
        {
            var hwnd = new System.Windows.Interop.WindowInteropHelper(w).Handle;
            if (hwnd == IntPtr.Zero) return;
            int dark = IsDark ? 1 : 0;
            DwmSetWindowAttribute(hwnd, 20, ref dark, sizeof(int));
            // Windows 11: Titelleiste in der Fensterfarbe (Graphit), damit sie nahtlos übergeht
            if (Application.Current?.TryFindResource("WindowBgColor") is System.Windows.Media.Color c)
            {
                int colorRef = c.R | (c.G << 8) | (c.B << 16);
                DwmSetWindowAttribute(hwnd, 35, ref colorRef, sizeof(int));
                int text = IsDark ? 0x00DEE5E9 : 0x001D2123; // COLORREF (BGR)
                DwmSetWindowAttribute(hwnd, 36, ref text, sizeof(int));
            }
        }
        catch { /* ältere Windows-Version */ }
    }

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
