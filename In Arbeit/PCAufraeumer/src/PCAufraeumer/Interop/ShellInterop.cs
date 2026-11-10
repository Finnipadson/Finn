using System.Runtime.InteropServices;
using System.Text;

namespace PCAufraeumer.Interop;

// COM-Schnittstellen der Windows-Shell für das Anordnen von Desktop-Symbolen.
// Reihenfolge der Methoden = Reihenfolge in der VTable (nicht ändern!).

[StructLayout(LayoutKind.Sequential)]
public struct POINT { public int X; public int Y; public POINT(int x, int y) { X = x; Y = y; } }

[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left, Top, Right, Bottom; }

[ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IServiceProvider
{
    [PreserveSig] int QueryService(ref Guid guidService, ref Guid riid, out IntPtr ppvObject);
}

[ComImport, Guid("000214E2-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellBrowser
{
    [PreserveSig] int GetWindow(out IntPtr phwnd);
    [PreserveSig] int ContextSensitiveHelp(int fEnterMode);
    [PreserveSig] int InsertMenusSB(IntPtr a, IntPtr b);
    [PreserveSig] int SetMenuSB(IntPtr a, IntPtr b, IntPtr c);
    [PreserveSig] int RemoveMenusSB(IntPtr a);
    [PreserveSig] int SetStatusTextSB(IntPtr a);
    [PreserveSig] int EnableModelessSB(int a);
    [PreserveSig] int TranslateAcceleratorSB(IntPtr a, ushort b);
    [PreserveSig] int BrowseObject(IntPtr a, uint b);
    [PreserveSig] int GetViewStateStream(uint a, out IntPtr b);
    [PreserveSig] int GetControlWindow(uint a, out IntPtr b);
    [PreserveSig] int SendControlMsg(uint a, uint b, IntPtr c, IntPtr d, out IntPtr e);
    [PreserveSig] int QueryActiveShellView(out IntPtr ppshv);
}

[ComImport, Guid("000214E3-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellView
{
    [PreserveSig] int GetWindow(out IntPtr phwnd);
}

[ComImport, Guid("cde725b0-ccc9-4519-917e-325d72fab4ce"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFolderView
{
    [PreserveSig] int GetCurrentViewMode(out uint pViewMode);
    [PreserveSig] int SetCurrentViewMode(uint viewMode);
    [PreserveSig] int GetFolder(ref Guid riid, out IntPtr ppv);
    [PreserveSig] int Item(int iItemIndex, out IntPtr ppidl);
    [PreserveSig] int ItemCount(uint uFlags, out int pcItems);
    [PreserveSig] int Items(uint uFlags, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int GetSelectionMarkedItem(out int piItem);
    [PreserveSig] int GetFocusedItem(out int piItem);
    [PreserveSig] int GetItemPosition(IntPtr pidl, out POINT ppt);
    [PreserveSig] int GetSpacing(out POINT ppt);
    [PreserveSig] int GetDefaultSpacing(out POINT ppt);
    [PreserveSig] int GetAutoArrange();
    [PreserveSig] int SelectItem(int iItem, uint dwFlags);
    [PreserveSig] int SelectAndPositionItems(uint cidl, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl,
        [MarshalAs(UnmanagedType.LPArray)] POINT[] apt, uint dwFlags);
}

[ComImport, Guid("1af3a467-214f-4298-908e-06b03e0b39f9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IFolderView2
{
    // IFolderView
    [PreserveSig] int GetCurrentViewMode(out uint pViewMode);
    [PreserveSig] int SetCurrentViewMode(uint viewMode);
    [PreserveSig] int GetFolder(ref Guid riid, out IntPtr ppv);
    [PreserveSig] int Item(int iItemIndex, out IntPtr ppidl);
    [PreserveSig] int ItemCount(uint uFlags, out int pcItems);
    [PreserveSig] int Items(uint uFlags, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int GetSelectionMarkedItem(out int piItem);
    [PreserveSig] int GetFocusedItem(out int piItem);
    [PreserveSig] int GetItemPosition(IntPtr pidl, out POINT ppt);
    [PreserveSig] int GetSpacing(out POINT ppt);
    [PreserveSig] int GetDefaultSpacing(out POINT ppt);
    [PreserveSig] int GetAutoArrange();
    [PreserveSig] int SelectItem(int iItem, uint dwFlags);
    [PreserveSig] int SelectAndPositionItems(uint cidl, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl,
        [MarshalAs(UnmanagedType.LPArray)] POINT[] apt, uint dwFlags);
    // IFolderView2 (nur bis GetCurrentFolderFlags benötigt)
    [PreserveSig] int SetGroupBy(IntPtr key, int fAscending);
    [PreserveSig] int GetGroupBy(IntPtr pkey, out int pfAscending);
    [PreserveSig] int SetViewProperty(IntPtr pidl, IntPtr propkey, IntPtr propvar);
    [PreserveSig] int GetViewProperty(IntPtr pidl, IntPtr propkey, IntPtr ppropvar);
    [PreserveSig] int SetTileViewProperties(IntPtr pidl, IntPtr pszPropList);
    [PreserveSig] int SetExtendedTileViewProperties(IntPtr pidl, IntPtr pszPropList);
    [PreserveSig] int SetText(int iType, IntPtr pwszText);
    [PreserveSig] int SetCurrentFolderFlags(uint dwMask, uint dwFlags);
    [PreserveSig] int GetCurrentFolderFlags(out uint pdwFlags);
}

[ComImport, Guid("000214E6-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellFolder
{
    [PreserveSig] int ParseDisplayName(IntPtr hwnd, IntPtr pbc, [MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr pchEaten, out IntPtr ppidl, IntPtr pdwAttributes);
    [PreserveSig] int EnumObjects(IntPtr hwnd, int grfFlags, out IntPtr ppenumIDList);
    [PreserveSig] int BindToObject(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int BindToStorage(IntPtr pidl, IntPtr pbc, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int CompareIDs(IntPtr lParam, IntPtr pidl1, IntPtr pidl2);
    [PreserveSig] int CreateViewObject(IntPtr hwndOwner, ref Guid riid, out IntPtr ppv);
    [PreserveSig] int GetAttributesOf(uint cidl, [MarshalAs(UnmanagedType.LPArray)] IntPtr[] apidl, ref uint rgfInOut);
    [PreserveSig] int GetUIObjectOf(IntPtr hwndOwner, uint cidl, IntPtr apidl, ref Guid riid, IntPtr rgfReserved, out IntPtr ppv);
    [PreserveSig] int GetDisplayNameOf(IntPtr pidl, uint uFlags, out STRRET pName);
    [PreserveSig] int SetNameOf(IntPtr hwnd, IntPtr pidl, [MarshalAs(UnmanagedType.LPWStr)] string name, uint uFlags, out IntPtr ppidlOut);
}

[ComImport, Guid("85CB6900-4D95-11CF-960C-0080C7F4EE85"), InterfaceType(ComInterfaceType.InterfaceIsDual)]
public interface IShellWindows
{
    [PreserveSig] int get_Count(out int count);
    [PreserveSig] int Item(object index, [MarshalAs(UnmanagedType.IDispatch)] out object folder);
    [PreserveSig] int _NewEnum(out IntPtr ppunk);
    [PreserveSig] int Register(IntPtr a, int b, int c, out int d);
    [PreserveSig] int RegisterPending(int a, IntPtr b, IntPtr c, int d, out int e);
    [PreserveSig] int Revoke(int a);
    [PreserveSig] int OnNavigate(int a, IntPtr b);
    [PreserveSig] int OnActivated(int a, int b);
    [PreserveSig] int FindWindowSW([In, MarshalAs(UnmanagedType.Struct)] ref object pvarloc,
        [In, MarshalAs(UnmanagedType.Struct)] ref object pvarlocRoot, int swClass, out int phwnd, int swfwOptions,
        [MarshalAs(UnmanagedType.IDispatch)] out object ppdispOut);
}

[StructLayout(LayoutKind.Explicit, Size = 272)]
public struct STRRET
{
    [FieldOffset(0)] public uint uType;
    [FieldOffset(8)] public IntPtr pOleStr;
}

// ── Verknüpfungen (.lnk) ──
[ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellLinkW
{
    [PreserveSig] int GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, uint fFlags);
    [PreserveSig] int GetIDList(out IntPtr ppidl);
    [PreserveSig] int SetIDList(IntPtr pidl);
    [PreserveSig] int GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
    [PreserveSig] int SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
    [PreserveSig] int GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
    [PreserveSig] int SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
    [PreserveSig] int GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
    [PreserveSig] int SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
    [PreserveSig] int GetHotkey(out ushort pwHotkey);
    [PreserveSig] int SetHotkey(ushort wHotkey);
    [PreserveSig] int GetShowCmd(out int piShowCmd);
    [PreserveSig] int SetShowCmd(int iShowCmd);
    [PreserveSig] int GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
    [PreserveSig] int SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
    [PreserveSig] int SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
    [PreserveSig] int Resolve(IntPtr hwnd, uint fFlags);
    [PreserveSig] int SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}

[ComImport, Guid("0000010b-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPersistFile
{
    [PreserveSig] int GetClassID(out Guid pClassID);
    [PreserveSig] int IsDirty();
    [PreserveSig] int Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
    [PreserveSig] int Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, int fRemember);
    [PreserveSig] int SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
    [PreserveSig] int GetCurFile(out IntPtr ppszFileName);
}

[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
public class ShellLinkCoClass { }

public static class ShellNative
{
    public static readonly Guid CLSID_ShellWindows = new("9BA05972-F6A8-11CF-A442-00A0C90A8F39");
    public static readonly Guid SID_STopLevelBrowser = new("4C96BE40-915C-11CF-99D3-00AA004AE837");
    public static readonly Guid IID_IShellBrowser = typeof(IShellBrowser).GUID;
    public static readonly Guid IID_IShellFolder = typeof(IShellFolder).GUID;

    public const int SWC_DESKTOP = 8;
    public const int SWFO_NEEDDISPATCH = 1;
    public const uint SVGIO_ALLVIEW = 2;
    public const uint SVSI_POSITIONITEM = 0x80;
    public const uint FWF_AUTOARRANGE = 0x1;
    public const uint FWF_SNAPTOGRID = 0x4;
    public const uint SHGDN_NORMAL = 0;
    public const uint SHGDN_INFOLDER = 1;
    public const uint SHGDN_FORPARSING = 0x8000;
    public const uint SFGAO_FILESYSTEM = 0x40000000;
    public const uint SFGAO_FOLDER = 0x20000000;
    public const uint FVM_ICON = 1;

    [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
    public static extern int StrRetToBufW(ref STRRET pstr, IntPtr pidl, StringBuilder pszBuf, uint cchBuf);

    [DllImport("ole32.dll")]
    public static extern void CoTaskMemFree(IntPtr pv);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, ref RECT rc, IntPtr data);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct MONITORINFOEX
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr hwnd);
}
