using PCAufraeumer.Services;
using Xunit.Abstractions;

namespace PCAufraeumer.Tests;

/// <summary>Nur lesend: prüft, ob die Desktop-Shell-Schnittstelle erreichbar ist und zeigt Verknüpfungsziele.</summary>
public class DesktopProbe
{
    private readonly ITestOutputHelper _out;
    public DesktopProbe(ITestOutputHelper o) => _out = o;

    [Fact]
    public async Task Real_desktop_can_be_read_without_changes()
    {
        var text = await StaTask.Run(() =>
        {
            using var v = DesktopShellView.OpenDesktop();
            var items = v.GetItems();
            var sb = new System.Text.StringBuilder();
            sb.AppendLine($"Spacing {v.Spacing.X}x{v.Spacing.Y}, AutoArrange={v.AutoArrange}");
            foreach (var i in items.Where(i => i.ParsingPath.EndsWith(".lnk") || i.ParsingPath.EndsWith(".url")))
            {
                var info = ShortcutResolver.Resolve(i.ParsingPath);
                if (Environment.GetEnvironmentVariable("PCA_PROBE_VERBOSE") == "1")
                    sb.AppendLine($"{i.DisplayName} => {info.Target} {info.Arguments} [{info.Company}|{info.Product}]");
            }
            return sb.ToString();
        });
        _out.WriteLine(text);
        Assert.Contains("Spacing", text);
    }
}
