using System.Text.Json;
using PCAufraeumer.Interop;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Verlauf der Aufräumaktionen (je eine JSON-Datei, die neuesten 20 werden behalten).</summary>
public static class DesktopHistory
{
    public const int Keep = 20;
    public static string Dir
    {
        get { var d = Path.Combine(AppPaths.BaseDir, "Desktop-Verlauf"); Directory.CreateDirectory(d); return d; }
    }

    public static void Save(DesktopSnapshot s)
    {
        Json.WriteAtomic(Path.Combine(Dir, $"{s.Date:yyyyMMdd-HHmmss}-{s.Id[..8]}.json"), s);
        // Nur eigene Verlaufsdateien über dem Limit entfernen (älteste zuerst).
        foreach (var old in Directory.GetFiles(Dir, "*.json").OrderByDescending(f => f).Skip(Keep))
            try { File.Delete(old); } catch { }
    }

    public static List<DesktopSnapshot> Load()
    {
        var list = new List<DesktopSnapshot>();
        foreach (var f in Directory.GetFiles(Dir, "*.json").OrderByDescending(f => f))
        {
            try
            {
                var s = JsonSerializer.Deserialize<DesktopSnapshot>(File.ReadAllText(f), Json.Options);
                if (s != null) list.Add(s);
            }
            catch (Exception ex) { ErrorLog.Write($"Desktop-Verlauf nicht lesbar: {f}", ex); }
        }
        return list;
    }

    public static void Update(DesktopSnapshot s)
    {
        var file = Directory.GetFiles(Dir, $"*-{s.Id[..8]}.json").FirstOrDefault();
        if (file != null) Json.WriteAtomic(file, s); else Save(s);
    }
}

public sealed class DesktopApplyResult
{
    public int Moved { get; set; }
    public int Positioned { get; set; }
    public int FoldersCreated { get; set; }
    public int FoldersRemoved { get; set; }
    public List<string> Problems { get; } = new();
}

/// <summary>
/// Führt einen Plan aus bzw. macht ihn rückgängig. Löscht NIE Dateien. Vor jeder Änderung wird
/// der komplette alte Zustand gespeichert (Positionen, Pfade, neue Ordner).
/// </summary>
public sealed class DesktopApplier
{
    private readonly DeleteLogService _log;
    public DesktopApplier(DeleteLogService log) => _log = log;

    /// <summary>Wartezeit, bis der Explorer Dateiänderungen anzeigt (für Tests verkürzbar).</summary>
    public TimeSpan RefreshTimeout { get; set; } = TimeSpan.FromSeconds(6);

    /// <param name="view">Symbolansicht (null = nur Dateien, z. B. in Tests). Aufruf auf dem UI-Thread.</param>
    public async Task<(DesktopApplyResult result, DesktopSnapshot snapshot)> ApplyAsync(
        DesktopShellView? view, DesktopPlan plan, string viewKind, IProgress<string>? progress = null)
    {
        var result = new DesktopApplyResult();
        var snap = new DesktopSnapshot { ViewKind = viewKind, Description = "Desktop aufgeräumt" };

        // 1) Alten Zustand sichern
        if (view != null)
            foreach (var i in view.GetItems())
                snap.Positions.Add(new SnapshotPosition { Path = i.ParsingPath, X = i.X, Y = i.Y });
        DesktopHistory.Save(snap);

        // 2) Ordner anlegen, Dateien verschieben (Hintergrund)
        var moves = plan.Moves.ToList();
        await Task.Run(() =>
        {
            var log = new List<DeleteLogEntry>();
            var reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var c in moves)
            {
                var src = c.Item.Path;
                var folder = Path.GetDirectoryName(c.FinalPath)!;
                var e = new DeleteLogEntry { Timestamp = DateTime.Now, Path = src, Method = "Desktop: verschoben", Category = "Desktop aufräumen" };
                try
                {
                    progress?.Report($"Verschiebe {c.Item.FileName} …");
                    if (!File.Exists(src)) throw new IOException("Datei existiert nicht mehr.");
                    var attrs = File.GetAttributes(src);
                    if (!ProtectionService.IsCloudOnly(attrs) && ProtectionService.IsLocked(src))
                        throw new IOException("Datei ist geöffnet/gesperrt – übersprungen.");
                    e.Size = new FileInfo(src).Length;
                    if (!Directory.Exists(folder))
                    {
                        Directory.CreateDirectory(folder);
                        snap.CreatedFolders.Add(folder);
                        result.FoldersCreated++;
                    }
                    // Nichts überschreiben: Namen bei Bedarf neu vergeben (falls sich seit der Vorschau etwas geändert hat).
                    var dest = File.Exists(c.FinalPath) ? DesktopPlanner.UniquePath(folder, Path.GetFileName(src), reserved) : c.FinalPath;
                    File.Move(src, dest, overwrite: false);
                    snap.Moves.Add(new SnapshotMove { From = src, To = dest });
                    e.Success = true;
                    e.Error = $"→ {dest}";
                    result.Moved++;
                }
                catch (Exception ex)
                {
                    e.Success = false;
                    e.Error = ex.Message;
                    result.Problems.Add($"{c.Item.FileName}: {ex.Message}");
                }
                log.Add(e);
                DesktopHistory.Update(snap); // nach jeder Datei sichern – auch bei Absturz rückgängig machbar
            }
            _log.Append(log);
        });

