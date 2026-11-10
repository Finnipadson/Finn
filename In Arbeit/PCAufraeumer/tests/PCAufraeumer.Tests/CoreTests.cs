using PCAufraeumer.Models;
using PCAufraeumer.Services;

namespace PCAufraeumer.Tests;

/// <summary>
/// Alle Tests arbeiten AUSSCHLIESSLICH in einem eigenen Testordner mit Dummy-Dateien
/// (Standard: %USERPROFILE%\PCAufraeumer-Testordner, wird am Ende wieder entfernt).
/// </summary>
public sealed class TestFolder : IDisposable
{
    public string Root { get; }

    public TestFolder()
    {
        var baseDir = Environment.GetEnvironmentVariable("PCA_TESTDIR")
                      ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "PCAufraeumer-Testordner");
        Root = Path.Combine(baseDir, Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(Root);
        AppPaths.OverrideBaseDir(Path.Combine(Root, "_appdata"));
    }

    public string File(string rel, byte[] content, DateTime? time = null)
    {
        var p = Path.Combine(Root, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(p)!);
        System.IO.File.WriteAllBytes(p, content);
        if (time is { } t)
        {
            System.IO.File.SetCreationTime(p, t);
            System.IO.File.SetLastWriteTime(p, t);
            System.IO.File.SetLastAccessTime(p, t);
        }
        return p;
    }

    public void Dispose()
    {
        try
        {
            foreach (var f in Directory.EnumerateFiles(Root, "*", SearchOption.AllDirectories))
                System.IO.File.SetAttributes(f, FileAttributes.Normal);
            Directory.Delete(Root, true);
            var parent = Path.GetDirectoryName(Root)!;
            if (!Directory.EnumerateFileSystemEntries(parent).Any()) Directory.Delete(parent);
        }
        catch { }
    }

    public static byte[] Bytes(int size, int seed)
    {
        var b = new byte[size];
        new Random(seed).NextBytes(b);
        return b;
    }
}

[CollectionDefinition("seq", DisableParallelization = true)]
public class SeqCollection { }

[Collection("seq")]
public class ProtectionTests
{
    private readonly ProtectionService _p = new(() => new List<string> { @"D:\Ausgeschlossen" });

    [Theory]
    [InlineData(@"C:\Windows\System32\foo.dll")]
    [InlineData(@"C:\Program Files\App\a.mp4")]
    [InlineData(@"C:\Program Files (x86)\App\a.mp4")]
    [InlineData(@"C:\ProgramData\Cache\x.mp4")]
    [InlineData(@"D:\Ausgeschlossen\film.mkv")]
    [InlineData(@"D:\SteamLibrary\steamapps\common\Game\intro.mp4")]
    [InlineData(@"E:\Projekt\node_modules\x\a.zip")]
    [InlineData(@"E:\Projekt\.git\objects\a")]
    public void Protected_paths_are_never_offered(string path) => Assert.True(_p.IsProtectedPath(path));

    [Theory]
    [InlineData(@"D:\Videos\urlaub.mp4")]
    [InlineData(@"C:\Users\x\Downloads\setup.exe")]
    [InlineData(@"D:\Ausgeschlossen2\film.mkv")] // nur Präfix gleich, anderer Ordner
    public void Normal_paths_are_allowed(string path) => Assert.False(_p.IsProtectedPath(path));

    [Fact]
    public void Cloud_only_attributes_are_detected()
    {
        Assert.True(ProtectionService.IsCloudOnly(FileAttributes.Offline));
        Assert.True(ProtectionService.IsCloudOnly((FileAttributes)0x00400000));
        Assert.True(ProtectionService.IsCloudOnly((FileAttributes)0x00040000));
        Assert.False(ProtectionService.IsCloudOnly(FileAttributes.Archive | FileAttributes.ReparsePoint));
    }

