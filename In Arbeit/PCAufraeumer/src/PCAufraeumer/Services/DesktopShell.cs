using System.Runtime.InteropServices;
using System.Text;
using PCAufraeumer.Interop;

namespace PCAufraeumer.Services;

public sealed class ShellViewItem
{
    public string ParsingPath { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public bool IsFileSystem { get; init; }
    public bool IsFolder { get; init; }
    public int X { get; init; }
    public int Y { get; init; }
}

/// <summary>Ein Monitor in Koordinaten der Symbolansicht (physische Pixel).</summary>
public sealed class ViewMonitor
{
    public int Left { get; init; }
    public int Top { get; init; }
    public int Width { get; init; }
    public int Height { get; init; }
    public int WorkLeft { get; init; }
    public int WorkTop { get; init; }
    public int WorkWidth { get; init; }
    public int WorkHeight { get; init; }
    public bool IsPrimary { get; init; }
    public bool Contains(int x, int y) => x >= Left && x < Left + Width && y >= Top && y < Top + Height;
}

/// <summary>
/// Zugriff auf die Symbolansicht des Desktops (oder – zum Testen – eines Explorer-Fensters)
/// über die Shell-Schnittstellen IShellWindows → IShellBrowser → IFolderView2.
/// Verschiebt KEINE Dateien, sondern setzt nur Symbolpositionen. Muss auf dem UI-Thread (STA) benutzt werden.
/// </summary>
public sealed class DesktopShellView : IDisposable
{
    private readonly IFolderView2 _view;
    private readonly IShellFolder _folder;
    private readonly IntPtr _hwnd;
    public bool IsDesktop { get; }

    private DesktopShellView(object browserDispatch, bool isDesktop)
    {
        IsDesktop = isDesktop;
        var sp = (Interop.IServiceProvider)browserDispatch;
        var sid = ShellNative.SID_STopLevelBrowser;
        var iid = ShellNative.IID_IShellBrowser;
        Check(sp.QueryService(ref sid, ref iid, out var pBrowser), "QueryService");
        var browser = (IShellBrowser)Marshal.GetObjectForIUnknown(pBrowser);
        Marshal.Release(pBrowser);
        Check(browser.QueryActiveShellView(out var pView), "QueryActiveShellView");
        var viewObj = Marshal.GetObjectForIUnknown(pView);
        Marshal.Release(pView);
        _view = (IFolderView2)viewObj;
        ((IShellView)viewObj).GetWindow(out _hwnd);
        var iidFolder = ShellNative.IID_IShellFolder;
        Check(_view.GetFolder(ref iidFolder, out var pFolder), "GetFolder");
        _folder = (IShellFolder)Marshal.GetObjectForIUnknown(pFolder);
        Marshal.Release(pFolder);
    }

    private static void Check(int hr, string what)
    {
        if (hr != 0) throw new InvalidOperationException($"Shell-Aufruf {what} fehlgeschlagen (0x{hr:X8}).");
    }

    /// <summary>Öffnet die Symbolansicht des echten Desktops.</summary>
    public static DesktopShellView OpenDesktop()
    {
        var sw = (IShellWindows)Activator.CreateInstance(Type.GetTypeFromCLSID(ShellNative.CLSID_ShellWindows)!)!;
        object loc = 0; // CSIDL_DESKTOP
        object root = null!;
        int hr = sw.FindWindowSW(ref loc, ref root, ShellNative.SWC_DESKTOP, out _, ShellNative.SWFO_NEEDDISPATCH, out var disp);
        if (hr != 0 || disp == null) throw new InvalidOperationException("Der Desktop (Explorer) wurde nicht gefunden. Läuft der Windows-Explorer?");
        return new DesktopShellView(disp, true);
    }

    /// <summary>Öffnet die Symbolansicht eines offenen Explorer-Fensters, das den angegebenen Ordner zeigt (für Tests).</summary>
    public static DesktopShellView? OpenExplorerWindow(string folderPath)
    {
        dynamic sw = Activator.CreateInstance(Type.GetTypeFromCLSID(ShellNative.CLSID_ShellWindows)!)!;
        int count = sw.Count;
        var want = ProtectionService.Normalize(folderPath);
        for (int i = 0; i < count; i++)
        {
            try
            {
                dynamic w = sw.Item(i);
                if (w == null) continue;
                string path = w.Document.Folder.Self.Path;
                if (string.Equals(ProtectionService.Normalize(path), want, StringComparison.OrdinalIgnoreCase))
                    return new DesktopShellView((object)w, false);
            }
            catch { /* Fenster ohne Ordner (z. B. Startseite) */ }
        }
        return null;
    }

    private string Name(IntPtr pidl, uint flags)
    {
        if (_folder.GetDisplayNameOf(pidl, flags, out var sr) != 0) return "";
        var sb = new StringBuilder(1024);
        return ShellNative.StrRetToBufW(ref sr, pidl, sb, (uint)sb.Capacity) == 0 ? sb.ToString() : "";
    }

