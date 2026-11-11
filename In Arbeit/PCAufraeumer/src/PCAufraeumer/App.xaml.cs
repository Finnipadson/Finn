using System.Windows;
using System.Windows.Threading;
using PCAufraeumer.Services;

namespace PCAufraeumer;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Admin-Helfer: wird nur von der App selbst per UAC gestartet, um geschützte Temp-Ordner zu leeren.
        if (e.Args.Length == 3 && e.Args[0] == "--admin-clean")
        {
            int code = CleanupService.RunAdminHelper(e.Args[1], e.Args[2]);
            Shutdown(code);
            return;
        }
        // Allgemeiner Admin-Helfer (Programme deinstallieren, Registry, Autostart …) – nur fest erlaubte Aktionen.
        if (e.Args.Length == 3 && e.Args[0] == "--admin-job")
        {
            int code = AdminHelper.RunJobFile(e.Args[1], e.Args[2]);
            Shutdown(code);
            return;
        }

        DispatcherUnhandledException += OnUiException;
        AppDomain.CurrentDomain.UnhandledException += (_, ev) =>
            ErrorLog.Write("Unerwarteter Fehler (Hintergrund).", ev.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, ev) =>
        {
            ErrorLog.Write("Unerwarteter Fehler (Aufgabe).", ev.Exception);
            ev.SetObserved();
        };

        base.OnStartup(e);
        var window = new MainWindow();
        MainWindow = window;
        window.Show();
    }

    private void OnUiException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        ErrorLog.Write("Unerwarteter Fehler.", e.Exception);
        MessageBox.Show(
            "Da ist etwas schiefgegangen – die App läuft aber weiter.\n\n" + e.Exception.Message +
            $"\n\nDetails stehen im Fehlerprotokoll:\n{AppPaths.ErrorLogFile}",
            "PC Aufräumer", MessageBoxButton.OK, MessageBoxImage.Warning);
        e.Handled = true;
    }
}
