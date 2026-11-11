using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Löschen. Funde aus dem Dateiscan gehen AUSSCHLIESSLICH in den Windows-Papierkorb.
/// Nur Temp/Cache wird direkt gelöscht (separate Bestätigung in der Oberfläche).
/// </summary>
public sealed class CleanupService
{
    private readonly ProtectionService _protection;
    private readonly DeleteLogService _log;

    public CleanupService(ProtectionService protection, DeleteLogService log)
    {
        _protection = protection;
        _log = log;
    }

    public IntPtr OwnerWindow { get; set; }

    /// <summary>
    /// Prüft eine geplante Löschung. Gibt eine Liste mit Problemen zurück (leer = alles in Ordnung).
    /// Regel: Von jeder Duplikat-Gruppe muss mindestens eine Kopie erhalten bleiben.
    /// </summary>
    public static List<string> ValidateDuplicateGroups(IReadOnlyCollection<FileCandidate> toDelete, IEnumerable<FileCandidate> all)
    {
        var problems = new List<string>();
        var deletePaths = new HashSet<string>(toDelete.Select(c => c.FullPath), StringComparer.OrdinalIgnoreCase);
        foreach (var g in all.Where(c => c.Category == FindingCategory.Duplicates).GroupBy(c => c.GroupId))
        {
            if (!g.Any(c => deletePaths.Contains(c.FullPath))) continue;
            bool survivor = g.Any(c => !c.IsDeleted && !deletePaths.Contains(c.FullPath) && File.Exists(c.FullPath));
            if (!survivor)
                problems.Add($"Gruppe {g.Key}: Es würde keine Kopie übrig bleiben ({g.First().Name}).");
        }
        return problems;
    }