    [Fact]
    public void Known_cache_root_is_allowed_only_when_requested()
    {
        _p.AllowCacheRoot(@"C:\Windows\Temp");
        Assert.True(_p.IsProtectedPath(@"C:\Windows\Temp\a.tmp"));
        Assert.False(_p.IsProtectedPath(@"C:\Windows\Temp\a.tmp", allowKnownCache: true));
        Assert.True(_p.IsProtectedPath(@"C:\Windows\System32\a.dll", allowKnownCache: true));
    }
}

[Collection("seq")]
public class LastAccessTests
{
    [Theory]
    [InlineData(0x80000000u, true)]
    [InlineData(0x80000001u, false)]
    [InlineData(0x80000002u, true)]
    [InlineData(0x80000003u, false)]
    [InlineData(0u, true)]
    [InlineData(1u, false)]
    public void Registry_value_is_interpreted(uint value, bool enabled)
    {
        var s = new LastAccessService();
        s.Interpret(value);
        Assert.Equal(enabled, s.UpdatesEnabled);
    }

    [Fact]
    public void Falls_back_to_write_date_when_disabled()
    {
        var s = new LastAccessService();
        s.Interpret(0x80000003);
        var (_, basis) = s.UsageDate(DateTime.Now, DateTime.Now.AddDays(-400));
        Assert.Equal(DateBasis.LastWrite, basis);
        s.Interpret(0x80000002);
        (_, basis) = s.UsageDate(DateTime.Now.AddDays(-10), DateTime.Now.AddDays(-400));
        Assert.Equal(DateBasis.LastAccess, basis);
    }
}

[Collection("seq")]
public class ScanTests : IDisposable
{
    private readonly TestFolder _t = new();
    public void Dispose() => _t.Dispose();

    private (ScanService scan, AppSettings s) Setup()
    {
        var la = new LastAccessService();
        la.Interpret(0x80000002); // Zugriffsdatum gilt als zuverlässig
        var settings = new AppSettings
        {
            ScanFolders = { _t.Root },
            DuplicateMinKB = 100,
            VideoAgeDays = 365,
            DownloadAgeDays = 182,
        };
        var prot = new ProtectionService(() => settings.ExcludedFolders);
        var scan = new ScanService(prot, la) { DownloadsFolder = Path.Combine(_t.Root, "Downloads") };
        return (scan, settings);
    }

    [Fact]
    public void Finds_old_videos_downloads_and_duplicates_but_respects_protection()
    {
        var old = DateTime.Now.AddDays(-500);
        var recent = DateTime.Now.AddDays(-10);

        var oldVideo = _t.File(@"Videos\alt.mkv", TestFolder.Bytes(2000, 1), old);
        _t.File(@"Videos\neu.mp4", TestFolder.Bytes(2000, 2), recent);
        var offline = _t.File(@"Videos\nur-online.mp4", TestFolder.Bytes(2000, 3), old);
        File.SetAttributes(offline, FileAttributes.Offline);
        _t.File(@"Projekt\node_modules\pkg\clip.mp4", TestFolder.Bytes(2000, 4), old);
        var excepted = _t.File(@"Videos\ausnahme.avi", TestFolder.Bytes(2000, 5), old);
        var locked = _t.File(@"Videos\offen.mov", TestFolder.Bytes(2000, 6), old);

        var dupContent = TestFolder.Bytes(300_000, 42);
        var d1 = _t.File(@"Fotos\Bild.jpg", dupContent, DateTime.Now.AddDays(-900));
        var d2 = _t.File(@"Downloads\Bild (1).jpg", dupContent, DateTime.Now.AddDays(-20));
        var d3 = _t.File(@"Desktop\Bild - Kopie.jpg", dupContent, DateTime.Now.AddDays(-5));
        // Gleiche Größe, gleicher Anfang und gleiches Ende, aber anderer Inhalt in der Mitte → KEIN Duplikat
        var tricky = (byte[])dupContent.Clone();
        tricky[150_000] ^= 0xFF;
        var notDup = _t.File(@"Fotos\Fast-gleich.jpg", tricky);
        _t.File(@"Fotos\klein1.txt", TestFolder.Bytes(500, 9));
        _t.File(@"Fotos\klein2.txt", TestFolder.Bytes(500, 9)); // Duplikat, aber unter Mindestgröße

        var oldSetup = _t.File(@"Downloads\setup.exe", TestFolder.Bytes(5000, 7), DateTime.Now.AddDays(-300));
        _t.File(@"Downloads\neu.zip", TestFolder.Bytes(5000, 8), DateTime.Now.AddDays(-30));

        var (scan, s) = Setup();
        s.ExceptionFiles.Add(excepted);
        ScanResult r;
        using (new FileStream(locked, FileMode.Open, FileAccess.Read, FileShare.None))
            r = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);

