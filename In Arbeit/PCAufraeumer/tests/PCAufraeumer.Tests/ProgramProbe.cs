using PCAufraeumer.Models;
using PCAufraeumer.Services;
using Xunit.Abstractions;

namespace PCAufraeumer.Tests;

/// <summary>Nur lesend: zeigt, was die Programmliste auf diesem PC erkennt (Ausgabe mit PCA_PROBE_VERBOSE=1).</summary>
public class ProgramProbe
{
    private readonly ITestOutputHelper _out;
    public ProgramProbe(ITestOutputHelper o) => _out = o;

    [Fact]
    public void Installed_programs_can_be_read()
    {
        var list = new ProgramInventory().ReadAll();
        Assert.NotEmpty(list);
        if (Environment.GetEnvironmentVariable("PCA_PROBE_VERBOSE") != "1") return;
        var cat = new DesktopCategorizer(new DesktopSettings());
        _out.WriteLine($"Gesamt {list.Count}, sichtbar {list.Count(p => !p.HiddenByDefault)}");
        foreach (var g in list.Where(p => !p.HiddenByDefault).GroupBy(p => p.TypeLabel))
            _out.WriteLine($"  {g.Key}: {g.Count()}");
        foreach (var p in list.Where(p => !p.HiddenByDefault).Take(400))
            _out.WriteLine($"{p.TypeLabel,-18} | {cat.CategorizeProgram(p),-20} | {p.Name} | {p.Version} | {p.Publisher} | {p.InstallDateText} | {(p.Size is long s ? Format.Bytes(s) : "?")} | {(p.IsLocked ? "LOCK " : "")}{(p.IsOrphaned ? "VERWAIST " : "")}| {p.InstallLocation}");
    }
}
