using System.Runtime.InteropServices;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace PCAufraeumer.Services;

/// <summary>Echte Windows-Symbole (wie auf dem Desktop) inkl. Transparenz. Muss auf einem STA-Thread laufen.</summary>
public static class ShellIcons
{
    [StructLayout(LayoutKind.Sequential)]
    private struct BITMAP { public int bmType, bmWidth, bmHeight, bmWidthBytes; public ushort bmPlanes, bmBitsPixel; public IntPtr bmBits; }

    [StructLayout(LayoutKind.Sequential)]
    private struct BITMAPINFOHEADER
    {
        public int biSize, biWidth, biHeight; public ushort biPlanes, biBitCount;
        public uint biCompression, biSizeImage; public int biXPelsPerMeter, biYPelsPerMeter; public uint biClrUsed, biClrImportant;
    }

    [DllImport("gdi32.dll")] private static extern int GetObject(IntPtr h, int c, out BITMAP bm);
    [DllImport("gdi32.dll")] private static extern int GetDIBits(IntPtr hdc, IntPtr hbm, uint start, uint lines, byte[] bits, ref BITMAPINFOHEADER bmi, uint usage);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);

    private static readonly Dictionary<string, ImageSource?> Cache = new(StringComparer.OrdinalIgnoreCase);

    public static ImageSource? Get(string parsingPath, int size = 48)
    {
        var key = parsingPath + "|" + size;
        lock (Cache) if (Cache.TryGetValue(key, out var c)) return c;
        ImageSource? img = null;
        try
        {
            // Bei OneDrive-„Nur online“-Dateien nur das Symbol, kein Vorschaubild (würde sonst herunterladen).
            var flags = NativeMethods.SIIGBF.BiggerSizeOk;
            try
            {
                if (!parsingPath.StartsWith("::") && File.Exists(parsingPath) &&
                    ProtectionService.IsCloudOnly(File.GetAttributes(parsingPath)))
                    flags |= NativeMethods.SIIGBF.IconOnly;
            }
            catch { }
            NativeMethods.SHCreateItemFromParsingName(parsingPath, IntPtr.Zero, typeof(NativeMethods.IShellItemImageFactory).GUID, out var f);
            try
            {
                if (f.GetImage(new NativeMethods.SIZE { cx = size, cy = size }, flags, out var hbmp) == 0 && hbmp != IntPtr.Zero)
                {
                    try { img = ToBitmapSource(hbmp); }
                    finally { NativeMethods.DeleteObject(hbmp); }
                }
            }
            finally { Marshal.ReleaseComObject(f); }
        }
        catch { /* kein Symbol */ }
        lock (Cache) Cache[key] = img;
        return img;
    }

    private static ImageSource? ToBitmapSource(IntPtr hbmp)
    {
        if (GetObject(hbmp, Marshal.SizeOf<BITMAP>(), out var bm) == 0) return null;
        int w = bm.bmWidth, h = bm.bmHeight;
        var bmi = new BITMAPINFOHEADER
        {
            biSize = Marshal.SizeOf<BITMAPINFOHEADER>(), biWidth = w, biHeight = -h, // negativ = von oben nach unten
            biPlanes = 1, biBitCount = 32, biCompression = 0,
        };
        var bits = new byte[w * h * 4];
        var hdc = GetDC(IntPtr.Zero);
        try { if (GetDIBits(hdc, hbmp, 0, (uint)h, bits, ref bmi, 0) == 0) return null; }
        finally { ReleaseDC(IntPtr.Zero, hdc); }
        // 24-Bit-Bilder (Vorschaubilder ohne Alpha) haben Alpha = 0 → dann deckend darstellen.
        bool anyAlpha = false;
        for (int i = 3; i < bits.Length; i += 4) if (bits[i] != 0) { anyAlpha = true; break; }
        if (!anyAlpha) for (int i = 3; i < bits.Length; i += 4) bits[i] = 255;
        var src = BitmapSource.Create(w, h, 96, 96, PixelFormats.Pbgra32, null, bits, w * 4);
        src.Freeze();
        return src;
    }
}
