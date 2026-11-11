using PCAufraeumer.Interop;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Ein Symbol in der Vorher/Nachher-Ansicht.</summary>
public sealed class PreviewIcon
{
    public string Path { get; init; } = "";
    public string Name { get; init; } = "";
    public int X { get; init; }
    public int Y { get; init; }
    public bool IsNewFolder { get; init; }
    public bool Moved { get; init; }
    public string Group { get; init; } = "";
    public DesktopChange? Change { get; init; }
}

/// <summary>Eine Gruppe (Kategorie) in der Nachher-Ansicht – für Beschriftung und Drag &amp; Drop.</summary>
public sealed class PreviewGroup
{
    public string Name { get; init; } = "";
    public int X { get; init; }
    public int Y { get; init; }
    public int Width { get; init; }
    public int Height { get; init; }
    public bool IsCategory { get; init; }
}

public sealed class DesktopPlan
{
    public Dictionary<string, POINT> Positions { get; } = new(StringComparer.OrdinalIgnoreCase);
    public List<DesktopChange> Moves { get; } = new();
    public List<string> NewFolders { get; } = new();
    public List<PreviewIcon> After { get; } = new();
    public List<PreviewGroup> Groups { get; } = new();
    public List<string> Warnings { get; } = new();
}

/// <summary>
/// Erkennt Desktop-Elemente und berechnet den Plan (Gruppen-Anordnung + Zielordner).
/// Ändert selbst NICHTS – das macht erst DesktopApplier nach „Übernehmen“.
/// </summary>
public sealed class DesktopPlanner
{
    public const string FolderGroup = "Ordner";
    private static readonly HashSet<string> IconExt = new(StringComparer.OrdinalIgnoreCase) { ".lnk", ".url", ".website", ".appref-ms" };

    private readonly DesktopSettings _s;
    private readonly DesktopCategorizer _cat;
    public string UserDesktop { get; }
    public string? PublicDesktop { get; }

    public DesktopPlanner(DesktopSettings s, string userDesktop, string? publicDesktop)
    {
        _s = s;
        _cat = new DesktopCategorizer(s);
        UserDesktop = userDesktop;
        PublicDesktop = publicDesktop;
    }

    public DesktopCategorizer Categorizer => _cat;