        // 3) Symbole positionieren, sobald der Explorer die Änderungen anzeigt
        if (view != null)
        {
            progress?.Report("Ordne Symbole an …");
            var gone = snap.Moves.Select(m => m.From).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var appear = snap.CreatedFolders.ToHashSet(StringComparer.OrdinalIgnoreCase);
            await WaitForViewAsync(view, gone, appear);
            result.Positioned = view.Position(plan.Positions);
            _log.Append(new[]
            {
                new DeleteLogEntry
                {
                    Timestamp = DateTime.Now, Path = viewKind, Method = "Desktop: angeordnet", Category = "Desktop aufräumen",
                    Success = true, Error = $"{result.Positioned} Symbole neu angeordnet",
                },
            });
        }
        DesktopHistory.Update(snap);
        return (result, snap);
    }

    /// <summary>Stellt den Zustand vor der Aktion wieder her.</summary>
    public async Task<DesktopApplyResult> UndoAsync(DesktopShellView? view, DesktopSnapshot snap, IProgress<string>? progress = null)
    {
        var result = new DesktopApplyResult();
        var renamed = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        await Task.Run(() =>
        {
            var log = new List<DeleteLogEntry>();
            var reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var m in Enumerable.Reverse(snap.Moves))
            {
                var e = new DeleteLogEntry { Timestamp = DateTime.Now, Path = m.From, Method = "Desktop: zurückgeholt", Category = "Desktop aufräumen" };
                try
                {
                    progress?.Report($"Hole {Path.GetFileName(m.From)} zurück …");
                    if (!File.Exists(m.To)) throw new IOException($"Datei nicht mehr gefunden: {m.To}");
                    e.Size = new FileInfo(m.To).Length;
                    var dest = m.From;
                    if (File.Exists(dest) || Directory.Exists(dest))
                    {
                        dest = DesktopPlanner.UniquePath(Path.GetDirectoryName(m.From)!, Path.GetFileName(m.From), reserved);
                        renamed[m.From] = dest;
                    }
                    File.Move(m.To, dest, overwrite: false);
                    e.Success = true;
                    e.Error = dest == m.From ? $"← {m.To}" : $"← {m.To} (als „{Path.GetFileName(dest)}“, Name war belegt)";
                    result.Moved++;
                }
                catch (Exception ex)
                {
                    e.Success = false;
                    e.Error = ex.Message;
                    result.Problems.Add(ex.Message);
                }
                log.Add(e);
            }
            // Neu erstellte Ordner nur entfernen, wenn sie jetzt leer sind.
            foreach (var f in snap.CreatedFolders)
            {
                try
                {
                    if (Directory.Exists(f) && !Directory.EnumerateFileSystemEntries(f).Any())
                    {
                        Directory.Delete(f);
                        result.FoldersRemoved++;
                    }
                    else if (Directory.Exists(f))
                        result.Problems.Add($"Ordner „{Path.GetFileName(f)}“ ist nicht leer und bleibt bestehen.");
                }
                catch (Exception ex) { result.Problems.Add(ex.Message); }
            }
            _log.Append(log);
        });

        if (view != null && snap.Positions.Count > 0)
        {
            progress?.Report("Stelle Symbolpositionen wieder her …");
            var appear = snap.Moves.Select(m => renamed.TryGetValue(m.From, out var r) ? r : m.From).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var gone = snap.CreatedFolders.Where(f => !Directory.Exists(f)).ToHashSet(StringComparer.OrdinalIgnoreCase);
            await WaitForViewAsync(view, gone, appear);
            var targets = new Dictionary<string, POINT>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in snap.Positions)
                targets[renamed.TryGetValue(p.Path, out var r) ? r : p.Path] = new POINT(p.X, p.Y);
            result.Positioned = view.Position(targets);
        }

        snap.Undone = true;
        snap.UndoneDate = DateTime.Now;
        DesktopHistory.Update(snap);
        _log.Append(new[]
        {
            new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = snap.ViewKind, Method = "Desktop: rückgängig", Category = "Desktop aufräumen",
                Success = result.Problems.Count == 0, Error = $"{result.Moved} Dateien zurück, {result.Positioned} Positionen wiederhergestellt",
            },
        });
        return result;
    }

    /// <summary>Wartet, bis der Explorer verschobene Dateien entfernt und neue Ordner/Dateien anzeigt.</summary>
    private async Task WaitForViewAsync(DesktopShellView view, ISet<string> gone, ISet<string> appear)
    {
        var until = DateTime.Now + RefreshTimeout;
        while (DateTime.Now < until)
        {
            var paths = view.GetItems().Select(i => i.ParsingPath).ToHashSet(StringComparer.OrdinalIgnoreCase);
            if (!gone.Any(paths.Contains) && appear.All(paths.Contains)) break;
            await Task.Delay(200);
        }
        await Task.Delay(300); // Explorer kurz zur Ruhe kommen lassen
    }
}