    public List<ShellViewItem> GetItems()
    {
        var list = new List<ShellViewItem>();
        if (_view.ItemCount(ShellNative.SVGIO_ALLVIEW, out int n) != 0) return list;
        for (int i = 0; i < n; i++)
        {
            if (_view.Item(i, out var pidl) != 0 || pidl == IntPtr.Zero) continue;
            try
            {
                _view.GetItemPosition(pidl, out var pt);
                uint attrs = ShellNative.SFGAO_FILESYSTEM | ShellNative.SFGAO_FOLDER;
                _folder.GetAttributesOf(1, new[] { pidl }, ref attrs);
                list.Add(new ShellViewItem
                {
                    ParsingPath = Name(pidl, ShellNative.SHGDN_FORPARSING),
                    DisplayName = Name(pidl, ShellNative.SHGDN_NORMAL),
                    IsFileSystem = (attrs & ShellNative.SFGAO_FILESYSTEM) != 0,
                    IsFolder = (attrs & ShellNative.SFGAO_FOLDER) != 0,
                    X = pt.X, Y = pt.Y,
                });
            }
            finally { ShellNative.CoTaskMemFree(pidl); }
        }
        return list;
    }

    public POINT Spacing
    {
        get
        {
            _view.GetSpacing(out var p);
            if (p.X <= 0 || p.Y <= 0) _view.GetDefaultSpacing(out p);
            if (p.X <= 0 || p.Y <= 0) p = new POINT(100, 100);
            return p;
        }
    }

    public bool AutoArrange
    {
        get => _view.GetAutoArrange() == 0;
        set => _view.SetCurrentFolderFlags(ShellNative.FWF_AUTOARRANGE, value ? ShellNative.FWF_AUTOARRANGE : 0);
    }

    public bool SnapToGrid
    {
        get => _view.GetCurrentFolderFlags(out var f) == 0 && (f & ShellNative.FWF_SNAPTOGRID) != 0;
    }

    /// <summary>Stellt (nur für Test-Explorerfenster) die Ansicht auf große Symbole.</summary>
    public void UseIconView() => _view.SetCurrentViewMode(ShellNative.FVM_ICON);

    public uint ViewMode => _view.GetCurrentViewMode(out var m) == 0 ? m : 0;

    /// <summary>Monitore in Koordinaten der Symbolansicht. Beim Explorer-Fenster: dessen sichtbarer Bereich.</summary>
    public List<ViewMonitor> GetMonitors()
    {
        var result = new List<ViewMonitor>();
        if (!IsDesktop)
        {
            ShellNative.GetClientRect(_hwnd, out var rc);
            result.Add(new ViewMonitor
            {
                Left = 0, Top = 0, Width = rc.Right, Height = rc.Bottom,
                WorkLeft = 0, WorkTop = 0, WorkWidth = rc.Right, WorkHeight = rc.Bottom, IsPrimary = true,
            });
            return result;
        }

        ShellNative.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr h, IntPtr hdc, ref RECT r, IntPtr d) =>
        {
            var mi = new ShellNative.MONITORINFOEX { cbSize = Marshal.SizeOf<ShellNative.MONITORINFOEX>() };
            if (ShellNative.GetMonitorInfo(h, ref mi))
            {
                var tl = new POINT(mi.rcMonitor.Left, mi.rcMonitor.Top);
                var wtl = new POINT(mi.rcWork.Left, mi.rcWork.Top);
                ShellNative.ScreenToClient(_hwnd, ref tl);
                ShellNative.ScreenToClient(_hwnd, ref wtl);
                result.Add(new ViewMonitor
                {
                    Left = tl.X, Top = tl.Y,
                    Width = mi.rcMonitor.Right - mi.rcMonitor.Left, Height = mi.rcMonitor.Bottom - mi.rcMonitor.Top,
                    WorkLeft = wtl.X, WorkTop = wtl.Y,
                    WorkWidth = mi.rcWork.Right - mi.rcWork.Left, WorkHeight = mi.rcWork.Bottom - mi.rcWork.Top,
                    IsPrimary = (mi.dwFlags & 1) != 0,
                });
            }
            return true;
        }, IntPtr.Zero);
        return result.OrderByDescending(m => m.IsPrimary).ThenBy(m => m.Left).ToList();
    }

    /// <summary>Setzt Positionen (Schlüssel = Parsing-Pfad). Gibt zurück, wie viele Symbole positioniert wurden.</summary>
    public int Position(IReadOnlyDictionary<string, POINT> targets)
    {
        int done = 0;
        if (_view.ItemCount(ShellNative.SVGIO_ALLVIEW, out int n) != 0) return 0;
        for (int i = 0; i < n; i++)
        {
            if (_view.Item(i, out var pidl) != 0 || pidl == IntPtr.Zero) continue;
            try
            {
                var path = Name(pidl, ShellNative.SHGDN_FORPARSING);
                if (!targets.TryGetValue(path, out var pt)) continue;
                if (_view.SelectAndPositionItems(1, new[] { pidl }, new[] { pt }, ShellNative.SVSI_POSITIONITEM) == 0) done++;
            }
            finally { ShellNative.CoTaskMemFree(pidl); }
        }
        return done;
    }

    public void Dispose()
    {
        try { Marshal.ReleaseComObject(_folder); } catch { }
        try { Marshal.ReleaseComObject(_view); } catch { }
    }
}
