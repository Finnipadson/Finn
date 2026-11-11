using System.Diagnostics;
using System.Windows;
using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.Tests;

/// <summary>Speicherplatz-Karte, Programm-Updates (winget-Ausgabe) und Downloads aufräumen – nur im Testordner.</summary>
[Collection("seq")]
public class StorageUpdatesDownloadsTests : IDisposable
{
    private readonly TestFolder _t = new();
    public void Dispose() => _t.Dispose();

    // ───── Kachel-Aufteilung ─────

    [Fact]
    public void Treemap_areas_are_proportional_inside_bounds_and_do_not_overlap()
    {
        var values = new double[] { 500, 300, 120, 80, 50, 30, 10, 5, 3, 2 };
        var bounds = new Rect(10, 20, 800, 500);
        var res = TreemapLayout.Compute(values, v => v, bounds);
        Assert.Equal(values.Length, res.Count);
        double total = values.Sum();
        foreach (var (v, r) in res)
        {
            Assert.InRange(r.Width * r.Height, v / total * 400000 * 0.98, v / total * 400000 * 1.02);
            Assert.True(r.Left >= bounds.Left - 0.01 && r.Top >= bounds.Top - 0.01 && r.Right <= bounds.Right + 0.01 && r.Bottom <= bounds.Bottom + 0.01);
        }
        for (int i = 0; i < res.Count; i++)
            for (int j = i + 1; j < res.Count; j++)
            {
                var a = res[i].Rect; a.Intersect(res[j].Rect);
                Assert.True(a.IsEmpty || a.Width * a.Height < 0.5, $"Kacheln {i} und {j} überlappen");
            }
        Assert.InRange(res.Sum(x => x.Rect.Width * x.Rect.Height), 400000 * 0.99, 400000 * 1.01);
    }

    [Fact]
    public void Treemap_ignores_zero_sizes_and_empty_input()
    {
        Assert.Empty(TreemapLayout.Compute(Array.Empty<double>(), v => v, new Rect(0, 0, 100, 100)));
        var res = TreemapLayout.Compute(new double[] { 0, 10, 0 }, v => v, new Rect(0, 0, 100, 50));
        Assert.Single(res);
        Assert.Equal(new Rect(0, 0, 100, 50), res[0].Rect);
    }

    // ───── Speicherplatz-Scan ─────

    [Fact]
    public void DiskMap_sums_sizes_bundles_small_files_and_skips_junctions()
    {
        var root = Path.Combine(_t.Root, "karte");
        _t.File("karte/Videos/gross.bin", new byte[300_000]);
        _t.File("karte/Videos/Unter/mittel.bin", new byte[100_000]);
        for (int i = 0; i < DiskMapService.FilesPerFolder + 10; i++) _t.File($"karte/Viele/f{i:00}.txt", new byte[100 + i]);
        _t.File("karte/lose.txt", new byte[50]);

        // Junction auf „Videos“ darf nicht doppelt gezählt werden
        var link = Path.Combine(root, "Verknuepft");
        var p = Process.Start(new ProcessStartInfo("cmd.exe", $"/c mklink /J \"{link}\" \"{Path.Combine(root, "Videos")}\"")
            { CreateNoWindow = true, UseShellExecute = false })!;
        p.WaitForExit();
        Assert.True(Directory.Exists(link));

        var svc = new DiskMapService();
        var node = svc.Scan(root);
        long viele = Enumerable.Range(0, DiskMapService.FilesPerFolder + 10).Sum(i => 100L + i);
        Assert.Equal(300_000 + 100_000 + 50 + viele, node.Size);
        Assert.Equal(DiskMapService.FilesPerFolder + 10 + 3, node.FileCount);
        Assert.Equal(1, svc.SkippedLinks);
        Assert.DoesNotContain(node.Children, c => c.Name == "Verknuepft");

        // Größte zuerst, Eltern richtig gesetzt
        Assert.Equal("Videos", node.Children[0].Name);
        Assert.Same(node, node.Children[0].Parent);
        Assert.Equal(400_000, node.Children[0].Size);

        var many = node.Children.Single(c => c.Name == "Viele");
        Assert.Equal(DiskMapService.FilesPerFolder + 1, many.Children.Count); // 40 einzeln + 1 Sammel-Eintrag
        var group = many.Children.Single(c => c.IsGroup);
        Assert.Equal(10, group.FileCount);
        Assert.Equal(viele, many.Children.Sum(c => c.Size));
        Assert.False(group.CanOpen);
        Assert.True(many.CanOpen);
        Assert.Equal(new[] { "karte", "Viele" }, many.PathFromRoot().Select(n => n.Name));
        Directory.Delete(link); // nur die Verknüpfung entfernen
    }

