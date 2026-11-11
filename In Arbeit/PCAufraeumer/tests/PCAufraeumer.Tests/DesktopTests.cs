using System.Diagnostics;
using System.Text.Json;
using PCAufraeumer.Interop;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using Xunit.Abstractions;

namespace PCAufraeumer.Tests;

/// <summary>
/// Tests für „Desktop aufräumen“ – ausschließlich in einem Testordner mit Dummy-Verknüpfungen und Dummy-Dateien.
/// Der echte Desktop wird hier nie verändert.
/// </summary>
[Collection("seq")]
public class DesktopTests : IDisposable
{
    private readonly TestFolder _t = new();
    private readonly ITestOutputHelper _out;
    public DesktopTests(ITestOutputHelper o) => _out = o;
    public void Dispose() => _t.Dispose();

    private static ShellViewItem SI(string path, int x = 0, int y = 0) => new()
    {
        ParsingPath = path, DisplayName = Path.GetFileNameWithoutExtension(path), IsFileSystem = true,
        IsFolder = Directory.Exists(path), X = x, Y = y,
    };

    private string Lnk(string name, string target, string args = "")
    {
        var p = Path.Combine(_t.Root, "Desk", name + ".lnk");
        Directory.CreateDirectory(Path.GetDirectoryName(p)!);
        StaTask.Run(() => { ShortcutResolver.CreateLnk(p, target, args); return 0; }).Wait();
        return p;
    }

    private string Url(string name, string url)
    {
        var p = Path.Combine(_t.Root, "Desk", name + ".url");
        Directory.CreateDirectory(Path.GetDirectoryName(p)!);
        File.WriteAllText(p, $"[InternetShortcut]\r\nURL={url}\r\n");
        return p;
    }

    private static readonly List<ViewMonitor> OneMonitor = new()
    {
        new ViewMonitor { Width = 1920, Height = 1080, WorkWidth = 1920, WorkHeight = 1040, IsPrimary = true },
    };

    [Fact]
    public async Task Shortcuts_are_categorized_and_overrides_win()
    {
        var s = new DesktopSettings();
        var items = new List<string>
        {
            Lnk("Chrome", @"C:\Program Files\Google\Chrome\Application\chrome.exe"),
            Lnk("Mein Spiel", @"D:\SteamLibrary\steamapps\common\MeinSpiel\game.exe"),
            Url("Hogwarts Legacy", "steam://rungameid/990080"),
            Url("Fortnite", "com.epicgames.launcher://apps/fn?action=launch"),
            Lnk("Discord", @"C:\Users\x\AppData\Local\Discord\Update.exe", "--processStart Discord.exe"),
            Lnk("Unbekannt", @"C:\Tools\irgendwas.exe"),
            Lnk("VS Code", @"C:\Users\x\AppData\Local\Programs\Microsoft VS Code\Code.exe"),
        };
        var planner = new DesktopPlanner(s, Path.Combine(_t.Root, "Desk"), null);
        var classified = await StaTask.Run(() =>
        {
            var c = planner.Classify(items.Select(p => SI(p)));
            planner.Categorize(c);
            return c;
        });
        string Cat(string n) => classified.First(i => i.DisplayName == n).DetectedCategory;
        Assert.All(classified, i => Assert.Equal(DesktopItemKind.AppIcon, i.Kind));
        Assert.Equal("Browser & Internet", Cat("Chrome"));
        Assert.Equal("Spiele", Cat("Mein Spiel"));
        Assert.Equal("Spiele", Cat("Hogwarts Legacy"));
        Assert.Equal("Spiele", Cat("Fortnite"));
        Assert.Equal("Kommunikation", Cat("Discord"));
        Assert.Equal("Sonstiges", Cat("Unbekannt"));
        Assert.Equal("Entwicklung", Cat("VS Code"));

        // Eigene Zuordnung (aus Drag & Drop) hat Vorrang
        s.IconOverrides["Unbekannt.lnk"] = "System & Tools";
        var again = await StaTask.Run(() => { var c = planner.Classify(new[] { SI(items[5]) }); planner.Categorize(c); return c; });
        Assert.Equal("System & Tools", again[0].DetectedCategory);
    }