        var videos = r.Candidates.Where(c => c.Category == FindingCategory.Videos).Select(c => c.FullPath).ToList();
        Assert.Equal(new[] { oldVideo }, videos);
        Assert.Equal(DateBasis.LastAccess, r.Candidates.First(c => c.FullPath == oldVideo).Basis);
        Assert.Contains("nicht geöffnet", r.Candidates.First(c => c.FullPath == oldVideo).Reason);

        var downloads = r.Candidates.Where(c => c.Category == FindingCategory.Downloads).Select(c => c.FullPath).ToList();
        Assert.Equal(new[] { oldSetup }, downloads);

        var dups = r.Candidates.Where(c => c.Category == FindingCategory.Duplicates).ToList();
        Assert.Equal(3, dups.Count);
        Assert.DoesNotContain(dups, c => c.FullPath == notDup);
        Assert.Single(dups.Select(d => d.GroupId).Distinct());
        var keep = Assert.Single(dups, d => d.IsKeep);
        Assert.Equal(d1, keep.FullPath); // nicht Downloads, keine „Kopie“, älteste
        Assert.All(dups.Where(d => !d.IsKeep), d => Assert.StartsWith("Duplikat von", d.Reason));
        Assert.Contains(d2, dups.Select(d => d.FullPath));
        Assert.Contains(d3, dups.Select(d => d.FullPath));

        Assert.True(r.Stats.SkippedCloudOnly >= 1);
        Assert.True(r.Stats.SkippedLocked >= 1);
        Assert.True(r.Stats.SkippedExceptions >= 1);
        Assert.True(r.Stats.SkippedProtected >= 1);
        Assert.All(r.Candidates, c => Assert.False(c.IsSelected)); // Standardmäßig NICHTS ausgewählt
    }

    [Fact]
    public void Excluded_folder_and_min_size_are_respected()
    {
        var old = DateTime.Now.AddDays(-500);
        _t.File(@"Privat\film.mp4", TestFolder.Bytes(2000, 1), old);
        var big = _t.File(@"Filme\gross.mp4", TestFolder.Bytes(3 * 1024 * 1024, 2), old);
        _t.File(@"Filme\klein.mp4", TestFolder.Bytes(1024, 3), old);
        var (scan, s) = Setup();
        s.ExcludedFolders.Add(Path.Combine(_t.Root, "Privat"));
        s.MinSizeMB = 2;
        var r = scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        Assert.Equal(new[] { big }, r.Candidates.Select(c => c.FullPath));
    }

    [Fact]
    public void Scan_can_be_cancelled()
    {
        for (int i = 0; i < 50; i++) _t.File($@"Ordner{i}\x.mp4", TestFolder.Bytes(100, i), DateTime.Now.AddDays(-900));
        var (scan, s) = Setup();
        using var cts = new CancellationTokenSource();
        cts.Cancel();
        var r = scan.Scan(s, new Progress<ScanProgress>(), cts.Token);
        Assert.True(r.Cancelled);
    }

    [Fact]
    public void Hashing_restores_last_access_time()
    {
        var content = TestFolder.Bytes(200_000, 5);
        var when = DateTime.Now.AddDays(-700);
        var a = _t.File(@"A\x.bin", content, when);
        _t.File(@"B\x.bin", content, when);
        var (scan, s) = Setup();
        scan.Scan(s, new Progress<ScanProgress>(), CancellationToken.None);
        Assert.True(Math.Abs((File.GetLastAccessTime(a) - when).TotalSeconds) < 5);
    }
}