    /// <summary>Wandelt die Shell-Liste in Desktop-Elemente um (Art, Quelle, Sperre, „nie anfassen“).</summary>
    public List<DesktopItem> Classify(IEnumerable<ShellViewItem> shellItems)
    {
        var list = new List<DesktopItem>();
        foreach (var s in shellItems)
        {
            var it = new DesktopItem { Path = s.ParsingPath, DisplayName = s.DisplayName, X = s.X, Y = s.Y };
            it.IsPublic = PublicDesktop != null && ProtectionService.IsUnder(s.ParsingPath, PublicDesktop);
            if (!s.IsFileSystem || s.ParsingPath.StartsWith("::") || s.ParsingPath.Length < 3) it.Kind = DesktopItemKind.System;
            else if (Directory.Exists(s.ParsingPath)) it.Kind = DesktopItemKind.Folder;
            else if (IconExt.Contains(Path.GetExtension(s.ParsingPath))) it.Kind = DesktopItemKind.AppIcon;
            else if (ShortcutResolver.IsAppLauncher(s.ParsingPath)) it.Kind = DesktopItemKind.AppIcon; // z. B. Firefox-Starter
            else it.Kind = DesktopItemKind.File;

            it.NeverTouch = _s.NeverTouch.Any(n =>
                string.Equals(n, it.DisplayName, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(n, it.FileName, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(n.TrimEnd('\\'), it.Path, StringComparison.OrdinalIgnoreCase));

            if (it.Kind == DesktopItemKind.File)
            {
                try
                {
                    var a = File.GetAttributes(it.Path);
                    // „Nur online“-Dateien nicht öffnen (würde sie herunterladen) → gelten als nicht gesperrt.
                    it.Locked = !ProtectionService.IsCloudOnly(a) && ProtectionService.IsLocked(it.Path);
                }
                catch { it.Locked = true; }
            }
            list.Add(it);
        }
        return list;
    }

    /// <summary>Setzt Kategorien für App-Symbole (Verknüpfungen werden aufgelöst – STA-Thread!).</summary>
    public void Categorize(IEnumerable<DesktopItem> items)
    {
        foreach (var it in items.Where(i => i.Kind == DesktopItemKind.AppIcon))
        {
            var info = ShortcutResolver.Resolve(it.Path);
            it.Target = info.Target;
            it.DetectedCategory = _cat.Categorize(it, info);
        }
    }

    public IReadOnlyList<string> ExistingFolderNames(IEnumerable<DesktopItem> items) =>
        items.Where(i => i.Kind == DesktopItemKind.Folder && !i.IsPublic).Select(i => i.FileName).OrderBy(n => n).ToList();

    /// <summary>Erstellt die Liste der geplanten Änderungen (Standardvorschläge).</summary>
    public List<DesktopChange> BuildChanges(List<DesktopItem> items, IReadOnlyList<ViewMonitor> monitors)
    {
        var changes = new List<DesktopChange>();
        var existing = ExistingFolderNames(items);
        var folderOptions = existing.Concat(_s.FolderRules.Select(r => r.Folder))
            .Where(n => !string.IsNullOrWhiteSpace(n)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var primary = monitors.FirstOrDefault(m => m.IsPrimary) ?? monitors.FirstOrDefault();

        foreach (var it in items)
        {
            if (it.Kind == DesktopItemKind.System || it.NeverTouch) continue;
            bool onOther = !_s.AllOnPrimary && primary != null && monitors.Count > 1 && !primary.Contains(it.X, it.Y);

            switch (it.Kind)
            {
                case DesktopItemKind.AppIcon:
                    changes.Add(new DesktopChange
                    {
                        Item = it, Kind = DesktopChangeKind.Position, Target = it.DetectedCategory,
                        Options = _s.Categories.ToList(), IsEnabled = !onOther,
                        Note = (it.IsPublic ? "Öffentlicher Desktop – wird nur neu angeordnet. " : "") +
                               (onOther ? "Liegt auf einem anderen Monitor – bleibt dort (einschaltbar)." : ""),
                    });
                    break;
                case DesktopItemKind.Folder:
                    changes.Add(new DesktopChange
                    {
                        Item = it, Kind = DesktopChangeKind.Position, Target = FolderGroup,
                        Options = new[] { FolderGroup }, IsEnabled = !onOther,
                        Note = onOther ? "Liegt auf einem anderen Monitor – bleibt dort (einschaltbar)." : "Wird nicht verändert, nur mit angeordnet.",
                    });
                    break;
                case DesktopItemKind.File:
                    if (it.IsPublic)
                    {
                        changes.Add(new DesktopChange
                        {
                            Item = it, Kind = DesktopChangeKind.MoveFile, Target = "", CanEnable = false, IsEnabled = false,
                            Note = "Liegt auf dem öffentlichen Desktop – wird nicht verschoben (bräuchte Adminrechte).",
                        });
                        break;
                    }
                    var rule = _cat.RuleForFile(it.FileName);
                    var match = existing.FirstOrDefault(e =>
                        string.Equals(e, rule.Folder, StringComparison.OrdinalIgnoreCase) ||
                        rule.AliasList().Any(a => string.Equals(a, e, StringComparison.OrdinalIgnoreCase)));
                    changes.Add(new DesktopChange
                    {
                        Item = it, Kind = DesktopChangeKind.MoveFile, Target = match ?? rule.Folder, Options = folderOptions,
                        CanEnable = !it.Locked, IsEnabled = !it.Locked,
                        Note = it.Locked ? "Datei ist geöffnet/gesperrt – wird übersprungen." : "",
                    });
                    break;
            }
        }
        return changes;
    }

    public static string SanitizeFolderName(string name)
    {
        var bad = Path.GetInvalidFileNameChars();
        var s = new string(name.Trim().Select(c => bad.Contains(c) ? '_' : c).ToArray()).Trim(' ', '.');
        return s.Length == 0 ? "Sonstiges" : s;
    }

    /// <summary>Freier Dateiname im Zielordner: „Bild.png“ → „Bild (2).png“ …</summary>
    public static string UniquePath(string folder, string fileName, ISet<string> reserved)
    {
        var baseName = Path.GetFileNameWithoutExtension(fileName);
        var ext = Path.GetExtension(fileName);
        var p = Path.Combine(folder, fileName);
        for (int n = 2; File.Exists(p) || Directory.Exists(p) || reserved.Contains(p); n++)
            p = Path.Combine(folder, $"{baseName} ({n}){ext}");
        reserved.Add(p);
        return p;
    }

    /// <summary>Berechnet Zielordner, Dateinamen und die neue Anordnung.</summary>
    public DesktopPlan Plan(List<DesktopItem> items, List<DesktopChange> changes, IReadOnlyList<ViewMonitor> monitors, POINT spacing,
        DesktopLayout? layout = null, FolderPlacement? folderPlacement = null)
    {
        var plan = new DesktopPlan();
        var reserved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var byItem = changes.ToDictionary(c => c.Item);

        // 1) Dateien → Ordner
        foreach (var c in changes.Where(c => c.Kind == DesktopChangeKind.MoveFile))
        {
            if (!c.IsEnabled)
            {
                c.FinalPath = "";
                c.Description = $"Datei „{c.Item.FileName}“ bleibt liegen";
                continue;
            }
            var folderName = SanitizeFolderName(c.Target);
            var folder = Path.Combine(UserDesktop, folderName);
            c.TargetIsNewFolder = !Directory.Exists(folder);
            if (c.TargetIsNewFolder && !plan.NewFolders.Contains(folder, StringComparer.OrdinalIgnoreCase)) plan.NewFolders.Add(folder);
            c.FinalPath = UniquePath(folder, c.Item.FileName, reserved);
            var finalName = Path.GetFileName(c.FinalPath);
            c.Description = $"Datei „{c.Item.FileName}“ → Ordner {folderName}{(c.TargetIsNewFolder ? " (neu)" : "")}" +
                            (finalName != c.Item.FileName ? $" – umbenannt zu „{finalName}“ (Name war schon vergeben)" : "");
            plan.Moves.Add(c);
        }

        // 2) Raster des Hauptmonitors
        var primary = monitors.FirstOrDefault(m => m.IsPrimary) ?? monitors.FirstOrDefault()
                      ?? new ViewMonitor { Width = 1920, Height = 1080, WorkWidth = 1920, WorkHeight = 1040, IsPrimary = true };
        int sx = Math.Max(40, spacing.X), sy = Math.Max(40, spacing.Y);
        var onPrimary = items.Where(i => i.Kind != DesktopItemKind.System && primary.Contains(i.X, i.Y)).ToList();
        int phaseX = onPrimary.Count > 0 ? Mod(onPrimary.Min(i => i.X) - primary.WorkLeft, sx) : 2;
        int phaseY = onPrimary.Count > 0 ? Mod(onPrimary.Min(i => i.Y) - primary.WorkTop, sy) : 2;
        int ox = primary.WorkLeft + phaseX, oy = primary.WorkTop + phaseY;
        int rows = Math.Max(1, (primary.WorkHeight - phaseY) / sy);
        int cols = Math.Max(1, (primary.WorkWidth - phaseX) / sx);

        // Feste Elemente (Systemsymbole, „nie anfassen“, abgewählte, gesperrte …) behalten ihren Platz.
        var placed = new List<(DesktopItem item, string group, DesktopChange? change)>();
        var fixedItems = new List<DesktopItem>();
        foreach (var it in items)
        {
            if (byItem.TryGetValue(it, out var c))
            {
                if (c.Kind == DesktopChangeKind.MoveFile) { if (!c.IsEnabled) fixedItems.Add(it); continue; }
                if (c.IsEnabled) { placed.Add((it, c.Target, c)); continue; }
            }
            fixedItems.Add(it);
        }
        var occupied = new HashSet<(int, int)>();
        foreach (var f in fixedItems.Where(f => primary.Contains(f.X, f.Y)))
            occupied.Add(((f.X - ox + sx / 2) / sx, (f.Y - oy + sy / 2) / sy));

        // Reihenfolge: Kategorien wie in den Einstellungen, danach Ordner (inkl. neuer Ordner).
        var order = _s.Categories.ToList();
        var groups = new List<(string name, List<(string path, string name, DesktopChange? change, bool isNew)> members)>();
        foreach (var cat in order)
        {
            var m = placed.Where(p => p.group != FolderGroup && string.Equals(p.group, cat, StringComparison.OrdinalIgnoreCase))
                .OrderBy(p => p.item.DisplayName, StringComparer.CurrentCultureIgnoreCase)
                .Select(p => (p.item.Path, p.item.DisplayName, p.change, false)).ToList();
            if (m.Count > 0) groups.Add((cat, m));
        }
        // Symbole mit unbekannter Kategorie (z. B. gelöschte Kategorie) → Sonstiges
        var unknown = placed.Where(p => p.group != FolderGroup && !order.Contains(p.group, StringComparer.OrdinalIgnoreCase)).ToList();
        if (unknown.Count > 0)
        {
            var fb = _cat.FallbackCategory;
            var g = groups.FirstOrDefault(x => x.name == fb);
            var add = unknown.Select(p => (p.item.Path, p.item.DisplayName, p.change, false)).ToList();
            if (g.members != null) g.members.AddRange(add); else groups.Add((fb, add));
        }
        var folders = placed.Where(p => p.group == FolderGroup)
            .Select(p => (p.item.Path, p.item.DisplayName, p.change, false))
            .Concat(plan.NewFolders.Select(f => (f, Path.GetFileName(f), (DesktopChange?)null, true)))
            .OrderBy(f => f.Item2, StringComparer.CurrentCultureIgnoreCase).ToList();
        if (folders.Count > 0) groups.Add((FolderGroup, folders));

        var style = layout ?? _s.Layout;
        var placement = folderPlacement ?? _s.FolderPlacement;
        // Eigene Ordner-Position gilt für alle Vorschläge außer „Mein Layout“ (dort bleibt alles an seinem Platz)
        bool customFolders = placement != FolderPlacement.WieVorschlag && style != DesktopLayout.Vorlage
                             && groups.Any(g => g.name == FolderGroup);
        int gap = Math.Max(0, _s.GapColumns);
        if (style == DesktopLayout.Spalten)
        {
            int needed = groups.Where(g => !customFolders || g.name != FolderGroup).Sum(g => (int)Math.Ceiling(g.members.Count / (double)rows)) + gap * Math.Max(0, groups.Count - 1);
            if (needed > cols && gap > 0)
            {
                gap = 0;
                plan.Warnings.Add("Nicht genug Platz für Abstände zwischen den Gruppen – Gruppen stehen direkt nebeneinander.");
            }
        }

        // Nächste freie Zelle aus einer gewünschten Reihenfolge holen (feste Elemente werden übersprungen).
        (int c, int r) Take(IEnumerator<(int c, int r)> cells)
        {
            while (cells.MoveNext())
                if (!occupied.Contains(cells.Current)) { occupied.Add(cells.Current); return cells.Current; }
            throw new InvalidOperationException("Kein Platz gefunden.");
        }
        IEnumerable<(int, int)> ColumnFlow(int col0)
        {
            for (int c = col0; c < col0 + 4000; c++) for (int r = 0; r < rows; r++) yield return (c, r);
        }
        IEnumerable<(int, int)> RowFlow(int row0)
        {
            for (int r = row0; r < row0 + 4000; r++) for (int c = 0; c < cols; c++) yield return (c, r);
        }
        IEnumerable<(int, int)> BlockFlow(int col0, int row0, int w)
        {
            for (int r = row0; r < row0 + 4000; r++) for (int c = col0; c < col0 + w; c++) yield return (c, r);
        }
        // Ordner an einer festen Stelle: z. B. unterste Reihe von links nach rechts, reicht sie nicht, die Reihe darüber.
        IEnumerable<(int, int)> FolderFlow(FolderPlacement p)
        {
            switch (p)
            {
                case FolderPlacement.UntenLinks:
                    for (int r = rows - 1; r >= 0; r--) for (int c = 0; c < cols; c++) yield return (c, r);
                    break;
                case FolderPlacement.UntenRechts:
                    for (int r = rows - 1; r >= 0; r--) for (int c = cols - 1; c >= 0; c--) yield return (c, r);
                    break;
                case FolderPlacement.RechterRand:
                    for (int c = cols - 1; c >= 0; c--) for (int r = 0; r < rows; r++) yield return (c, r);
                    break;
                case FolderPlacement.ObenRechts:
                    for (int r = 0; r < rows; r++) for (int c = cols - 1; c >= 0; c--) yield return (c, r);
                    break;
            }
            // Bildschirm voll: außerhalb weiter (wird als Warnung gemeldet)
            for (int c = cols; c < cols + 4000; c++) for (int r = 0; r < rows; r++) yield return (c, r);
        }

        var compact = ColumnFlow(0).GetEnumerator();
        int nextCol = 0, nextRow = 0, shelfRight = -1;
        bool overflow = false;
        if (style == DesktopLayout.Vorlage)
        {
            // „Eigenes Layout“: die jetzige Anordnung ist die Vorlage. Jedes Symbol bleibt auf seiner Rasterzelle,
            // aufgeräumt wird nur: Überlappungen lösen, Lücken verschobener Dateien schließen, neue Ordner zu den Ordnern.
            (int c, int r) CellOf(int x, int y) =>
                (Math.Clamp((int)Math.Round((x - ox) / (double)sx), 0, cols - 1), Math.Clamp((int)Math.Round((y - oy) / (double)sy), 0, rows - 1));
            (int c, int r) NearestFree((int c, int r) p)
            {
                for (int d = 0; d < cols + rows; d++)
                    for (int dc = -d; dc <= d; dc++)
                        for (int dr = -d; dr <= d; dr++)
                        {
                            if (Math.Max(Math.Abs(dc), Math.Abs(dr)) != d) continue;
                            var q = (p.c + dc, p.r + dr);
                            if (q.Item1 < 0 || q.Item2 < 0 || q.Item1 >= cols || q.Item2 >= rows) continue;
                            if (!occupied.Contains(q)) return q;
                        }
                overflow = true;
                return (cols, 0);
            }

            var cellOf = new Dictionary<string, (int c, int r)>(StringComparer.OrdinalIgnoreCase);
            var startCell = new Dictionary<string, (int c, int r)>(StringComparer.OrdinalIgnoreCase);
            var info = new Dictionary<string, (string name, DesktopChange? change, bool isNew)>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in placed.OrderBy(p => CellOf(p.item.X, p.item.Y).r).ThenBy(p => CellOf(p.item.X, p.item.Y).c))
            {
                var want = CellOf(p.item.X, p.item.Y);
                var got = NearestFree(want);
                occupied.Add(got);
                cellOf[p.item.Path] = got;
                startCell[p.item.Path] = want;
                info[p.item.Path] = (p.item.DisplayName, p.change, false);
            }

            // Lücken schließen, die verschobene Dateien hinterlassen: Symbole direkt darunter rücken nach oben.
            var holes = plan.Moves.Select(m => m.Item).Where(i => primary.Contains(i.X, i.Y))
                .Select(i => CellOf(i.X, i.Y)).Where(h => !occupied.Contains(h)).Distinct()
                .OrderBy(h => h.c).ThenBy(h => h.r).ToList();
            foreach (var hole in holes)
            {
                int cur = hole.r;
                while (!occupied.Contains((hole.c, cur)))
                {
                    var below = cellOf.FirstOrDefault(kv => kv.Value == (hole.c, cur + 1));
                    if (below.Key == null) break;
                    occupied.Remove((hole.c, cur + 1));
                    occupied.Add((hole.c, cur));
                    cellOf[below.Key] = (hole.c, cur);
                    cur++;
                }
            }

            // Neue Ordner neben die vorhandenen Ordner (sonst oben rechts).
            var folderCells = placed.Where(p => p.group == FolderGroup).Select(p => cellOf[p.item.Path]).ToList();
            (int c, int r) anchor = folderCells.Count > 0
                ? ((int)Math.Round(folderCells.Average(f => f.c)), folderCells.Max(f => f.r) + 1)
                : (cols - 1, 0);
            foreach (var f in plan.NewFolders.OrderBy(f => f, StringComparer.CurrentCultureIgnoreCase))
            {
                var got = NearestFree((Math.Clamp(anchor.c, 0, cols - 1), Math.Clamp(anchor.r, 0, rows - 1)));
                occupied.Add(got);
                cellOf[f] = got;
                info[f] = (Path.GetFileName(f), null, true);
            }

            foreach (var (path, cell) in cellOf)
            {
                var (name, change, isNew) = info[path];
                var pt = new POINT(ox + cell.c * sx, oy + cell.r * sy);
                plan.Positions[path] = pt;
                plan.After.Add(new PreviewIcon { Path = path, Name = name, X = pt.X, Y = pt.Y, IsNewFolder = isNew, Change = change });
                if (change != null)
                {
                    bool same = startCell.TryGetValue(path, out var s0) && s0 == cell &&
                                Math.Abs(change.Item.X - pt.X) <= sx / 4 && Math.Abs(change.Item.Y - pt.Y) <= sy / 4;
                    var what = change.Item.Kind == DesktopItemKind.Folder ? "Ordner" : "Symbol";
                    change.Description = same
                        ? $"{what} „{name}“ bleibt an seinem Platz"
                        : $"{what} „{name}“ → aufgeräumt (rückt ins Raster / in eine Lücke)";
                }
            }
        }

        // Eine Gruppe in die angebotenen Zellen legen und als Rahmen für die Vorschau merken.
        (int minC, int maxC, int minR, int maxR) PlaceGroup(string name, List<(string path, string name, DesktopChange? change, bool isNew)> members,
                                                            IEnumerator<(int c, int r)> cells)
        {
            int minC = int.MaxValue, maxC = int.MinValue, minR = int.MaxValue, maxR = int.MinValue;
            foreach (var mbr in members)
            {
                var (c, r) = Take(cells);
                minC = Math.Min(minC, c); maxC = Math.Max(maxC, c); minR = Math.Min(minR, r); maxR = Math.Max(maxR, r);
                if (c >= cols || r >= rows) overflow = true;
                var pt = new POINT(ox + c * sx, oy + r * sy);
                plan.Positions[mbr.path] = pt;
                plan.After.Add(new PreviewIcon
                {
                    Path = mbr.path, Name = mbr.name, X = pt.X, Y = pt.Y, IsNewFolder = mbr.isNew, Group = name, Change = mbr.change,
                });
                if (mbr.change != null)
                {
                    mbr.change.Description = mbr.change.Item.Kind == DesktopItemKind.Folder
                        ? $"Ordner „{mbr.name}“ → bei den Ordnern einsortiert"
                        : $"Symbol „{mbr.name}“ → Gruppe {name}";
                }
            }
            plan.Groups.Add(new PreviewGroup
            {
                Name = name, X = ox + minC * sx, Y = oy + minR * sy,
                Width = (maxC - minC + 1) * sx, Height = (maxR - minR + 1) * sy, IsCategory = name != FolderGroup,
            });
            return (minC, maxC, minR, maxR);
        }

        var flowGroups = style == DesktopLayout.Vorlage ? new() : groups;
        if (customFolders)
        {
            // Ordner zuerst an ihre feste Stelle – die App-Gruppen fließen danach um sie herum.
            var fg = groups.First(g => g.name == FolderGroup);
            PlaceGroup(FolderGroup, fg.members, FolderFlow(placement).GetEnumerator());
            flowGroups = groups.Where(g => g.name != FolderGroup).ToList();
        }

        foreach (var (name, members) in flowGroups)
        {
            int n = members.Count;
            IEnumerator<(int c, int r)> cells;
            switch (style)
            {
                case DesktopLayout.Kompakt:
                    cells = compact;
                    break;
                case DesktopLayout.Zeilen:
                    cells = RowFlow(nextRow).GetEnumerator();
                    break;
                case DesktopLayout.Bloecke:
                {
                    int h = Math.Min(rows, Math.Max(2, (int)Math.Ceiling(Math.Sqrt(n))));
                    int w = (int)Math.Ceiling(n / (double)h);
                    if (nextRow > 0 && nextRow + h > rows) { nextCol = shelfRight + 1 + gap; nextRow = 0; }
                    cells = BlockFlow(nextCol, nextRow, w).GetEnumerator();
                    break;
                }
                case DesktopLayout.Raender when name == FolderGroup:
                    cells = ColumnFlow(Math.Max(nextCol, cols - (int)Math.Ceiling(n / (double)rows))).GetEnumerator();
                    break;
                default: // Spalten, Ränder (Apps links)
                    cells = ColumnFlow(nextCol).GetEnumerator();
                    break;
            }

            var (_, maxC, _, maxR) = PlaceGroup(name, members, cells);

            switch (style)
            {
                case DesktopLayout.Zeilen: nextRow = maxR + 1 + Math.Min(1, gap); break;
                case DesktopLayout.Bloecke: shelfRight = Math.Max(shelfRight, maxC); nextRow = maxR + 2; break;
                case DesktopLayout.Kompakt: break;
                default: nextCol = maxC + 1 + gap; break;
            }
        }
        if (overflow) plan.Warnings.Add("Nicht alle Symbole passen auf den Hauptmonitor – einige liegen außerhalb des sichtbaren Bereichs. Probier einen anderen Vorschlag.");

        // Abgewählte Symbole: Beschreibung
        foreach (var c in changes.Where(c => c.Kind == DesktopChangeKind.Position && !c.IsEnabled))
            c.Description = $"{(c.Item.Kind == DesktopItemKind.Folder ? "Ordner" : "Symbol")} „{c.Item.DisplayName}“ bleibt, wo es ist";

        // Feste Elemente in die Nachher-Ansicht
        foreach (var f in fixedItems)
            plan.After.Add(new PreviewIcon { Path = f.Path, Name = f.DisplayName, X = f.X, Y = f.Y, Group = "" });
        return plan;
    }

    private static int Mod(int a, int m) => ((a % m) + m) % m;
}
