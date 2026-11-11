using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using PCAufraeumer.Interop;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>Liest Verknüpfungen aus (.lnk über IShellLink, .url als Textdatei) – muss auf einem STA-Thread laufen.</summary>
public static class ShortcutResolver
{
    public sealed record Info(string Target, string Arguments, string Description, string Company, string Product);

    public static Info Resolve(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        try
        {
            if (ext is ".url" or ".website") return ResolveUrl(path);
            if (ext == ".lnk") return ResolveLnk(path);
            if (ext == ".exe")
            {
                // Programm-Starter direkt auf dem Desktop (z. B. Firefox „desktop-launcher.exe“)
                // Nur der Dateiname zählt – der Ordnerpfad (z. B. „…\OneDrive\Desktop“) würde sonst falsche Regeln treffen.
                var vi = FileVersionInfo.GetVersionInfo(path);
                return new Info(Path.GetFileName(path), "", vi.FileDescription ?? "", vi.CompanyName ?? "", vi.ProductName ?? "");
            }
        }
        catch (Exception ex) { ErrorLog.Write($"Verknüpfung nicht lesbar: {path}", ex); }
        return new Info("", "", "", "", "");
    }

    private static Info ResolveUrl(string path)
    {
        string url = "", icon = "";
        foreach (var line in File.ReadLines(path))
        {
            if (line.StartsWith("URL=", StringComparison.OrdinalIgnoreCase)) url = line[4..].Trim();
            else if (line.StartsWith("IconFile=", StringComparison.OrdinalIgnoreCase)) icon = line[9..].Trim();
        }
        return new Info(url, "", icon, "", "");
    }

    private static Info ResolveLnk(string path)
    {
        var link = (IShellLinkW)new ShellLinkCoClass();
        try
        {
            ((IPersistFile)link).Load(path, 0);
            var sb = new StringBuilder(1024);
            link.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);
            var target = sb.ToString();
            sb.Clear(); link.GetArguments(sb, sb.Capacity);
            var args = sb.ToString();
            sb.Clear(); link.GetDescription(sb, sb.Capacity);
            var desc = sb.ToString();
            if (string.IsNullOrEmpty(target))
            {
                // „Angekündigte“ Verknüpfungen (Office, Store-Apps): Symbolpfad als Hinweis nutzen.
                sb.Clear(); link.GetIconLocation(sb, sb.Capacity, out _);
                target = Environment.ExpandEnvironmentVariables(sb.ToString());
            }
            string company = "", product = "";
            try
            {
                if (target.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) && File.Exists(target))
                {
                    var vi = FileVersionInfo.GetVersionInfo(target);
                    company = vi.CompanyName ?? "";
                    product = vi.ProductName ?? "";
                }
            }
            catch { }
            return new Info(target, args, desc, company, product);
        }
        finally { Marshal.ReleaseComObject(link); }
    }

    private static readonly string[] InstallerWords = { "setup", "install", "installer", "update", "uninst", "redist", "bootstrap" };

    /// <summary>
    /// Ist eine .exe auf dem Desktop ein Programm-Starter (wie eine Verknüpfung) statt eines Installers?
    /// Beispiel: Firefox legt statt einer Verknüpfung „Firefox.exe“ ab (Originalname desktop-launcher.exe).
    /// Installer (Setup, Install, Update …) bleiben Dateien und kommen weiter in den Ordner „Installer“.
    /// </summary>
    public static bool IsAppLauncher(string path)
    {
        try
        {
            if (!path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || !File.Exists(path)) return false;
            // „Nur online“-Dateien nicht anfassen (Lesen würde sie herunterladen)
            if (ProtectionService.IsCloudOnly(File.GetAttributes(path))) return false;
            var vi = FileVersionInfo.GetVersionInfo(path);
            var orig = vi.OriginalFilename ?? "";
            var hay = string.Join(" ", Path.GetFileName(path), vi.ProductName, vi.FileDescription, orig, vi.InternalName);
            if (InstallerWords.Any(w => hay.Contains(w, StringComparison.OrdinalIgnoreCase))) return false;
            return orig.Contains("launcher", StringComparison.OrdinalIgnoreCase)
                || (vi.FileDescription ?? "").Contains("launcher", StringComparison.OrdinalIgnoreCase);
        }
        catch { return false; }
    }

    /// <summary>Legt eine .lnk-Datei an (nur für Tests mit Dummy-Verknüpfungen).</summary>
    public static void CreateLnk(string lnkPath, string target, string args = "")
    {
        var link = (IShellLinkW)new ShellLinkCoClass();
        try
        {
            link.SetPath(target);
            if (args.Length > 0) link.SetArguments(args);
            ((IPersistFile)link).Save(lnkPath, 1);
        }
        finally { Marshal.ReleaseComObject(link); }
    }
}

/// <summary>Ordnet App-Symbole Kategorien zu: eigene Zuordnung → Regelliste → „Sonstiges“.</summary>
public sealed class DesktopCategorizer
{
    private readonly DesktopSettings _s;
    public DesktopCategorizer(DesktopSettings s) => _s = s;