[Collection("seq")]
public class CleanupTests : IDisposable
{
    private readonly TestFolder _t = new();
    public void Dispose() => _t.Dispose();

    private static FileCandidate C(string path, int group = 0, bool keep = false) => new()
    {
        FullPath = path, Name = Path.GetFileName(path), Directory = Path.GetDirectoryName(path)!,
        Size = new FileInfo(path).Length, Category = group > 0 ? FindingCategory.Duplicates : FindingCategory.Videos,
        GroupId = group, IsKeep = keep,
    };

    [Fact]
    public void At_least_one_copy_per_duplicate_group_must_survive()
    {
        var a = C(_t.File("a.bin", new byte[10]), 1, keep: true);
        var b = C(_t.File("b.bin", new byte[10]), 1);
        var all = new[] { a, b };
        Assert.Empty(CleanupService.ValidateDuplicateGroups(new[] { b }, all));
        Assert.NotEmpty(CleanupService.ValidateDuplicateGroups(new[] { a, b }, all));
    }

    [Fact]
    public void Keep_copy_cannot_be_selected()
    {
        var a = C(_t.File("a.bin", new byte[10]), 1, keep: true);
        a.IsSelected = true;
        Assert.False(a.IsSelected);
    }

    [Fact]
    public async Task Recycle_moves_dummy_file_to_recycle_bin_and_logs_it()
    {
        var name = $"PCAufraeumer-Testdatei-{Guid.NewGuid():N}.mp4";
        var path = _t.File(Path.Combine("Papierkorb-Test", name), TestFolder.Bytes(1234, 1));
        var log = new DeleteLogService();
        var prot = new ProtectionService(() => new List<string>());
        var svc = new CleanupService(prot, log);
        var c = C(path);

        var entries = await svc.RecycleAsync(new[] { c }, new[] { c }, new Progress<(int, int, string)>(), CancellationToken.None);

        var e = Assert.Single(entries);
        Assert.True(e.Success, e.Error);
        Assert.False(File.Exists(path));
        Assert.Equal("Papierkorb", e.Method);
        Assert.Contains(log.ReadAll(), x => x.Path == path && x.Success && x.Size == 1234);
        Assert.True(InRecycleBin(name), "Datei wurde nicht im Papierkorb gefunden");
    }

    [Fact]
    public async Task Changed_or_locked_files_are_not_deleted()
    {
        var p1 = _t.File("geaendert.mp4", TestFolder.Bytes(100, 1));
        var c1 = C(p1);
        File.WriteAllBytes(p1, TestFolder.Bytes(200, 2)); // Größe geändert seit dem „Scan“
        var p2 = _t.File("gesperrt.mp4", TestFolder.Bytes(100, 3));
        var c2 = C(p2);
        var svc = new CleanupService(new ProtectionService(() => new List<string>()), new DeleteLogService());
        List<DeleteLogEntry> entries;
        using (new FileStream(p2, FileMode.Open, FileAccess.Read, FileShare.None))
            entries = await svc.RecycleAsync(new[] { c1, c2 }, new[] { c1, c2 }, new Progress<(int, int, string)>(), CancellationToken.None);
        Assert.All(entries, e => Assert.False(e.Success));
        Assert.True(File.Exists(p1));
        Assert.True(File.Exists(p2));
    }