    // ───── winget-Ausgabe ─────

    private const string English =
        "   - \r   \\ \r                                                                                                                        \r" +
        "Name                                Id                            Version      Available    Source\n" +
        "--------------------------------------------------------------------------------------------------\n" +
        "Git                                 Git.Git                       2.53.0.2     2.56.0.4     winget\n" +
        "Microsoft Visual C++ v14 Redist     Microsoft.VCRedist.2015+.x64  14.51.36247  14.52.37029  winget\n" +
        "App Installer                       Microsoft.AppInstaller        1.29.379.0   1.29.380     winget\n" +
        "Python Launcher                     Python.Launcher               < 3.14.7     3.15.2       winget\n" +
        "Some Tool                           Vendor.VeryLongPackageNameTh… Unknown      2.0          winget\n" +
        "5 upgrades available.\n" +
        "\n" +
        "The following packages have an upgrade available, but require explicit targeting for upgrade:\n" +
        "Name      Id              Version Available Source\n" +
        "--------------------------------------------------\n" +
        "Discord   Discord.Discord 1.0     1.1       winget\n";

    [Fact]
    public void Winget_table_is_parsed_including_second_table_and_flags()
    {
        var list = WingetService.Parse(English);
        Assert.Equal(6, list.Count);
        var git = list.Single(u => u.Id == "Git.Git");
        Assert.Equal(("Git", "2.53.0.2", "2.56.0.4", "winget"), (git.Name, git.Version, git.Available, git.Source));
        Assert.False(git.Blocked);
        Assert.False(git.IsChecked); // standardmäßig nichts ausgewählt
        Assert.Equal("< 3.14.7", list.Single(u => u.Id == "Python.Launcher").Version);
        Assert.Equal("Microsoft Visual C++ v14 Redist", list.Single(u => u.Id == "Microsoft.VCRedist.2015+.x64").Name);

        var winget = list.Single(u => u.Id == "Microsoft.AppInstaller");
        Assert.True(winget.Blocked);
        winget.IsChecked = true;
        Assert.False(winget.IsChecked); // gesperrte Einträge lassen sich nicht anhaken

        var cut = list.Single(u => u.Id.StartsWith("Vendor."));
        Assert.True(cut.Blocked);
        Assert.True(cut.VersionUnknown);
        Assert.Contains("--include-unknown", WingetService.UpgradeArgs(cut));

        Assert.Contains(list, u => u.Id == "Discord.Discord" && u.Available == "1.1");
        Assert.Equal("upgrade --id \"Git.Git\" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity",
            WingetService.UpgradeArgs(git));
    }

    [Fact]
    public void Winget_german_header_and_empty_output_work()
    {
        const string de =
            "Name              ID                 Version   Verfügbar Quelle\r\n" +
            "-------------------------------------------------------------\r\n" +
            "Mozilla Firefox   Mozilla.Firefox    140.0     141.0.2   winget\r\n" +
            "1 Aktualisierungen verfügbar.\r\n";
        var list = WingetService.Parse(de);
        var ff = Assert.Single(list);
        Assert.Equal(("Mozilla Firefox", "Mozilla.Firefox", "140.0", "141.0.2"), (ff.Name, ff.Id, ff.Version, ff.Available));

        Assert.Empty(WingetService.Parse("Es wurde kein installiertes Paket gefunden, das den Eingabekriterien entspricht."));
        Assert.Empty(WingetService.Parse(""));
    }

    // ───── Downloads aufräumen ─────

