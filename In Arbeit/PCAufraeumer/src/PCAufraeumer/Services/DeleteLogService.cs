using System.Globalization;
using System.Text;
using System.Text.Json;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Protokoll aller Löschaktionen (JSON-Lines-Datei) inkl. CSV-Export.</summary>
public sealed class DeleteLogService
{
    private readonly object _gate = new();

    public void Append(IEnumerable<DeleteLogEntry> entries)
    {
        var sb = new StringBuilder();
        foreach (var e in entries) sb.AppendLine(JsonSerializer.Serialize(e, Json.Compact));
        if (sb.Length == 0) return;
        try
        {
            lock (_gate) File.AppendAllText(AppPaths.DeleteLogFile, sb.ToString(), Encoding.UTF8);
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Löschprotokoll konnte nicht geschrieben werden.", ex);
        }
    }

    public List<DeleteLogEntry> ReadAll()
    {
        var list = new List<DeleteLogEntry>();
        try
        {
            if (!File.Exists(AppPaths.DeleteLogFile)) return list;
            foreach (var line in File.ReadLines(AppPaths.DeleteLogFile))
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                try
                {
                    var e = JsonSerializer.Deserialize<DeleteLogEntry>(line, Json.Compact);
                    if (e != null) list.Add(e);
                }
                catch { /* defekte Zeile überspringen */ }
            }
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Löschprotokoll konnte nicht gelesen werden.", ex);
        }
        list.Reverse(); // neueste zuerst
        return list;
    }

    /// <summary>CSV mit Semikolon und UTF-8-BOM, damit deutsches Excel es direkt richtig öffnet.</summary>
    public static void ExportCsv(IEnumerable<DeleteLogEntry> entries, string file)
    {
        var de = CultureInfo.GetCultureInfo("de-DE");
        var sb = new StringBuilder();
        sb.AppendLine("Datum;Uhrzeit;Dateipfad;Größe (Bytes);Größe;Methode;Kategorie;Erfolgreich;Fehler");
        foreach (var e in entries)
        {
            sb.Append(e.Timestamp.ToString("dd.MM.yyyy", de)).Append(';')
              .Append(e.Timestamp.ToString("HH:mm:ss", de)).Append(';')
              .Append(Csv(e.Path)).Append(';')
              .Append(e.Size.ToString(de)).Append(';')
              .Append(Csv(Format.Bytes(e.Size))).Append(';')
              .Append(Csv(e.Method)).Append(';')
              .Append(Csv(e.Category)).Append(';')
              .Append(e.Success ? "Ja" : "Nein").Append(';')
              .Append(Csv(e.Error ?? ""))
              .AppendLine();
        }
        File.WriteAllText(file, sb.ToString(), new UTF8Encoding(true));
    }

    private static string Csv(string s) =>
        s.IndexOfAny(new[] { ';', '"', '\n', '\r' }) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;
}