    public string Categorize(DesktopItem item, ShortcutResolver.Info info)
    {
        var cats = _s.Categories;
        string Valid(string c) => cats.Contains(c, StringComparer.OrdinalIgnoreCase)
            ? cats.First(x => string.Equals(x, c, StringComparison.OrdinalIgnoreCase))
            : FallbackCategory;

        var ov = _s.IconOverrides.FirstOrDefault(kv => string.Equals(kv.Key, item.FileName, StringComparison.OrdinalIgnoreCase));
        if (ov.Key != null) return Valid(ov.Value);

        // In der Programmliste gesetzte Kategorie (gleiche .exe oder gleicher Name) gilt auch hier.
        if (TargetOverride(info.Target, item.DisplayName) is { } tov) return Valid(tov);

        var hay = string.Join(" | ", item.DisplayName, item.FileName, info.Target, info.Arguments, info.Description, info.Company, info.Product);
        foreach (var r in _s.AppRules)
        {
            if (string.IsNullOrWhiteSpace(r.Pattern)) continue;
            if (hay.Contains(r.Pattern, StringComparison.OrdinalIgnoreCase))
                return Valid(r.Category);
        }
        return FallbackCategory;
    }

    public static string ExeKey(string exe) => exe.Trim().Trim('"').ToLowerInvariant();
    public static string NameKey(string name) => "name:" + name.Trim().ToLowerInvariant();

    private string? TargetOverride(string target, string name)
    {
        var d = _s.TargetOverrides;
        if (!string.IsNullOrWhiteSpace(target) &&
            d.FirstOrDefault(kv => string.Equals(kv.Key, ExeKey(target), StringComparison.OrdinalIgnoreCase)) is { Key: not null } a) return a.Value;
        if (!string.IsNullOrWhiteSpace(name) &&
            d.FirstOrDefault(kv => string.Equals(kv.Key, NameKey(name), StringComparison.OrdinalIgnoreCase)) is { Key: not null } b) return b.Value;
        return null;
    }

    /// <summary>Kategorie für einen Eintrag der Programmliste (gleiche Regeln wie beim Desktop).</summary>
    public string CategorizeProgram(InstalledProgram p)
    {
        var cats = _s.Categories;
        string Valid(string c) => cats.Contains(c, StringComparer.OrdinalIgnoreCase)
            ? cats.First(x => string.Equals(x, c, StringComparison.OrdinalIgnoreCase)) : FallbackCategory;
        if (TargetOverride(p.MainExe, p.Name) is { } ov) return Valid(ov);
        if (p.Kind == ProgramKind.Spiel && cats.Contains("Spiele", StringComparer.OrdinalIgnoreCase)) return Valid("Spiele");
        var hay = string.Join(" | ", p.Name, p.Publisher, p.MainExe, p.InstallLocation, p.LauncherUri, p.PackageFamilyName);
        foreach (var r in _s.AppRules)
        {
            if (string.IsNullOrWhiteSpace(r.Pattern)) continue;
            // Allgemeine Web-Links sagen bei Programmen nichts aus.
            if (r.Pattern.StartsWith("http", StringComparison.OrdinalIgnoreCase)) continue;
            if (hay.Contains(r.Pattern, StringComparison.OrdinalIgnoreCase)) return Valid(r.Category);
        }
        return FallbackCategory;
    }

    /// <summary>Kategorie eines Programms merken – gilt dann auch fürs Desktop-Aufräumen.</summary>
    public void RememberProgramCategory(InstalledProgram p, string category)
    {
        if (!string.IsNullOrWhiteSpace(p.MainExe)) _s.TargetOverrides[ExeKey(p.MainExe)] = category;
        _s.TargetOverrides[NameKey(p.Name)] = category;
    }

    public string FallbackCategory =>
        _s.Categories.FirstOrDefault(c => string.Equals(c, DesktopSettings.Fallback, StringComparison.OrdinalIgnoreCase))
        ?? _s.Categories.LastOrDefault() ?? DesktopSettings.Fallback;

    /// <summary>Passende Ordnerregel für eine lose Datei.</summary>
    public FolderRule RuleForFile(string fileName)
    {
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        var name = Path.GetFileNameWithoutExtension(fileName);
        // Zuerst Regeln mit Namensanfang (z. B. Screenshots), dann reine Endungsregeln.
        foreach (var r in _s.FolderRules.Where(r => r.PrefixList().Any()))
            if (r.ExtensionList().Contains(ext) && r.PrefixList().Any(p => name.StartsWith(p, StringComparison.OrdinalIgnoreCase)))
                return r;
        foreach (var r in _s.FolderRules.Where(r => !r.PrefixList().Any()))
            if (r.ExtensionList().Contains(ext)) return r;
        return _s.FolderRules.FirstOrDefault(r => !r.ExtensionList().Any()) ?? new FolderRule("Sonstiges", "");
    }
}