    [Fact]
    public void Downloads_plan_sorts_by_rules_and_keeps_partial_new_and_hidden_files()
    {
        var dl = Path.Combine(_t.Root, "Downloads");
        var old = DateTime.Now.AddDays(-10);
        _t.File("Downloads/Urlaub.jpg", new byte[10], old);
        _t.File("Downloads/Rechnung.pdf", new byte[10], old);
        _t.File("Downloads/Setup_Tool.exe", new byte[10], old);
        _t.File("Downloads/Film.mp4.crdownload", new byte[10], old);
        _t.File("Downloads/heute.zip", new byte[10]); // von heute
        _t.File("Downloads/Screenshot 2026-01-01.png", new byte[10], old);
        var ini = _t.File("Downloads/desktop.ini", new byte[10], old);
        File.SetAttributes(ini, FileAttributes.Hidden | FileAttributes.System);
        Directory.CreateDirectory(Path.Combine(dl, "Fotos")); // vorhandener Ordner (Alias von „Bilder“)
        _t.File("Downloads/Fotos/schon_da.jpg", new byte[5], old);

        var planner = new DownloadsPlanner(new DesktopSettings(), dl);
        var files = planner.ReadFiles();
        Assert.DoesNotContain(files, f => f.FileName == "desktop.ini");
        Assert.DoesNotContain(files, f => f.FileName == "schon_da.jpg"); // Unterordner bleiben unberührt
        var changes = planner.BuildChanges(files, minAgeDays: 1, DateTime.Now);
        DesktopChange C(string n) => changes.Single(c => c.Item.FileName == n);

        Assert.Equal("Fotos", C("Urlaub.jpg").Target);
        Assert.Equal("Dokumente", C("Rechnung.pdf").Target);
        Assert.Equal("Installer", C("Setup_Tool.exe").Target);
        Assert.Equal("Screenshots", C("Screenshot 2026-01-01.png").Target);
        Assert.False(C("Film.mp4.crdownload").CanEnable);
        Assert.False(C("Film.mp4.crdownload").IsEnabled);
        Assert.True(C("heute.zip").CanEnable);
        Assert.False(C("heute.zip").IsEnabled); // Dateien von heute bleiben liegen …
        Assert.True(planner.BuildChanges(files, 0, DateTime.Now).Single(c => c.Item.FileName == "heute.zip").IsEnabled); // … außer bei „Alle“

        var plan = planner.Plan(changes);
        Assert.Equal(4, plan.Moves.Count);
        Assert.Equal(Path.Combine(dl, "Fotos", "Urlaub.jpg"), C("Urlaub.jpg").FinalPath);
        Assert.DoesNotContain(Path.Combine(dl, "Fotos"), plan.NewFolders);
        Assert.Contains(Path.Combine(dl, "Dokumente"), plan.NewFolders);
        Assert.Contains("bleibt liegen", C("heute.zip").Description);
    }

