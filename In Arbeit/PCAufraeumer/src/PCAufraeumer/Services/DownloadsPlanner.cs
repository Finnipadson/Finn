using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// „Downloads aufräumen“: lose Dateien im Downloads-Ordner nach den Ordnerregeln in Unterordner sortieren.
/// Ändert selbst NICHTS – ausgeführt wird erst mit <see cref="DesktopApplier"/> nach „Übernehmen“ (mit Verlauf + Rückgängig).
/// </summary>
public sealed class DownloadsPlanner
{
    /// <summary>Laufende/unfertige Downloads – nie verschieben.</summary>
    public static readonly HashSet<string> PartialExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".crdownload", ".part", ".partial", ".download", ".tmp", ".opdownload", ".!ut", ".!qb", ".aria2", ".dtapart",
    };

    private readonly DesktopSettings _rules;
    private readonly DesktopCategorizer _cat;
    public string Folder { get; }

    public DownloadsPlanner(DesktopSettings rules, string folder)
    {
        _rules = rules;
        _cat = new DesktopCategorizer(rules);
        Folder = folder;
    }

    /// <summary>Dateien direkt im Ordner (Unterordner bleiben unberührt). Versteckte und Systemdateien (desktop.ini …) werden ausgelassen.</summary>
    public List<DesktopItem> ReadFiles()
    {
        var list = new List<DesktopItem>();
        foreach (var f in new DirectoryInfo(Folder).EnumerateFiles("*", new EnumerationOptions { IgnoreInaccessible = true, AttributesToSkip = 0 }))
        {
            try
            {
                var a = f.Attributes;
                if ((a & (FileAttributes.Hidden | FileAttributes.System)) != 0) continue;
                bool cloud = ProtectionService.IsCloudOnly(a);
                list.Add(new DesktopItem
                {
                    Path = f.FullName, DisplayName = f.Name, Kind = DesktopItemKind.File, Size = f.Length,
                    Modified = f.CreationTime > f.LastWriteTime ? f.CreationTime : f.LastWriteTime,
                    // „Nur online“-Dateien nicht öffnen (würde sie herunterladen) → gelten als nicht gesperrt.
                    Locked = !cloud && ProtectionService.IsLocked(f.FullName),
                });
            }
            catch { }
        }
        return list.OrderBy(i => i.DisplayName, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    public IReadOnlyList<string> ExistingFolderNames()
    {
        try
        {
            return Directory.EnumerateDirectories(Folder).Select(Path.GetFileName).Where(n => !string.IsNullOrEmpty(n))
                .Select(n => n!).OrderBy(n => n, StringComparer.CurrentCultureIgnoreCase).ToList();
        }
        catch { return Array.Empty<string>(); }
    }

    /// <summary>Vorschläge: jede Datei → passender Ordner (vorhandener Ordner gewinnt, auch über Alias-Namen).</summary>
    /// <param name="minAgeDays">Neuere Dateien bleiben (abgewählt) liegen; 0 = alle.</param>
    public List<DesktopChange> BuildChanges(IEnumerable<DesktopItem> files, int minAgeDays, DateTime now)
    {
        var existing = ExistingFolderNames();
        var options = existing.Concat(_rules.FolderRules.Select(r => r.Folder))
            .Where(n => !string.IsNullOrWhiteSpace(n)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var changes = new List<DesktopChange>();
        foreach (var it in files)
        {
            var ext = Path.GetExtension(it.FileName);
            if (PartialExtensions.Contains(ext))
            {
                changes.Add(new DesktopChange
                {
                    Item = it, Kind = DesktopChangeKind.MoveFile, CanEnable = false, IsEnabled = false, Options = options,
                    Note = "Download läuft noch oder ist unfertig – bleibt liegen.",
                });
                continue;
            }
            var rule = _cat.RuleForFile(it.FileName);
            var match = existing.FirstOrDefault(e =>
                string.Equals(e, rule.Folder, StringComparison.OrdinalIgnoreCase) ||
                rule.AliasList().Any(a => string.Equals(a, e, StringComparison.OrdinalIgnoreCase)));
            bool tooNew = minAgeDays > 0 && it.Modified is { } m && (now - m).TotalDays < minAgeDays;
            changes.Add(new DesktopChange
            {
                Item = it, Kind = DesktopChangeKind.MoveFile, Target = match ?? rule.Folder, Options = options,
                CanEnable = !it.Locked, IsEnabled = !it.Locked && !tooNew,
                Note = it.Locked ? "Datei ist geöffnet/gesperrt – wird übersprungen." :
                       tooNew ? (minAgeDays == 1 ? "Heute geladen – bleibt liegen (einschaltbar)." : $"Jünger als {minAgeDays} Tage – bleibt liegen (einschaltbar).") : "",
            });
        }
        return changes;
    }

    /// <summary>
    /// Doppelte Dateien unter den losen Dateien finden (gleiche Größe → gleicher Inhalts-Hash).
    /// Pro Gruppe bleibt die Datei ohne „_1“/„(1)“/„Kopie“ im Namen, sonst die älteste; die anderen werden markiert.
    /// Laufende Downloads, gesperrte und „Nur online“-Dateien werden nicht gelesen.
    /// </summary>
    public static int MarkDuplicates(IReadOnlyList<DesktopChange> changes, CancellationToken ct = default)
    {
        foreach (var c in changes) { c.DuplicateOf = ""; c.DuplicateKeepPath = ""; c.DuplicateGroup = 0; }
        var usable = changes.Where(c => c.Item.Size > 0 && !c.Item.Locked && c.CanEnable &&
                                        !PartialExtensions.Contains(Path.GetExtension(c.Item.FileName)) && !IsCloudOnly(c.Item.Path)).ToList();
        int group = 0, marked = 0;
        foreach (var bySize in usable.GroupBy(c => c.Item.Size).Where(g => g.Count() > 1))
        {
            var byHash = new Dictionary<UInt128, List<DesktopChange>>();
            foreach (var c in bySize)
            {
                ct.ThrowIfCancellationRequested();
                try
                {
                    var h = ProtectionService.PreserveAccessTime(c.Item.Path, () => ScanService.Hash(c.Item.Path, partial: false, ct));
                    if (!byHash.TryGetValue(h, out var l)) byHash[h] = l = new List<DesktopChange>();
                    l.Add(c);
                }
                catch (OperationCanceledException) { throw; }
                catch (Exception ex) { ErrorLog.Write($"Downloads: Datei nicht lesbar (Duplikatprüfung): {c.Item.Path}", ex); }
            }
            foreach (var members in byHash.Values.Where(l => l.Count > 1))
            {
                group++;
                var keep = members.OrderBy(m => CopyPenalty(m.Item.FileName))
                    .ThenBy(m => m.Item.Modified ?? DateTime.MaxValue)
                    .ThenBy(m => m.Item.FileName.Length).First();
                foreach (var m in members)
                {
                    m.DuplicateGroup = group;
                    if (ReferenceEquals(m, keep)) continue;
                    m.DuplicateOf = keep.Item.FileName;
                    m.DuplicateKeepPath = keep.Item.Path;
                    marked++;
                }
            }
        }
        return marked;
    }

    private static bool IsCloudOnly(string path)
    {
        try { return ProtectionService.IsCloudOnly(File.GetAttributes(path)); } catch { return true; }
    }

    /// <summary>Namen, die nach Kopie aussehen: „Datei (1).zip“, „Datei_1.zip“, „Datei - Kopie.zip“, „Copy of …“.</summary>
    internal static int CopyPenalty(string fileName)
    {
        var n = Path.GetFileNameWithoutExtension(fileName).ToLowerInvariant();
        int p = 0;
        if (System.Text.RegularExpressions.Regex.IsMatch(n, @"\(\d+\)$")) p += 3;
        if (System.Text.RegularExpressions.Regex.IsMatch(n, @"[_ ]\d$")) p += 2;
        if (n.Contains(" - kopie") || n.Contains(" - copy") || n.StartsWith("kopie von") || n.StartsWith("copy of")) p += 4;
        return p;
    }

    /// <summary>Zielordner und endgültige Dateinamen berechnen (nichts wird überschrieben).</summary>
    public DesktopPlan Plan(IEnumerable<DesktopChange> changes)
    {
        var plan = new DesktopPlan();
        var reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var c in changes)
        {
            if (!c.IsEnabled || !c.CanEnable)
            {
                c.FinalPath = "";
                c.Description = $"„{c.Item.FileName}“ bleibt liegen";
                continue;
            }
            var folderName = DesktopPlanner.SanitizeFolderName(c.Target);
            var folder = Path.Combine(Folder, folderName);
            c.TargetIsNewFolder = !Directory.Exists(folder);
            if (c.TargetIsNewFolder && !plan.NewFolders.Contains(folder, StringComparer.OrdinalIgnoreCase)) plan.NewFolders.Add(folder);
            c.FinalPath = DesktopPlanner.UniquePath(folder, c.Item.FileName, reserved);
            var finalName = Path.GetFileName(c.FinalPath);
            c.Description = $"→ Ordner {folderName}{(c.TargetIsNewFolder ? " (neu)" : "")}" +
                            (finalName != c.Item.FileName ? $" – umbenannt zu „{finalName}“ (Name war schon vergeben)" : "");
            plan.Moves.Add(c);
        }
        return plan;
    }
}
