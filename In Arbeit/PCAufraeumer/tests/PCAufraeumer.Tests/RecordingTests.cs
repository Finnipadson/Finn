using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.Tests;

/// <summary>Spielaufnahmen im Scan – nur mit Dummy-Clips im Testordner, nie mit den echten Aufnahmen.</summary>
public class RecordingTests : IDisposable
{
    private readonly TestFolder _t = new();
    public void Dispose() => _t.Dispose();

    [Theory]
    [InlineData("Apex Legends 2026.01.04 - 17.32.11.02.DVR", "Apex Legends")]
    [InlineData("Fortnite 2026-01-04 17-32-11", "Fortnite")]
    [InlineData("Call of Duty  Black Ops 7_2026_01_04", "Call of Duty Black Ops 7")]
    [InlineData("2026-01-04 17-32-11", RecordingSources.UnknownGame)]
    [InlineData("mein bester clip", RecordingSources.UnknownGame)]
    public void Game_is_read_from_file_name(string name, string game) =>
        Assert.Equal(game, RecordingSources.GameFromFileName(name));

    [Fact]
    public void Game_folder_keep_folder_and_flat_sources_are_handled()
    {
        var nv = new RecordingFolder(@"C:\V\NVIDIA", "NVIDIA", true, true);
        Assert.Equal("Apex Legends", RecordingSources.GameFor(nv, @"C:\V\NVIDIA\Apex Legends\x 2026.01.01.mp4"));
        Assert.Equal("Valorant", RecordingSources.GameFor(nv, @"C:\V\NVIDIA\Valorant 2026.01.01 - 1.mp4")); // direkt im Ordner → Dateiname
        Assert.Equal("Call of Duty Black Ops 7", RecordingSources.GameFor(nv, @"C:\V\NVIDIA\Call of Duty  Black Ops 7\a.mp4"));
        Assert.True(RecordingSources.IsInKeepFolder(nv.Path, @"C:\V\NVIDIA\Apex Legends\Behalten\a.mp4"));
        Assert.True(RecordingSources.IsInKeepFolder(nv.Path, @"C:\V\NVIDIA\behalten\sub\a.mp4"));
        Assert.False(RecordingSources.IsInKeepFolder(nv.Path, @"C:\V\NVIDIA\Apex Legends\a.mp4"));

        var xbox = new RecordingFolder(@"C:\V\Captures", "Xbox Game Bar", false, false);
        Assert.True(RecordingSources.Belongs(xbox, @"C:\V\Captures\Fortnite 2026-01-04 17-32-11.mp4"));
        Assert.False(RecordingSources.Belongs(xbox, @"C:\V\Captures\Unterordner\a.mp4"));
        var ss = new RecordingFolder(@"C:\V\SteelSeries Moments", "SteelSeries Moments", true, false);
        Assert.True(RecordingSources.Belongs(ss, @"C:\V\SteelSeries Moments\Exported Clips\Apex Legends 2026-01-01.mp4"));
        Assert.False(RecordingSources.Belongs(ss, @"C:\V\SteelSeries Moments\thumbs\a.mp4"));
        Assert.Equal("Apex Legends", RecordingSources.GameFor(ss, @"C:\V\SteelSeries Moments\Exported Clips\Apex Legends 2026-01-01.mp4"));

        var steam = new RecordingFolder(@"C:\S\userdata\1\gamerecordings", "Steam", true, false);
        Assert.Equal("Counter-Strike 2", RecordingSources.GameFor(steam, @"C:\S\userdata\1\gamerecordings\clips\clip_730_20260101_120000\export.mp4",
            id => id == "730" ? "Counter-Strike 2" : null));
    }

    private (ScanService scan, AppSettings s, string nv, string xbox) Setup()
    {
        var nv = Path.Combine(_t.Root, "Videos", "NVIDIA");
        var xbox = Path.Combine(_t.Root, "Videos", "Captures");
        var s = new AppSettings
        {
            ScanFolders = { _t.Root }, CategoryVideos = true, CategoryDuplicates = true, CategoryDownloads = false,
            CategoryRecordings = true, VideoAgeDays = 30, DuplicateMinKB = 1,
        };
        var la = new LastAccessService();
        la.Interpret(0x80000002);
        var scan = new ScanService(new ProtectionService(() => s.ExcludedFolders), la)
        {
            DownloadsFolder = Path.Combine(_t.Root, "Downloads"),
            RecordingFolders = _ => new List<RecordingFolder>
            {
                new(nv, "NVIDIA", true, true),
                new(xbox, "Xbox Game Bar", false, false),
            },
        };
        return (scan, s, nv, xbox);
    }