    [Fact]
    public async Task Downloads_apply_and_undo_use_own_history_and_never_overwrite()
    {
        var dl = Path.Combine(_t.Root, "Downloads");
        var old = DateTime.Now.AddDays(-3);
        _t.File("Downloads/a.pdf", new byte[11], old);
        _t.File("Downloads/Dokumente/a.pdf", new byte[22], old); // gleicher Name schon im Zielordner
        _t.File("Downloads/b.mp3", new byte[33], old);

        var planner = new DownloadsPlanner(new DesktopSettings(), dl);
        var changes = planner.BuildChanges(planner.ReadFiles(), 1, DateTime.Now);
        var plan = planner.Plan(changes);
        Assert.Contains("umbenannt", changes.Single(c => c.Item.FileName == "a.pdf").Description);

        var applier = new DesktopApplier(new DeleteLogService());
        var (res, snap) = await applier.ApplyAsync(null, plan, dl, null, DesktopHistory.DownloadsArea);
        Assert.Equal(2, res.Moved);
        Assert.Equal(22, new FileInfo(Path.Combine(dl, "Dokumente", "a.pdf")).Length); // nichts überschrieben
        Assert.Equal(11, new FileInfo(Path.Combine(dl, "Dokumente", "a (2).pdf")).Length);
        Assert.True(File.Exists(Path.Combine(dl, "Musik", "b.mp3")));
        Assert.False(File.Exists(Path.Combine(dl, "a.pdf")));

        // Eigener Verlauf – der Desktop-Verlauf bleibt leer
        Assert.Single(DesktopHistory.Load(DesktopHistory.DownloadsArea));
        Assert.Empty(DesktopHistory.Load());
        Assert.Equal("Downloads", snap.Area);
        Assert.DoesNotContain("Symbolpositionen", snap.Summary);

        var undo = await applier.UndoAsync(null, snap);
        Assert.Equal(2, undo.Moved);
        Assert.Equal(11, new FileInfo(Path.Combine(dl, "a.pdf")).Length);
        Assert.True(File.Exists(Path.Combine(dl, "b.mp3")));
        Assert.False(Directory.Exists(Path.Combine(dl, "Musik")));     // neu angelegt + leer → entfernt
        Assert.True(Directory.Exists(Path.Combine(dl, "Dokumente")));  // gab es vorher → bleibt
        Assert.True(DesktopHistory.Load(DesktopHistory.DownloadsArea).Single().Undone);
    }

    [Fact]
    public void Old_desktop_history_without_area_still_loads_as_desktop()
    {
        var file = Path.Combine(DesktopHistory.Dir, "20260101-120000-abcdef12.json");
        File.WriteAllText(file, "{\"Id\":\"abcdef1234\",\"Date\":\"2026-01-01T12:00:00\",\"ViewKind\":\"Desktop\",\"Moves\":[],\"Positions\":[],\"CreatedFolders\":[]}");
        var s = Assert.Single(DesktopHistory.Load());
        Assert.Equal("Desktop", s.Area);
        Assert.Contains("Symbolpositionen", s.Summary);
        Assert.Empty(DesktopHistory.Load(DesktopHistory.DownloadsArea));
    }
}

/// <summary>Downloads: Regel „Code“ und doppelte Dateien – nur im Testordner.</summary>
[Collection("seq")]
public class DownloadsDuplicateTests : IDisposable
{
    private readonly TestFolder _t = new();
    public void Dispose() => _t.Dispose();