    [Fact]
    public void Temp_clean_only_deletes_old_files()
    {
        var oldF = _t.File(@"FakeTemp\alt.tmp", new byte[100], DateTime.Now.AddDays(-3));
        var newF = _t.File(@"FakeTemp\neu.tmp", new byte[100]);
        var sub = _t.File(@"FakeTemp\Unterordner\alt2.tmp", new byte[50], DateTime.Now.AddDays(-3));
        var t = new TempTarget { Id = "test", Name = "Test-Temp", Paths = { Path.Combine(_t.Root, "FakeTemp") }, MinAgeHours = 24 };
        TempService.Measure(t, CancellationToken.None);
        Assert.Equal(2, t.FileCount);
        Assert.Equal(150, t.Size);
        var log = TempService.Clean(t, null, CancellationToken.None);
        Assert.False(File.Exists(oldF));
        Assert.False(File.Exists(sub));
        Assert.True(File.Exists(newF));
        Assert.False(Directory.Exists(Path.GetDirectoryName(sub))); // leerer Unterordner entfernt
        Assert.True(Directory.Exists(Path.Combine(_t.Root, "FakeTemp")));  // Wurzel bleibt
        Assert.Equal(2, log.Count(e => e.Success));
    }

    [Fact]
    public void Csv_export_is_excel_friendly()
    {
        var file = Path.Combine(_t.Root, "p.csv");
        DeleteLogService.ExportCsv(new[]
        {
            new DeleteLogEntry { Timestamp = new DateTime(2026, 11, 10, 14, 5, 0), Path = @"C:\a;b.mp4", Size = 2048, Method = "Papierkorb", Category = "Videos", Success = true },
        }, file);
        var bytes = File.ReadAllBytes(file);
        Assert.Equal(new byte[] { 0xEF, 0xBB, 0xBF }, bytes[..3]);
        var lines = File.ReadAllLines(file);
        Assert.StartsWith("Datum;Uhrzeit;Dateipfad", lines[0]);
        Assert.Equal("10.11.2026;14:05:00;\"C:\\a;b.mp4\";2048;2,0 KB;Papierkorb;Videos;Ja;", lines[1]);
    }

    private static bool InRecycleBin(string name)
    {
        var t = Type.GetTypeFromProgID("Shell.Application")!;
        dynamic shell = Activator.CreateInstance(t)!;
        dynamic bin = shell.NameSpace(10);
        foreach (dynamic item in bin.Items())
            if (((string)item.Name).Contains(Path.GetFileNameWithoutExtension(name), StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }
}

public class DriverTests
{
    [Theory]
    [InlineData("32.0.15.6214", "562.14")]
    [InlineData("32.0.16.2114", "621.14")]
    public void Nvidia_version_is_converted(string win, string nv) => Assert.Equal(nv, DriverService.ToNvidiaVersion(win));

    [Fact]
    public void Gpu_names_are_normalized()
    {
        Assert.Equal(DriverService.NormalizeGpuName("NVIDIA GeForce RTX 5070 Ti"), DriverService.NormalizeGpuName("GeForce RTX 5070 Ti"));
        Assert.True(DriverService.CompareVersions("621.14", "621.14") == 0);
        Assert.True(DriverService.CompareVersions("560.94", "621.14") < 0);
    }

    [Fact]
    public void Windows_update_offer_turns_driver_yellow_otherwise_green()
    {
        var a = new DriverItem { DeviceName = "Realtek Audio", HardwareId = @"HDAUDIO\FUNC_01&VEN_10EC", DeviceClass = "MEDIA", Date = DateTime.Now.AddDays(-30) };
        var b = new DriverItem { DeviceName = "Intel LAN", HardwareId = @"PCI\VEN_8086", DeviceClass = "NET", Date = DateTime.Now.AddDays(-30) };
        var c = new DriverItem { DeviceName = "Alt", HardwareId = @"PCI\VEN_1234", DeviceClass = "NET", Date = DateTime.Now.AddDays(-800) };
        var rest = DriverService.ApplyWindowsUpdate(new[] { a, b, c }, new List<WuDriverUpdate>
        {
            new() { Title = "Realtek - Audio - 6.0.9999", HardwareId = @"HDAUDIO\FUNC_01&VEN_10EC" },
            new() { Title = "Irgendwas", HardwareId = @"USB\VID_FFFF" },
        });
        Assert.Equal(Ampel.Gelb, a.Status);
        Assert.Equal(Ampel.Gruen, b.Status);
        Assert.Equal(Ampel.Gelb, c.Status);
        Assert.Single(rest);
    }
}
