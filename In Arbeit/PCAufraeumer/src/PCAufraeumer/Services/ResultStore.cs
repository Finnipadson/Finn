using System.Text.Json;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Speichert/lädt Ergebnislisten, damit man ohne neuen Scan weiterarbeiten kann.</summary>
public static class ResultStore
{
    public static void Save(SavedScanResult r, string file) => Json.WriteAtomic(file, r);

    public static SavedScanResult? Load(string file)
    {
        try
        {
            if (!File.Exists(file)) return null;
            return JsonSerializer.Deserialize<SavedScanResult>(File.ReadAllText(file), Json.Options);
        }
        catch (Exception ex)
        {
            ErrorLog.Write($"Ergebnisliste konnte nicht geladen werden: {file}", ex);
            return null;
        }
    }
}