    [Fact]
    public void Code_rule_sorts_scripts_and_is_added_to_old_settings_once()
    {
        var fresh = new DesktopSettings();
        var cat = new DesktopCategorizer(fresh);
        Assert.Equal("Code", cat.RuleForFile("bot_server.py").Folder);
        Assert.Equal("Code", cat.RuleForFile("index.html").Folder);
        Assert.Equal("Dokumente", cat.RuleForFile("notizen.txt").Folder);
        Assert.Equal("Sonstiges", cat.RuleForFile("daten.xyz").Folder);

        // Alte Einstellungsdatei ohne „Code“ → wird vor „Sonstiges“ eingefügt, eigene Regeln bleiben
        var old = new DesktopSettings();
        old.FolderRules.RemoveAll(r => r.Folder == "Code");
        old.FolderRules.Insert(0, new FolderRule("Meine Skripte", ".ps1"));
        old.MigrateFolderRules();
        old.MigrateFolderRules();
        Assert.Single(old.FolderRules, r => r.Folder == "Code");
        Assert.Equal("Sonstiges", old.FolderRules[^1].Folder);
        Assert.Equal("Code", old.FolderRules[^2].Folder);
        Assert.Equal("Meine Skripte", new DesktopCategorizer(old).RuleForFile("x.ps1").Folder); // eigene Regel gewinnt
        Assert.Equal(DesktopSettings.CurrentFolderRulesVersion, old.FolderRulesVersion);

        // Wer „Code“ schon selbst hat, bekommt keine zweite Regel
        var own = new DesktopSettings();
        own.FolderRules.RemoveAll(r => r.Folder == "Code");
        own.FolderRules.Insert(0, new FolderRule("code", ".py"));
        own.MigrateFolderRules();
        Assert.Single(own.FolderRules, r => r.Folder.Equals("code", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Duplicates_are_marked_original_kept_and_only_copies_recycled()
    {
        var dl = Path.Combine(_t.Root, "Downloads");
        var old = DateTime.Now.AddDays(-5);
        var zip = TestFolder.Bytes(5000, 1);
        var pptx = TestFolder.Bytes(7000, 2);
        _t.File("Downloads/alle_sounds_pack_1.21.10.zip", zip, old);
        _t.File("Downloads/alle_sounds_pack_1.21.10_1.zip", zip, DateTime.Now.AddDays(-9)); // älter, aber Kopie-Name
        _t.File("Downloads/BigTech_WithImages.pptx", pptx, old);
        _t.File("Downloads/BigTech_WithImages (1).pptx", pptx, old);
        _t.File("Downloads/BigTech - Kopie.pptx", pptx, old);
        _t.File("Downloads/gleich_gross_anders.zip", TestFolder.Bytes(5000, 9), old);   // gleiche Größe, anderer Inhalt
        _t.File("Downloads/laeuft.zip.crdownload", zip, old);                           // laufender Download

        var planner = new DownloadsPlanner(new DesktopSettings(), dl);
        var changes = planner.BuildChanges(planner.ReadFiles(), 1, DateTime.Now);
        int marked = DownloadsPlanner.MarkDuplicates(changes);
        DesktopChange C(string n) => changes.Single(c => c.Item.FileName == n);

        Assert.Equal(3, marked);
        Assert.False(C("alle_sounds_pack_1.21.10.zip").IsDuplicate);
        Assert.Equal("alle_sounds_pack_1.21.10.zip", C("alle_sounds_pack_1.21.10_1.zip").DuplicateOf);
        Assert.False(C("BigTech_WithImages.pptx").IsDuplicate);
        Assert.True(C("BigTech_WithImages (1).pptx").IsDuplicate);
        Assert.True(C("BigTech - Kopie.pptx").IsDuplicate);
        Assert.False(C("gleich_gross_anders.zip").IsDuplicate);
        Assert.False(C("laeuft.zip.crdownload").IsDuplicate);
        Assert.Contains("gleicher Inhalt", C("BigTech - Kopie.pptx").DuplicateText);

        // In den Papierkorb: nur die Kopien, die Originale bleiben (Sicherung über Duplikat-Gruppen)
        var all = new List<FileCandidate>();
        var delete = new List<FileCandidate>();
        foreach (var c in changes.Where(c => c.DuplicateGroup > 0))
        {
            var fc = new FileCandidate { FullPath = c.Item.Path, Name = c.Item.FileName, Size = c.Item.Size, Category = FindingCategory.Duplicates, GroupId = c.DuplicateGroup };
            fc.IsKeep = !c.IsDuplicate;
            all.Add(fc);
            if (c.IsDuplicate) delete.Add(fc);
        }
        var cleanup = new CleanupService(new ProtectionService(() => new List<string>()), new DeleteLogService());
        var log = await cleanup.RecycleAsync(delete, all, new Progress<(int, int, string)>(), CancellationToken.None);
        Assert.All(log, e => Assert.True(e.Success, e.Error));
        Assert.True(File.Exists(Path.Combine(dl, "alle_sounds_pack_1.21.10.zip")));
        Assert.True(File.Exists(Path.Combine(dl, "BigTech_WithImages.pptx")));
        Assert.False(File.Exists(Path.Combine(dl, "alle_sounds_pack_1.21.10_1.zip")));
        Assert.False(File.Exists(Path.Combine(dl, "BigTech_WithImages (1).pptx")));
        Assert.False(File.Exists(Path.Combine(dl, "BigTech - Kopie.pptx")));

        // Ohne überlebende Kopie verweigert der Papierkorb-Dienst das Löschen
        var lone = new FileCandidate { FullPath = Path.Combine(dl, "BigTech_WithImages.pptx"), Size = 7000, Category = FindingCategory.Duplicates, GroupId = 99 };
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            cleanup.RecycleAsync(new[] { lone }, new[] { lone }, new Progress<(int, int, string)>(), CancellationToken.None));
    }
}
