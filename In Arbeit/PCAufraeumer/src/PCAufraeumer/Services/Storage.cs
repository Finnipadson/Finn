using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Alle Speicherorte der App (%APPDATA%\PCAufraeumer). Für Tests kann der Basisordner umgestellt werden.</summary>
public static class AppPaths
{
    private static string? _baseOverride;

    public static string BaseDir
    {
        get
        {
            var dir = _baseOverride ?? Environment.GetEnvironmentVariable("PCA_DATADIR") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PCAufraeumer");
            System.IO.Directory.CreateDirectory(dir);
            return dir;
        }
    }

    internal static void OverrideBaseDir(string dir) => _baseOverride = dir;

    public static string SettingsFile => Path.Combine(BaseDir, "einstellungen.json");
    public static string DeleteLogFile => Path.Combine(BaseDir, "loeschprotokoll.jsonl");
    public static string ErrorLogFile => Path.Combine(BaseDir, "fehler.log");
    public static string LastResultFile => Path.Combine(BaseDir, "letztes-ergebnis.json");
    public static string ResultsDir
    {
        get { var d = Path.Combine(BaseDir, "Ergebnisse"); System.IO.Directory.CreateDirectory(d); return d; }
    }
}

public static class Json
{
    public static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public static readonly JsonSerializerOptions Compact = new()
    {
        WriteIndented = false,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    /// <summary>Schreibt zuerst in eine Temp-Datei und ersetzt dann – so geht bei Absturz nichts kaputt.</summary>
    public static void WriteAtomic<T>(string path, T value)
    {
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(value, Options), Encoding.UTF8);
        File.Move(tmp, path, overwrite: true);
    }
}

/// <summary>Lädt und speichert die Einstellungen.</summary>
public sealed class SettingsService
{
    public AppSettings Current { get; private set; } = new();

    public event EventHandler? Saved;

    public void Load()
    {
        try
        {
            if (File.Exists(AppPaths.SettingsFile))
                Current = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(AppPaths.SettingsFile), Json.Options) ?? new AppSettings();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Einstellungen konnten nicht gelesen werden – Standardwerte werden verwendet.", ex);
            Current = new AppSettings();
        }

        if (Current.ScanFolders.Count == 0)
        {
            // Sinnvolle Vorbelegung: das eigene Benutzerprofil.
            Current.ScanFolders.Add(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
        }
        Current.VideoAgeDays = Math.Clamp(Current.VideoAgeDays, 1, 36500);
        Current.DownloadAgeDays = Math.Clamp(Current.DownloadAgeDays, 1, 36500);
        Current.MinSizeMB = Math.Max(0, Current.MinSizeMB);
        Current.DuplicateMinKB = Math.Max(1, Current.DuplicateMinKB);
    }

    public void Save()
    {
        try
        {
            Json.WriteAtomic(AppPaths.SettingsFile, Current);
            Saved?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Einstellungen konnten nicht gespeichert werden.", ex);
        }
    }

    public bool IsException(string path) =>
        Current.ExceptionFiles.Any(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));

    public void AddException(string path)
    {
        if (!IsException(path))
        {
            Current.ExceptionFiles.Add(path);
            Save();
        }
    }
}

/// <summary>Fehlerprotokoll. Fehler werden aufgeschrieben statt die App abstürzen zu lassen.</summary>
public static class ErrorLog
{
    private static readonly object Gate = new();

    public static event Action<string>? MessageLogged;

    public static void Write(string message, Exception? ex = null)
    {
        var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}  {message}" + (ex is null ? "" : $"  [{ex.GetType().Name}: {ex.Message}]");
        try
        {
            lock (Gate) File.AppendAllText(AppPaths.ErrorLogFile, line + Environment.NewLine, Encoding.UTF8);
        }
        catch { /* Protokoll darf selbst nie zum Absturz führen */ }
        MessageLogged?.Invoke(line);
    }

    public static string[] ReadRecent(int max = 500)
    {
        try
        {
            if (!File.Exists(AppPaths.ErrorLogFile)) return Array.Empty<string>();
            var all = File.ReadAllLines(AppPaths.ErrorLogFile);
            return all.Skip(Math.Max(0, all.Length - max)).Reverse().ToArray();
        }
        catch { return Array.Empty<string>(); }
    }
}