    [Fact]
    public void Loose_files_get_sensible_folders_and_conflicts_are_renamed()
    {
        var desk = Path.Combine(_t.Root, "Desk");
        Directory.CreateDirectory(Path.Combine(desk, "Fotos"));             // vorhandener Ordner (Alias von „Bilder“)
        Directory.CreateDirectory(Path.Combine(desk, "Dokumente"));
        File.WriteAllText(Path.Combine(desk, "Dokumente", "Bericht.pdf"), "alt"); // Namenskonflikt
        var shot = _t.File(@"Desk\Screenshot 2026-11-10 120000.png", new byte[10]);
        var foto = _t.File(@"Desk\Urlaub.jpg", new byte[10]);
        var pdf = _t.File(@"Desk\Bericht.pdf", new byte[10]);
        var zip = _t.File(@"Desk\paket.zip", new byte[10]);
        var odd = _t.File(@"Desk\notiz.xyz", new byte[10]);
        var locked = _t.File(@"Desk\offen.docx", new byte[10]);
        var keep = _t.File(@"Desk\Wichtig.txt", new byte[10]);

        var s = new DesktopSettings { NeverTouch = { "Wichtig" } };
        var planner = new DesktopPlanner(s, desk, null);
        var paths = new[] { shot, foto, pdf, zip, odd, locked, keep, Path.Combine(desk, "Fotos"), Path.Combine(desk, "Dokumente") };
        List<DesktopItem> items;
        using (new FileStream(locked, FileMode.Open, FileAccess.Read, FileShare.None))
            items = planner.Classify(paths.Select(p => SI(p)));
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100));

        DesktopChange C(string p) => changes.First(c => c.Item.Path == p);
        Assert.Equal("Screenshots", C(shot).Target);
        Assert.Equal("Fotos", C(foto).Target);                // vorhandener Ordner wird genutzt
        Assert.Equal("Dokumente", C(pdf).Target);
        Assert.EndsWith(@"Dokumente\Bericht (2).pdf", C(pdf).FinalPath); // nichts überschreiben
        Assert.Contains("umbenannt", C(pdf).Description);
        Assert.Equal("Archive", C(zip).Target);
        Assert.Equal("Sonstiges", C(odd).Target);
        Assert.False(C(locked).IsEnabled);                     // gesperrt → übersprungen
        Assert.False(C(locked).CanEnable);
        Assert.DoesNotContain(changes, c => c.Item.Path == keep); // „nie anfassen“
        Assert.Contains(plan.NewFolders, f => f.EndsWith("Screenshots"));
        Assert.DoesNotContain(plan.NewFolders, f => f.EndsWith("Fotos"));
        Assert.Contains("(neu)", C(shot).Description);
    }

    [Fact]
    public void Layout_groups_categories_in_columns_and_avoids_fixed_items()
    {
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, _t.Root, null);
        var items = new List<DesktopItem>
        {
            new() { Path = "::{645FF040-5081-101B-9F08-00AA002F954E}", DisplayName = "Papierkorb", Kind = DesktopItemKind.System, X = 2, Y = 2 },
        };
        for (int i = 0; i < 12; i++) items.Add(new DesktopItem { Path = $@"C:\d\Spiel{i}.url", DisplayName = $"Spiel{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Spiele", X = 500 + i, Y = 500 });
        for (int i = 0; i < 3; i++) items.Add(new DesktopItem { Path = $@"C:\d\Browser{i}.lnk", DisplayName = $"Browser{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Browser & Internet", X = 900, Y = 500 });
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100));

        // 10 Zeilen à 100 px (Arbeitsbereich 1040 px). Papierkorb belegt Zelle (0,0).
        Assert.DoesNotContain(plan.Positions.Values, p => p.X == 2 && p.Y == 2);
        var games = plan.Positions.Where(p => p.Key.Contains("Spiel")).Select(p => p.Value).ToList();
        var browsers = plan.Positions.Where(p => p.Key.Contains("Browser")).Select(p => p.Value).ToList();
        Assert.Equal(12, games.Count);
        Assert.True(games.Max(g => g.X) < browsers.Min(b => b.X), "Browser-Gruppe muss rechts neben den Spielen stehen");
        Assert.True(browsers.Min(b => b.X) - games.Max(g => g.X) >= 200, "Eine Leerspalte zwischen den Gruppen");
        Assert.Equal(plan.Positions.Count, plan.Positions.Values.Select(p => (p.X, p.Y)).Distinct().Count()); // keine Überlappung
        Assert.Contains(plan.Groups, g => g.Name == "Spiele");
    }

    [Fact]
    public void Exe_launcher_on_desktop_is_app_icon_but_setup_stays_installer()
    {
        var desk = Path.Combine(_t.Root, "DeskL");
        Directory.CreateDirectory(desk);
        var setup = _t.File(@"DeskL\FirefoxSetup.exe", new byte[200]);   // keine Versionsinfo, „Setup“ im Namen
        Assert.False(ShortcutResolver.IsAppLauncher(setup));
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, desk, null);
        Assert.Equal(DesktopItemKind.File, planner.Classify(new[] { SI(setup) })[0].Kind);

        // Echter Firefox-Starter (desktop-launcher.exe), falls auf diesem PC vorhanden – nur eine Kopie wird geprüft.
        var real = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Firefox.exe");
        if (!File.Exists(real)) return;
        var copy = Path.Combine(desk, "Firefox.exe");
        File.Copy(real, copy, true);
        Assert.True(ShortcutResolver.IsAppLauncher(copy));
        var items = planner.Classify(new[] { SI(copy) });
        Assert.Equal(DesktopItemKind.AppIcon, items[0].Kind);
        planner.Categorize(items);
        Assert.Equal("Browser & Internet", items[0].DetectedCategory);     // Standardregel
        s.AppRules.Insert(0, new AppRule("Firefox", "Medien"));            // eigene Regel hat Vorrang
        planner.Categorize(items);
        Assert.Equal("Medien", items[0].DetectedCategory);
        var change = planner.BuildChanges(items, OneMonitor).Single();
        Assert.Equal(DesktopChangeKind.Position, change.Kind);              // wird nur angeordnet, nie verschoben
    }

    [Theory]
    [InlineData(DesktopLayout.Spalten, FolderPlacement.UntenLinks)]
    [InlineData(DesktopLayout.Zeilen, FolderPlacement.UntenLinks)]
    [InlineData(DesktopLayout.Bloecke, FolderPlacement.UntenRechts)]
    [InlineData(DesktopLayout.Kompakt, FolderPlacement.RechterRand)]
    [InlineData(DesktopLayout.Raender, FolderPlacement.ObenRechts)]
    public void Folder_placement_puts_folders_at_chosen_edge(DesktopLayout layout, FolderPlacement placement)
    {
        var desk = Path.Combine(_t.Root, "DeskF");
        foreach (var n in new[] { "Alpha", "Beta", "Gamma" }) Directory.CreateDirectory(Path.Combine(desk, n));
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, desk, null);
        var items = new List<DesktopItem>
        {
            new() { Path = "::{645FF040-5081-101B-9F08-00AA002F954E}", DisplayName = "Papierkorb", Kind = DesktopItemKind.System, X = 2, Y = 2 },
        };
        foreach (var n in new[] { "Gamma", "Alpha", "Beta" })
            items.Add(new DesktopItem { Path = Path.Combine(desk, n), DisplayName = n, Kind = DesktopItemKind.Folder, X = 700, Y = 700 });
        for (int i = 0; i < 25; i++) items.Add(new DesktopItem { Path = $@"C:\d\Spiel{i}.url", DisplayName = $"Spiel{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Spiele", X = 500, Y = 500 });
        for (int i = 0; i < 4; i++) items.Add(new DesktopItem { Path = $@"C:\d\Tool{i}.lnk", DisplayName = $"Tool{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "System & Tools", X = 900, Y = 600 });
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100), layout, placement);

        Assert.Equal(32, plan.Positions.Count);
        Assert.Equal(32, plan.Positions.Values.Select(p => (p.X, p.Y)).Distinct().Count()); // keine Überlappung
        Assert.All(plan.Positions.Values, p => Assert.True(p.X < 1920 && p.Y < 1040, $"{p.X},{p.Y} außerhalb"));
        Assert.Empty(plan.Warnings);

        var f = new[] { "Alpha", "Beta", "Gamma" }.Select(n => plan.Positions[Path.Combine(desk, n)]).ToList();
        // Raster: 100 px ab 0/0 (Systemsymbole zählen nicht), 10 Reihen (y bis 900), 19 Spalten (x bis 1800)
        switch (placement)
        {
            case FolderPlacement.UntenLinks:   // unterste Reihe, von links nach rechts in Namensreihenfolge
                Assert.All(f, p => Assert.Equal(900, p.Y));
                Assert.Equal(new[] { 0, 100, 200 }, f.Select(p => p.X));
                break;
            case FolderPlacement.UntenRechts:
                Assert.All(f, p => Assert.Equal(900, p.Y));
                Assert.Equal(new[] { 1800, 1700, 1600 }, f.Select(p => p.X));
                break;
            case FolderPlacement.RechterRand:
                Assert.All(f, p => Assert.Equal(1800, p.X));
                Assert.Equal(new[] { 0, 100, 200 }, f.Select(p => p.Y));
                break;
            case FolderPlacement.ObenRechts:
                Assert.All(f, p => Assert.Equal(0, p.Y));
                Assert.Equal(new[] { 1800, 1700, 1600 }, f.Select(p => p.X));
                break;
        }
        Assert.Contains(plan.Groups, g => g.Name == DesktopPlanner.FolderGroup && !g.IsCategory);
    }

    [Theory]
    [InlineData(DesktopLayout.Spalten)]
    [InlineData(DesktopLayout.Kompakt)]
    [InlineData(DesktopLayout.Zeilen)]
    [InlineData(DesktopLayout.Bloecke)]
    [InlineData(DesktopLayout.Raender)]
    [InlineData(DesktopLayout.Vorlage)]
    public void Every_layout_places_all_icons_without_overlap(DesktopLayout layout)
    {
        var desk = Path.Combine(_t.Root, "Desk");
        Directory.CreateDirectory(Path.Combine(desk, "Projekte"));
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, desk, null);
        var items = new List<DesktopItem>
        {
            new() { Path = "::{645FF040-5081-101B-9F08-00AA002F954E}", DisplayName = "Papierkorb", Kind = DesktopItemKind.System, X = 2, Y = 2 },
            new() { Path = Path.Combine(desk, "Projekte"), DisplayName = "Projekte", Kind = DesktopItemKind.Folder, X = 700, Y = 700 },
        };
        for (int i = 0; i < 14; i++) items.Add(new DesktopItem { Path = $@"C:\d\Spiel{i}.url", DisplayName = $"Spiel{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Spiele", X = 500, Y = 500 });
        for (int i = 0; i < 4; i++) items.Add(new DesktopItem { Path = $@"C:\d\Browser{i}.lnk", DisplayName = $"Browser{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Browser & Internet", X = 900, Y = 500 });
        for (int i = 0; i < 3; i++) items.Add(new DesktopItem { Path = $@"C:\d\Tool{i}.lnk", DisplayName = $"Tool{i}", Kind = DesktopItemKind.AppIcon, DetectedCategory = "System & Tools", X = 900, Y = 600 });
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100), layout);

        Assert.Equal(22, plan.Positions.Count);                                        // alle Apps + Ordner
        Assert.Equal(22, plan.Positions.Values.Select(p => (p.X, p.Y)).Distinct().Count()); // keine Überlappung
        Assert.DoesNotContain(plan.Positions.Values, p => p.X == 2 && p.Y == 2);        // Papierkorb-Platz frei
        Assert.All(plan.Positions.Values, p => Assert.True(p.X < 1920 && p.Y < 1040, $"{layout}: {p.X},{p.Y} außerhalb"));
        Assert.Empty(plan.Warnings);

        var games = plan.Positions.Where(p => p.Key.Contains("Spiel")).Select(p => p.Value).ToList();
        var browsers = plan.Positions.Where(p => p.Key.Contains("Browser")).Select(p => p.Value).ToList();
        var folder = plan.Positions[Path.Combine(desk, "Projekte")];
        switch (layout)
        {
            case DesktopLayout.Spalten:
                Assert.True(browsers.Min(b => b.X) - games.Max(g => g.X) >= 200); // Leerspalte
                break;
            case DesktopLayout.Kompakt:
                Assert.True(plan.Positions.Values.Max(p => p.X) <= 300);             // alles in den ersten Spalten
                break;
            case DesktopLayout.Zeilen:
                Assert.True(browsers.Min(b => b.Y) > games.Max(g => g.Y));            // Browser-Reihe unter den Spielen
                Assert.Single(games.Select(g => g.Y).Distinct());                     // alle Spiele in einer Reihe
                break;
            case DesktopLayout.Bloecke:
                Assert.True(games.Select(g => g.X).Distinct().Count() >= 3);          // fast quadratischer Block
                break;
            case DesktopLayout.Raender:
                Assert.True(folder.X >= 1700, "Ordner gehören an den rechten Rand");
                Assert.True(games.Max(g => g.X) < 500);
                break;
        }
    }

    [Fact]
    public void My_layout_keeps_positions_and_only_tidies_up()
    {
        var desk = Path.Combine(_t.Root, "Desk");
        Directory.CreateDirectory(Path.Combine(desk, "Projekte"));
        var shot = _t.File(@"Desk\Screenshot 1.png", new byte[1]);
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, desk, null);
        // Raster 100x100, Ursprung (2,2). Eigene Anordnung: eine Spalte bei x=302 mit einer Datei in der Mitte.
        var items = new List<DesktopItem>
        {
            new() { Path = "::{645FF040-5081-101B-9F08-00AA002F954E}", DisplayName = "Papierkorb", Kind = DesktopItemKind.System, X = 2, Y = 2 },
            new() { Path = @"C:\d\A.lnk", DisplayName = "A", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Spiele", X = 302, Y = 2 },
            new() { Path = shot, DisplayName = "Screenshot 1", Kind = DesktopItemKind.File, X = 302, Y = 102 },
            new() { Path = @"C:\d\B.lnk", DisplayName = "B", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Spiele", X = 302, Y = 202 },
            new() { Path = @"C:\d\C.lnk", DisplayName = "C", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Browser & Internet", X = 302, Y = 302 },
            new() { Path = @"C:\d\D.lnk", DisplayName = "D", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Medien", X = 902, Y = 502 },
            new() { Path = @"C:\d\E.lnk", DisplayName = "E", Kind = DesktopItemKind.AppIcon, DetectedCategory = "Medien", X = 905, Y = 498 }, // liegt fast auf D
            new() { Path = Path.Combine(desk, "Projekte"), DisplayName = "Projekte", Kind = DesktopItemKind.Folder, X = 1702, Y = 2 },
        };
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100), DesktopLayout.Vorlage);
        POINT P(string p) => plan.Positions[p];

        Assert.Equal(new POINT(302, 2), P(@"C:\d\A.lnk"));        // bleibt
        Assert.Equal(new POINT(302, 102), P(@"C:\d\B.lnk"));      // rückt in die Lücke der verschobenen Datei
        Assert.Equal(new POINT(302, 202), P(@"C:\d\C.lnk"));      // rückt mit nach
        Assert.Equal(new POINT(902, 502), P(@"C:\d\D.lnk"));      // bleibt
        Assert.NotEqual(P(@"C:\d\D.lnk"), P(@"C:\d\E.lnk"));      // Überlappung gelöst
        Assert.True(Math.Abs(P(@"C:\d\E.lnk").X - 902) <= 100 && Math.Abs(P(@"C:\d\E.lnk").Y - 502) <= 100); // direkt daneben
        Assert.Equal(new POINT(1702, 2), P(Path.Combine(desk, "Projekte")));
        var newFolder = P(Path.Combine(desk, "Screenshots"));     // neuer Ordner bei den Ordnern
        Assert.True(Math.Abs(newFolder.X - 1702) <= 100 && newFolder.Y <= 202, $"{newFolder.X},{newFolder.Y}");
        Assert.Empty(plan.Groups);                                 // keine Kategorie-Gruppen in diesem Modus
        Assert.Contains("bleibt an seinem Platz", changes.First(c => c.Item.Path == @"C:\d\A.lnk").Description);
    }

    [Fact]
    public async Task Apply_moves_files_and_undo_restores_everything()
    {
        AppPaths.OverrideBaseDir(Path.Combine(_t.Root, "_appdata"));
        var desk = Path.Combine(_t.Root, "Desk");
        Directory.CreateDirectory(Path.Combine(desk, "Bilder"));
        var a = _t.File(@"Desk\foto.jpg", new byte[] { 1, 2, 3 });
        var b = _t.File(@"Desk\Screenshot 1.png", new byte[] { 4 });
        var c = _t.File(@"Desk\liste.csv", new byte[] { 5 });
        var lnk = Lnk("Steam", @"C:\Program Files (x86)\Steam\steam.exe");
        var s = new DesktopSettings();
        var planner = new DesktopPlanner(s, desk, null);
        var items = planner.Classify(new[] { a, b, c, lnk, Path.Combine(desk, "Bilder") }.Select(p => SI(p)));
        var changes = planner.BuildChanges(items, OneMonitor);
        var plan = planner.Plan(items, changes, OneMonitor, new POINT(100, 100));

        var log = new DeleteLogService();
        var applier = new DesktopApplier(log);
        var (res, snap) = await applier.ApplyAsync(null, plan, desk);

        Assert.Equal(3, res.Moved);
        Assert.True(File.Exists(Path.Combine(desk, "Bilder", "foto.jpg")));
        Assert.True(File.Exists(Path.Combine(desk, "Screenshots", "Screenshot 1.png")));
        Assert.True(File.Exists(Path.Combine(desk, "Dokumente", "liste.csv")));
        Assert.False(File.Exists(a));
        Assert.True(File.Exists(lnk)); // Verknüpfungen werden nie verschoben
        Assert.Equal(2, snap.CreatedFolders.Count);
        Assert.Single(DesktopHistory.Load());

        // Inzwischen landet eine neue Datei im neuen Ordner „Dokumente“ → der Ordner darf beim Rückgängig nicht verschwinden
        File.WriteAllText(Path.Combine(desk, "Dokumente", "neu.txt"), "x");
        // und am alten Platz liegt inzwischen eine andere Datei gleichen Namens
        File.WriteAllText(a, "andere");

        var undo = await applier.UndoAsync(null, snap);
        Assert.Equal(3, undo.Moved);
        Assert.True(File.Exists(b));
        Assert.True(File.Exists(c));
        Assert.True(File.Exists(Path.Combine(desk, "foto (2).jpg")));        // nichts überschrieben
        Assert.Equal("andere", File.ReadAllText(a));
        Assert.False(Directory.Exists(Path.Combine(desk, "Screenshots")));  // neu + leer → entfernt
        Assert.True(Directory.Exists(Path.Combine(desk, "Dokumente")));     // neu, aber nicht leer → bleibt
        Assert.True(Directory.Exists(Path.Combine(desk, "Bilder")));        // war schon da → bleibt
        Assert.True(DesktopHistory.Load()[0].Undone);
        var entries = log.ReadAll();
        Assert.Contains(entries, e => e.Method == "Desktop: verschoben" && e.Success);
        Assert.Contains(entries, e => e.Method == "Desktop: zurückgeholt" && e.Success);
        Assert.Contains(entries, e => e.Method == "Desktop: rückgängig");
    }

    [Fact]
    public void History_keeps_at_least_ten_entries_and_prunes_old_ones()
    {
        AppPaths.OverrideBaseDir(Path.Combine(_t.Root, "_appdata"));
        for (int i = 0; i < 25; i++)
            DesktopHistory.Save(new DesktopSnapshot { Date = new DateTime(2026, 1, 1).AddMinutes(i), Description = $"#{i}" });
        var h = DesktopHistory.Load();
        Assert.Equal(DesktopHistory.Keep, h.Count);
        Assert.True(h.Count >= 10);
        Assert.Equal("#24", h[0].Description); // neueste zuerst
    }

    [Fact]
    public void Old_settings_file_without_desktop_section_still_loads()
    {
        const string old = "{\"ScanFolders\":[\"C:\\\\X\"],\"VideoAgeDays\":200,\"DarkMode\":false}";
        var s = JsonSerializer.Deserialize<AppSettings>(old, Json.Options)!;
        Assert.Equal(200, s.VideoAgeDays);
        Assert.False(s.DarkMode);
        Assert.Contains("Spiele", s.Desktop.Categories);
        Assert.NotEmpty(s.Desktop.AppRules);
        Assert.NotEmpty(s.Desktop.FolderRules);
        // und Rundreise mit Desktop-Teil
        s.Desktop.Categories.Add("Test");
        var again = JsonSerializer.Deserialize<AppSettings>(JsonSerializer.Serialize(s, Json.Options), Json.Options)!;
        Assert.Contains("Test", again.Desktop.Categories);
        Assert.Equal(again.Desktop.Categories.Count, again.Desktop.Categories.Distinct().Count()); // keine Verdopplung
    }

    /// <summary>
    /// Echtes Positionieren über die Shell-Schnittstelle – in einem Explorer-Fenster mit dem Testordner,
    /// NICHT auf dem echten Desktop. Prüft Anordnen und Rückgängig.
    /// </summary>
    [Fact]
    public async Task Positions_are_set_and_restored_in_test_explorer_window()
    {
        AppPaths.OverrideBaseDir(Path.Combine(_t.Root, "_appdata"));
        var desk = Path.Combine(_t.Root, "Desk");
        Directory.CreateDirectory(desk);
        Lnk("Chrome", @"C:\Program Files\Google\Chrome\Application\chrome.exe");
        Lnk("Discord", @"C:\Users\x\AppData\Local\Discord\Update.exe");
        Url("Hogwarts Legacy", "steam://rungameid/990080");
        Url("Fortnite", "com.epicgames.launcher://apps/fn");
        Lnk("Unbekannt", @"C:\Tools\x.exe");
        _t.File(@"Desk\Screenshot 5.png", new byte[] { 1 });

        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{desk}\"") { UseShellExecute = true });
        var log = await StaTask.Run(() => RunInExplorer(desk));
        _out.WriteLine(log);
        Assert.DoesNotContain("FEHLER", log);
    }

    /// <summary>
    /// Positionstest auf dem ECHTEN Desktop – läuft nur mit PCA_REAL_DESKTOP_TEST=1.
    /// Bewegt ausschließlich die Verknüpfung „PC Aufräumer“ um ein freies Feld und stellt danach
    /// alle Positionen aus dem Schnappschuss wieder her. Keine Datei wird verschoben.
    /// </summary>
    [Fact]
    public async Task Real_desktop_single_icon_position_and_restore()
    {
        if (Environment.GetEnvironmentVariable("PCA_REAL_DESKTOP_TEST") != "1") return;
        AppPaths.OverrideBaseDir(Path.Combine(_t.Root, "_appdata"));
        var log = await StaTask.Run(() =>
        {
            var sb = new System.Text.StringBuilder();
            using var view = DesktopShellView.OpenDesktop();
            var before = view.GetItems();
            var me = before.FirstOrDefault(i => i.DisplayName == "PC Aufräumer" && i.ParsingPath.EndsWith(".lnk"));
            if (me == null) return "FEHLER: Verknüpfung „PC Aufräumer“ nicht gefunden";
            var sp = view.Spacing;
            // freies Feld rechts neben der Verknüpfung suchen
            var target = new POINT(me.X + sp.X, me.Y);
            for (int k = 1; k < 30 && before.Any(i => Math.Abs(i.X - target.X) < sp.X / 2 && Math.Abs(i.Y - target.Y) < sp.Y / 2); k++)
                target = new POINT(me.X + sp.X * (k + 1), me.Y);
            sb.AppendLine($"vorher {me.X},{me.Y} → Ziel {target.X},{target.Y}");

            var snap = new DesktopSnapshot { Positions = before.Select(i => new SnapshotPosition { Path = i.ParsingPath, X = i.X, Y = i.Y }).ToList() };
            view.Position(new Dictionary<string, POINT>(StringComparer.OrdinalIgnoreCase) { [me.ParsingPath] = target });
            Thread.Sleep(500);
            var moved = view.GetItems().First(i => i.ParsingPath == me.ParsingPath);
            sb.AppendLine($"nachher {moved.X},{moved.Y}");
            if (Math.Abs(moved.X - target.X) > 4 || Math.Abs(moved.Y - target.Y) > 4) sb.AppendLine("FEHLER: Position nicht übernommen");

            var applier = new DesktopApplier(new DeleteLogService()) { RefreshTimeout = TimeSpan.FromSeconds(1) };
            Pump(() => applier.UndoAsync(view, snap));
            Thread.Sleep(500);
            var after = view.GetItems();
            int same = before.Count(b => after.Any(a => a.ParsingPath == b.ParsingPath && a.X == b.X && a.Y == b.Y));
            sb.AppendLine($"wiederhergestellt: {same}/{before.Count}");
            if (same != before.Count) sb.AppendLine("FEHLER: nicht alle Positionen wiederhergestellt");
            return sb.ToString();
        });
        _out.WriteLine(log);
        Assert.DoesNotContain("FEHLER", log);
    }

    private static T Pump<T>(Func<Task<T>> func)
    {
        var d = System.Windows.Threading.Dispatcher.CurrentDispatcher;
        SynchronizationContext.SetSynchronizationContext(new System.Windows.Threading.DispatcherSynchronizationContext(d));
        var task = func();
        var frame = new System.Windows.Threading.DispatcherFrame();
        task.ContinueWith(_ => frame.Continue = false, TaskScheduler.Default);
        System.Windows.Threading.Dispatcher.PushFrame(frame);
        return task.GetAwaiter().GetResult();
    }

    private string RunInExplorer(string desk)
    {
        var sb = new System.Text.StringBuilder();
        DesktopShellView? view = null;
        for (int i = 0; i < 40 && view == null; i++) { Thread.Sleep(250); view = DesktopShellView.OpenExplorerWindow(desk); }
        if (view == null) return "FEHLER: Explorer-Fenster nicht gefunden";
        using (view)
        {
            view.UseIconView();
            Thread.Sleep(500);
            view.AutoArrange = false;
            Thread.Sleep(300);
            sb.AppendLine($"AutoArrange nach Ausschalten: {view.AutoArrange}, Spacing {view.Spacing.X}x{view.Spacing.Y}, ViewMode {view.ViewMode}");
            if (view.AutoArrange)
            {
                sb.AppendLine("HINWEIS: Explorer-Ordnerfenster ordnen unter Windows 11 immer automatisch an – Positionstest nur eingeschränkt möglich.");
            }
            var before = view.GetItems();
            foreach (var i in before) sb.AppendLine($"vorher {i.X},{i.Y} {i.DisplayName}");
            if (before.All(i => i.X == 0 && i.Y == 0))
            {
                // Windows 11: Ordnerfenster ordnen immer automatisch an → hier nur Verschieben/Rückgängig der Dateien prüfen.
                sb.AppendLine("HINWEIS: Dieses Explorer-Fenster unterstützt keine freien Positionen – Positionen werden nur auf dem echten Desktop geprüft.");
                view.AutoArrange = true; // wirkt hier ohnehin nicht – nur für die Prüfungen unten
            }

            var s = new DesktopSettings();
            var planner = new DesktopPlanner(s, desk, null);
            var items = planner.Classify(before);
            planner.Categorize(items);
            var mons = view.GetMonitors();
            var changes = planner.BuildChanges(items, mons);
            var plan = planner.Plan(items, changes, mons, view.Spacing);
            var applier = new DesktopApplier(new DeleteLogService());
            // Wie in der App: Fortsetzungen laufen auf diesem STA-Thread (Dispatcher), damit die Shell-Objekte gültig bleiben.
            var (res, snap) = Pump(() => applier.ApplyAsync(view, plan, desk));
            Thread.Sleep(800);
            var after = view.GetItems();
            foreach (var i in after) sb.AppendLine($"nachher {i.X},{i.Y} {i.DisplayName}");
            sb.AppendLine($"positioniert: {res.Positioned}, verschoben: {res.Moved}");
            if (res.Moved != 1) sb.AppendLine("FEHLER: Screenshot wurde nicht verschoben");

            bool positionsSupported = !before.All(i => i.X == 0 && i.Y == 0);
            if (positionsSupported)
            {
                int ok = plan.Positions.Count(p => after.Any(a => string.Equals(a.ParsingPath, p.Key, StringComparison.OrdinalIgnoreCase)
                                                                   && Math.Abs(a.X - p.Value.X) <= 4 && Math.Abs(a.Y - p.Value.Y) <= 4));
                sb.AppendLine($"Positionen wie geplant: {ok}/{plan.Positions.Count}");
                if (ok < plan.Positions.Count) sb.AppendLine("FEHLER: Positionen weichen ab");
            }

            var undo = Pump(() => applier.UndoAsync(view, snap));
            Thread.Sleep(800);
            var restored = view.GetItems();
            foreach (var i in restored) sb.AppendLine($"zurück {i.X},{i.Y} {i.DisplayName}");
            if (!File.Exists(Path.Combine(desk, "Screenshot 5.png"))) sb.AppendLine("FEHLER: Datei nicht zurück");
            if (Directory.Exists(Path.Combine(desk, "Screenshots"))) sb.AppendLine("FEHLER: leerer neuer Ordner nicht entfernt");
            if (positionsSupported)
            {
                int same = before.Count(b => restored.Any(r => r.ParsingPath == b.ParsingPath && Math.Abs(r.X - b.X) <= 4 && Math.Abs(r.Y - b.Y) <= 4));
                sb.AppendLine($"Positionen wiederhergestellt: {same}/{before.Count}");
                if (same < before.Count) sb.AppendLine("FEHLER: Positionen nicht wiederhergestellt");
            }
        }
        // Explorer-Fenster wieder schließen
        try
        {
            dynamic sw = Activator.CreateInstance(Type.GetTypeFromCLSID(ShellNative.CLSID_ShellWindows)!)!;
            for (int i = sw.Count - 1; i >= 0; i--)
            {
                try
                {
                    dynamic w = sw.Item(i);
                    string p = w.Document.Folder.Self.Path;
                    if (string.Equals(p.TrimEnd('\\'), desk.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) w.Quit();
                }
                catch { }
            }
        }
        catch { }
        return sb.ToString();
    }
}
