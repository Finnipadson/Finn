using System.Diagnostics;
using System.Text;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Services;

public enum UpdateState { Offen, Laeuft, Fertig, Fehler }

/// <summary>Ein Programm, für das winget eine neuere Version kennt.</summary>
public sealed partial class WingetUpdate : ObservableObject
{
    public string Name { get; init; } = "";
    public string Id { get; init; } = "";
    public string Version { get; init; } = "";
    public string Available { get; init; } = "";
    public string Source { get; init; } = "";
    /// <summary>Kann nicht hier aktualisiert werden (ID abgeschnitten, winget selbst …) – Grund in <see cref="Note"/>.</summary>
    public bool Blocked { get; init; }
    public string Note { get; init; } = "";

    [ObservableProperty] private bool _isChecked;
    [ObservableProperty] private UpdateState _state;
    [ObservableProperty] private string _result = "";

    public bool CanCheck => !Blocked;
    public bool VersionUnknown => Version.Equals("Unknown", StringComparison.OrdinalIgnoreCase) ||
                                  Version.Equals("Unbekannt", StringComparison.OrdinalIgnoreCase);

    partial void OnIsCheckedChanged(bool value) { if (value && Blocked) IsChecked = false; }
}

/// <summary>
/// Programm-Updates über winget (bei Windows 10/11 dabei). Liest die Liste mit „winget upgrade“ und
/// aktualisiert nur ausdrücklich ausgewählte Pakete einzeln mit „--id … --exact“.
/// </summary>
public static class WingetService
{
    /// <summary>Pakete, die sich nicht über winget selbst aktualisieren lassen.</summary>
    private static readonly Dictionary<string, string> SelfManaged = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Microsoft.AppInstaller"] = "Das ist winget selbst – wird über den Microsoft Store aktualisiert.",
    };

    public static string? FindWinget()
    {
        var local = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WindowsApps", "winget.exe");
        if (File.Exists(local)) return local;
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            try
            {
                var p = Path.Combine(dir.Trim(), "winget.exe");
                if (File.Exists(p)) return p;
            }
            catch { }
        }
        return null;
    }

    public sealed record RunResult(int ExitCode, string Output);

    public static async Task<RunResult> RunAsync(string exe, string args, TimeSpan timeout, CancellationToken ct = default)
    {
        var psi = new ProcessStartInfo(exe, args)
        {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8,
        };
        using var p = Process.Start(psi) ?? throw new InvalidOperationException("winget konnte nicht gestartet werden.");
        var outTask = p.StandardOutput.ReadToEndAsync(ct);
        var errTask = p.StandardError.ReadToEndAsync(ct);
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(timeout);
        try { await p.WaitForExitAsync(cts.Token); }
        catch (OperationCanceledException)
        {
            try { p.Kill(entireProcessTree: true); } catch { }
            if (ct.IsCancellationRequested) throw;
            throw new TimeoutException($"winget hat nach {timeout.TotalMinutes:0} Minuten nicht geantwortet.");
        }
        return new RunResult(p.ExitCode, await outTask + await errTask);
    }

    public static async Task<List<WingetUpdate>> ListUpdatesAsync(CancellationToken ct = default)
    {
        var exe = FindWinget() ?? throw new FileNotFoundException(
            "winget wurde nicht gefunden. Es gehört zum „App-Installer“ aus dem Microsoft Store.");
        var r = await RunAsync(exe, "upgrade --include-unknown --accept-source-agreements --disable-interactivity",
            TimeSpan.FromMinutes(4), ct);
        return Parse(r.Output);
    }

    /// <summary>Liest die Tabelle(n) aus der winget-Ausgabe. Spaltenpositionen kommen aus der Kopfzeile (Sprache egal).</summary>
    public static List<WingetUpdate> Parse(string output)
    {
        var lines = output.Replace("\r\n", "\n").Split('\n').Select(Clean).ToList();
        var list = new List<WingetUpdate>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 1; i < lines.Count; i++)
        {
            var dash = lines[i].Trim();
            if (dash.Length < 20 || dash.Any(c => c != '-' && c != '─')) continue;
            var cols = ColumnStarts(lines[i - 1]);
            if (cols.Count < 4) continue;
            for (int j = i + 1; j < lines.Count; j++)
            {
                var line = lines[j];
                if (line.Trim().Length == 0) break;
                if (line.Length <= cols[3]) break; // Fußzeile („25 upgrades available.“)
                string Col(int k)
                {
                    int s = cols[k];
                    if (s >= line.Length) return "";
                    int e = k + 1 < cols.Count ? Math.Min(cols[k + 1], line.Length) : line.Length;
                    return line[s..e].Trim();
                }
                var id = Col(1);
                if (id.Length == 0 || id.Contains(' ') || !seen.Add(id)) continue;
                bool truncated = id.EndsWith('…') || id.EndsWith("...");
                var note = truncated ? "Paket-ID ist abgeschnitten – bitte im Terminal aktualisieren." :
                           SelfManaged.TryGetValue(id, out var n) ? n : "";
                list.Add(new WingetUpdate
                {
                    Name = Col(0).TrimEnd('…'), Id = id, Version = Col(2), Available = Col(3),
                    Source = cols.Count > 4 ? Col(4) : "", Blocked = note.Length > 0, Note = note,
                });
            }
        }
        return list.OrderBy(u => u.Name, StringComparer.CurrentCultureIgnoreCase).ToList();
    }

    /// <summary>Fortschrittsanzeige (\r, \b, Drehstrich) entfernen – nur der zuletzt geschriebene Zeilenteil zählt.</summary>
    private static string Clean(string line)
    {
        int cr = line.LastIndexOf('\r');
        if (cr >= 0) line = line[(cr + 1)..];
        var sb = new StringBuilder(line.Length);
        foreach (var c in line)
        {
            if (c == '\b') { if (sb.Length > 0) sb.Length--; continue; }
            if (c >= ' ') sb.Append(c);
        }
        return sb.ToString().TrimEnd();
    }

    private static List<int> ColumnStarts(string header)
    {
        var starts = new List<int>();
        for (int i = 0; i < header.Length; i++)
            if (header[i] != ' ' && (i == 0 || header[i - 1] == ' ')) starts.Add(i);
        // Führende Restzeichen eines Drehstrichs („- “, „\ “) vor „Name“ ignorieren
        while (starts.Count > 5 && header[starts[0]] is '-' or '\\' or '|' or '/') starts.RemoveAt(0);
        return starts;
    }

    public static string UpgradeArgs(WingetUpdate u) =>
        $"upgrade --id \"{u.Id}\" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" +
        (u.VersionUnknown ? " --include-unknown" : "");

    /// <summary>Ein Paket aktualisieren. Installer, die Adminrechte brauchen, fragen selbst per Windows-Abfrage (UAC).</summary>
    public static async Task<(bool ok, string message)> UpgradeAsync(WingetUpdate u, CancellationToken ct = default)
    {
        var exe = FindWinget() ?? throw new FileNotFoundException("winget wurde nicht gefunden.");
        var r = await RunAsync(exe, UpgradeArgs(u), TimeSpan.FromMinutes(30), ct);
        var last = r.Output.Replace("\r\n", "\n").Split('\n').Select(Clean)
            .Where(l => l.Trim().Length > 3 && !l.Trim().All(c => c is '-' or '\\' or '|' or '/' or '█' or '▒' or ' '))
            .LastOrDefault()?.Trim() ?? "";
        if (r.ExitCode == 0) return (true, last.Length > 0 ? last : "Aktualisiert.");
        return (false, $"Fehlercode 0x{r.ExitCode:X8}" + (last.Length > 0 ? $": {last}" : ""));
    }
}