    /// <summary>
    /// Spielaufnahmen in den Unterordner „Behalten“ ihres Ordners verschieben (dort werden sie nie mehr vorgeschlagen).
    /// Nichts wird überschrieben. Gibt die verschobenen Funde und Probleme zurück.
    /// </summary>
    public (List<FileCandidate> moved, List<string> problems) MoveToKeepFolder(IEnumerable<FileCandidate> clips)
    {
        var moved = new List<FileCandidate>();
        var problems = new List<string>();
        var log = new List<DeleteLogEntry>();
        var reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var c in clips)
        {
            var e = new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = c.FullPath, Size = c.Size,
                Method = "Aufnahme: nach „Behalten“ verschoben", Category = c.CategoryLabel,
            };
            try
            {
                if (c.Category != FindingCategory.Recordings) throw new InvalidOperationException("Nur für Spielaufnahmen.");
                if (!File.Exists(c.FullPath)) throw new IOException("Datei existiert nicht mehr.");
                if (ProtectionService.IsLocked(c.FullPath)) throw new IOException("Datei ist geöffnet/gesperrt.");
                var dir = Path.Combine(Path.GetDirectoryName(c.FullPath)!, RecordingSources.KeepFolderName);
                Directory.CreateDirectory(dir);
                var dest = DesktopPlanner.UniquePath(dir, Path.GetFileName(c.FullPath), reserved);
                File.Move(c.FullPath, dest, overwrite: false);
                e.Success = true;
                e.Error = $"→ {dest}";
                moved.Add(c);
            }
            catch (Exception ex)
            {
                e.Success = false;
                e.Error = ex.Message;
                problems.Add($"{c.Name}: {ex.Message}");
            }
            log.Add(e);
        }
        _log.Append(log);
        return (moved, problems);
    }

    /// <summary>Verschiebt Dateien einzeln in den Papierkorb und protokolliert jede Aktion.</summary>
    public Task<List<DeleteLogEntry>> RecycleAsync(IReadOnlyList<FileCandidate> files, IReadOnlyCollection<FileCandidate> all,
        IProgress<(int done, int total, string path)> progress, CancellationToken ct)
    {
        var problems = ValidateDuplicateGroups(files, all);
        if (problems.Count > 0) throw new InvalidOperationException(string.Join(Environment.NewLine, problems));

        return StaTask.Run(() =>
        {
            var entries = new List<DeleteLogEntry>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            int i = 0;
            foreach (var c in files)
            {
                if (ct.IsCancellationRequested) break;
                i++;
                if (!seen.Add(c.FullPath)) continue;
                progress.Report((i, files.Count, c.FullPath));
                var e = new DeleteLogEntry
                {
                    Timestamp = DateTime.Now, Path = c.FullPath, Size = c.Size,
                    Method = "Papierkorb", Category = c.CategoryLabel,
                };
                e.Error = RecycleOne(c);
                e.Success = e.Error == null;
                entries.Add(e);
            }
            _log.Append(entries);
            return entries;
        });
    }

    /// <summary>Gibt null bei Erfolg zurück, sonst eine verständliche Fehlermeldung.</summary>
    internal string? RecycleOne(FileCandidate c)
    {
        try
        {
            var problem = _protection.CheckFile(c.FullPath, checkLock: true);
            if (problem != null) return problem;

            var fi = new FileInfo(c.FullPath);
            if (fi.Length != c.Size) return "Datei hat sich seit dem Scan verändert – bitte neu scannen.";

            var root = Path.GetPathRoot(fi.FullName);
            if (root == null || root.StartsWith(@"\\", StringComparison.Ordinal))
                return "Netzwerkpfad – dort gibt es keinen Papierkorb. Nicht gelöscht.";
            var drive = new DriveInfo(root);
            if (drive.DriveType != DriveType.Fixed)
                return $"Laufwerk {root} ({drive.DriveType}) hat keinen Papierkorb. Nicht gelöscht.";

            var op = new NativeMethods.SHFILEOPSTRUCT
            {
                hwnd = OwnerWindow,
                wFunc = NativeMethods.FO_DELETE,
                pFrom = fi.FullName + "\0", // doppelt nullterminiert
                // ALLOWUNDO = Papierkorb. WANTNUKEWARNING: Windows warnt, falls die Datei NICHT in den Papierkorb passt.
                fFlags = (ushort)(NativeMethods.FOF_ALLOWUNDO | NativeMethods.FOF_NOCONFIRMATION |
                                  NativeMethods.FOF_SILENT | NativeMethods.FOF_NOERRORUI | NativeMethods.FOF_WANTNUKEWARNING),
            };
            int rc = NativeMethods.SHFileOperation(ref op);
            if (op.fAnyOperationsAborted) return "Vom Benutzer abgebrochen (Datei passt nicht in den Papierkorb).";
            if (rc != 0) return $"Windows meldet Fehler 0x{rc:X} – Datei wurde nicht gelöscht.";
            if (File.Exists(fi.FullName)) return "Datei ist noch vorhanden – Löschen fehlgeschlagen.";
            return null;
        }
        catch (Exception ex)
        {
            ErrorLog.Write($"Papierkorb fehlgeschlagen: {c.FullPath}", ex);
            return ex.Message;
        }
    }

    /// <summary>Leert Temp/Cache-Bereiche. Bereiche mit Adminrechten laufen über einen Helfer mit UAC-Abfrage.</summary>
    public async Task<List<DeleteLogEntry>> CleanTempAsync(IReadOnlyList<TempTarget> targets, IProgress<string> progress, CancellationToken ct)
    {
        var entries = new List<DeleteLogEntry>();
        var normal = targets.Where(t => !t.RequiresAdmin || TempService.IsAdmin).ToList();
        var admin = targets.Where(t => t.RequiresAdmin && !TempService.IsAdmin).ToList();

        await Task.Run(() =>
        {
            foreach (var t in normal)
            {
                ct.ThrowIfCancellationRequested();
                progress.Report(t.Name);
                entries.AddRange(TempService.Clean(t, progress, ct));
            }
        }, ct);

        if (admin.Count > 0)
        {
            progress.Report("Warte auf Adminrechte (UAC) …");
            entries.AddRange(await RunElevatedCleanAsync(admin));
        }

        _log.Append(entries);
        return entries;
    }

    private static async Task<List<DeleteLogEntry>> RunElevatedCleanAsync(List<TempTarget> targets)
    {
        var job = Path.Combine(Path.GetTempPath(), $"pcaufraeumer-job-{Guid.NewGuid():N}.json");
        var res = job.Replace("-job-", "-result-");
        File.WriteAllText(job, JsonSerializer.Serialize(targets.Select(t => t.Id).ToList()));
        try
        {
            var exe = Environment.ProcessPath ?? throw new InvalidOperationException("Programmpfad unbekannt.");
            var psi = new ProcessStartInfo(exe, $"--admin-clean \"{job}\" \"{res}\"")
            {
                UseShellExecute = true,
                Verb = "runas",
            };
            using var p = Process.Start(psi) ?? throw new InvalidOperationException("Helfer konnte nicht gestartet werden.");
            await p.WaitForExitAsync();
            if (!File.Exists(res)) throw new InvalidOperationException("Der Admin-Helfer hat kein Ergebnis geliefert.");
            return JsonSerializer.Deserialize<List<DeleteLogEntry>>(File.ReadAllText(res)) ?? new();
        }
        catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            return targets.Select(t => new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = string.Join(" | ", t.Paths), Category = t.Name,
                Method = "Direkt gelöscht (Temp/Cache)", Success = false, Error = "Adminrechte abgelehnt – nicht geleert.",
            }).ToList();
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Admin-Helfer fehlgeschlagen.", ex);
            return targets.Select(t => new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = string.Join(" | ", t.Paths), Category = t.Name,
                Method = "Direkt gelöscht (Temp/Cache)", Success = false, Error = ex.Message,
            }).ToList();
        }
        finally
        {
            try { File.Delete(job); } catch { }
            try { File.Delete(res); } catch { }
        }
    }

    /// <summary>Wird im Admin-Helferprozess ausgeführt (Aufruf mit --admin-clean). Nimmt nur IDs entgegen,
    /// die Pfade stammen aus der fest eingebauten Liste – der Helfer löscht also nie beliebige Pfade.</summary>
    public static int RunAdminHelper(string jobFile, string resultFile)
    {
        var log = new List<DeleteLogEntry>();
        try
        {
            var ids = JsonSerializer.Deserialize<List<string>>(File.ReadAllText(jobFile)) ?? new();
            var allowed = TempService.BuildTargets().Where(t => t.RequiresAdmin && ids.Contains(t.Id));
            foreach (var t in allowed)
                log.AddRange(TempService.Clean(t, null, CancellationToken.None));
        }
        catch (Exception ex)
        {
            log.Add(new DeleteLogEntry { Timestamp = DateTime.Now, Path = jobFile, Success = false, Error = ex.Message, Method = "Admin-Helfer" });
        }
        File.WriteAllText(resultFile, JsonSerializer.Serialize(log));
        return 0;
    }
}

/// <summary>Führt Code auf einem eigenen STA-Thread aus (für Shell-APIs wie SHFileOperation).</summary>
public static class StaTask
{
    public static Task<T> Run<T>(Func<T> func)
    {
        var tcs = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        var t = new Thread(() =>
        {
            try { tcs.SetResult(func()); }
            catch (Exception ex) { tcs.SetException(ex); }
        }) { IsBackground = true };
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        return tcs.Task;
    }
}
