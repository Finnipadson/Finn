using System.Collections.Concurrent;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Erzeugt Vorschaubilder über die Windows-Shell (wie im Explorer) auf einem eigenen STA-Thread.
/// Nur für sichtbare Zeilen (Lazy). OneDrive-„Nur online“-Dateien werden nie angefasst.
/// </summary>
public sealed class ThumbnailService : IDisposable
{
    private readonly BlockingCollection<FileCandidate> _queue = new();
    private readonly Thread _worker;

    public ThumbnailService()
    {
        _worker = new Thread(Work) { IsBackground = true, Name = "Vorschaubilder" };
        _worker.SetApartmentState(ApartmentState.STA);
        _worker.Start();
    }

    public void Request(FileCandidate c)
    {
        if (c.ThumbnailRequested) return;
        c.ThumbnailRequested = true;
        if (c.TypeLabel is not ("Video" or "Bild")) return;
        _queue.Add(c);
    }

    private void Work()
    {
        foreach (var c in _queue.GetConsumingEnumerable())
        {
            try
            {
                var img = Create(c.FullPath, 96);
                if (img != null) Application.Current?.Dispatcher.BeginInvoke(() => c.Thumbnail = img);
            }
            catch { /* kein Vorschaubild – Symbol bleibt */ }
        }
    }

    public static ImageSource? Create(string path, int size)
    {
        FileAttributes a;
        try { a = File.GetAttributes(path); } catch { return null; }
        if (ProtectionService.IsCloudOnly(a)) return null;

        return ProtectionService.PreserveAccessTime(path, () =>
        {
            NativeMethods.SHCreateItemFromParsingName(path, IntPtr.Zero, typeof(NativeMethods.IShellItemImageFactory).GUID, out var factory);
            try
            {
                var sz = new NativeMethods.SIZE { cx = size, cy = size };
                int hr = factory.GetImage(sz, NativeMethods.SIIGBF.BiggerSizeOk | NativeMethods.SIIGBF.ThumbnailOnly, out var hbmp);
                if (hr != 0 || hbmp == IntPtr.Zero) return null;
                try
                {
                    var src = Imaging.CreateBitmapSourceFromHBitmap(hbmp, IntPtr.Zero, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                    src.Freeze();
                    return (ImageSource)src;
                }
                finally { NativeMethods.DeleteObject(hbmp); }
            }
            finally { System.Runtime.InteropServices.Marshal.ReleaseComObject(factory); }
        });
    }

    public void Dispose() => _queue.CompleteAdding();
}