    [Fact]
    public void Scan_lists_all_clips_by_game_skips_keep_folder_and_does_not_double_count()
    {
        var (scan, s, _, _) = Setup();
        var old = DateTime.Now.AddDays(-400);
        var same = TestFolder.Bytes(5000, 7);
        _t.File(@"Videos\NVIDIA\Apex Legends\Apex Legends 2026.01.01 - 1.mp4", TestFolder.Bytes(9000, 1), DateTime.Now.AddDays(-1));
        _t.File(@"Videos\NVIDIA\Apex Legends\Apex Legends 2025.01.01 - 1.mp4", same, old);
        _t.File(@"Videos\NVIDIA\Apex Legends\Behalten\Bester Clip.mp4", TestFolder.Bytes(9000, 2), old);
        _t.File(@"Videos\NVIDIA\Call of Duty  Black Ops 7\a.mp4", TestFolder.Bytes(3000, 3), old);
        _t.File(@"Videos\NVIDIA\Call of Duty Black Ops 7\b.mp4", TestFolder.Bytes(3000, 4), old);
        _t.File(@"Videos\NVIDIA\Apex Legends\notiz.txt", new byte[10], old);       // keine Videodatei
        _t.File(@"Videos\Captures\Fortnite 2026-01-04 17-32-11.mp4", TestFolder.Bytes(1000, 5), DateTime.Now); // ganz neu
        _t.File(@"Videos\Captures\Alt\Fortnite 2020-01-01 10-00-00.mp4", TestFolder.Bytes(1000, 6), old);      // Xbox: keine Unterordner
        var film = _t.File(@"Videos\Urlaub.mp4", same, old); // normales altes Video, gleicher Inhalt wie ein Clip

        var r = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        var clips = r.Candidates.Where(c => c.Category == FindingCategory.Recordings).ToList();

        Assert.Equal(5, clips.Count); // 2× Apex, 2× CoD, 1× Fortnite – ohne „Behalten“, ohne Xbox-Unterordner
        Assert.DoesNotContain(clips, c => c.Name == "Bester Clip.mp4");
        Assert.Contains(clips, c => c.Game == "Fortnite" && c.Source == "Xbox Game Bar"); // auch neue Clips (keine Altersgrenze)
        Assert.All(clips, c => Assert.False(c.IsSelected)); // nichts vorausgewählt

        // Gleiches Spiel trotz doppeltem Leerzeichen → eine Gruppe; größtes Spiel zuerst
        Assert.Equal(2, clips.Count(c => c.GroupLabel == "Spielaufnahmen · Call of Duty Black Ops 7"));
        var apex = clips.Where(c => c.Game == "Apex Legends").ToList();
        Assert.All(apex, c => Assert.Equal(1, c.GroupId));
        Assert.True(apex.Single(c => c.Name.Contains("2026")).SortValue > apex.Single(c => c.Name.Contains("2025")).SortValue); // neueste zuerst

        // Clips nicht zusätzlich als „alte Videos“ oder Duplikate
        Assert.DoesNotContain(r.Candidates, c => c.Category == FindingCategory.Videos && c.FullPath.Contains(@"\NVIDIA\"));
        Assert.DoesNotContain(r.Candidates, c => c.Category == FindingCategory.Duplicates);
        Assert.Contains(r.Candidates, c => c.Category == FindingCategory.Videos && c.FullPath == film);
    }

    [Fact]
    public void Recordings_off_keeps_old_behaviour()
    {
        var (scan, s, _, _) = Setup();
        s.CategoryRecordings = false;
        _t.File(@"Videos\NVIDIA\Apex Legends\alt.mp4", TestFolder.Bytes(2000, 1), DateTime.Now.AddDays(-400));
        var r = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        Assert.DoesNotContain(r.Candidates, c => c.Category == FindingCategory.Recordings);
        Assert.Contains(r.Candidates, c => c.Category == FindingCategory.Videos && c.Name == "alt.mp4");
    }

    [Fact]
    public void Move_to_keep_folder_moves_without_overwrite_and_clip_is_not_suggested_again()
    {
        var (scan, s, nv, _) = Setup();
        var clip = _t.File(@"Videos\NVIDIA\Apex Legends\Apex Legends 2026.01.01 - 1.mp4", TestFolder.Bytes(4000, 1), DateTime.Now);
        _t.File(@"Videos\NVIDIA\Apex Legends\Behalten\Apex Legends 2026.01.01 - 1.mp4", TestFolder.Bytes(10, 2)); // gleicher Name existiert schon

        var r = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        var c = r.Candidates.Single(x => x.Category == FindingCategory.Recordings);
        var log = new DeleteLogService();
        var cleanup = new CleanupService(new ProtectionService(() => s.ExcludedFolders), log);
        var (moved, problems) = cleanup.MoveToKeepFolder(new[] { c });

        Assert.Single(moved);
        Assert.Empty(problems);
        Assert.False(File.Exists(clip));
        var keep = Path.Combine(nv, "Apex Legends", "Behalten");
        Assert.Equal(10, new FileInfo(Path.Combine(keep, "Apex Legends 2026.01.01 - 1.mp4")).Length);      // nicht überschrieben
        Assert.Equal(4000, new FileInfo(Path.Combine(keep, "Apex Legends 2026.01.01 - 1 (2).mp4")).Length);
        Assert.Contains(log.ReadAll(), e => e.Method.Contains("Behalten") && e.Success);

        var again = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        Assert.DoesNotContain(again.Candidates, x => x.Category == FindingCategory.Recordings);
        Assert.DoesNotContain(again.Candidates, x => x.FullPath.Contains(@"\Behalten\")); // auch nicht als altes Video/Duplikat

        // Andere Kategorien werden nie verschoben
        var other = new FileCandidate { FullPath = _t.File(@"x.mp4", new byte[5]), Name = "x.mp4", Category = FindingCategory.Videos };
        var (m2, p2) = cleanup.MoveToKeepFolder(new[] { other });
        Assert.Empty(m2);
        Assert.Single(p2);
        Assert.True(File.Exists(other.FullPath));
    }
}
