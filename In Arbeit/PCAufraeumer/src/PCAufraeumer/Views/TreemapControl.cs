using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using PCAufraeumer.Services;

namespace PCAufraeumer.Views;

/// <summary>
/// Kachelkarte der Speicherplatz-Seite: jede Kachel ist so groß wie ihr Platzbedarf.
/// Große Ordner zeigen ihren Inhalt eine Ebene tiefer gleich mit. Klick auf einen Ordner = hineinzoomen.
/// </summary>
public sealed class TreemapControl : FrameworkElement
{
    // Gedämpfte Töne passend zum Graphit-Design (funktionieren hell und dunkel, Text darauf dunkel).
    private static readonly Color[] Palette =
    {
        Color.FromRgb(0xD9, 0xA0, 0x45), Color.FromRgb(0x86, 0xB8, 0x6F), Color.FromRgb(0x74, 0x9C, 0xC4),
        Color.FromRgb(0xC9, 0x7F, 0x6B), Color.FromRgb(0x9C, 0x8A, 0xC0), Color.FromRgb(0x6F, 0xB3, 0xA6),
        Color.FromRgb(0xB8, 0xAE, 0x6A), Color.FromRgb(0xC2, 0x8F, 0xA8),
    };
    private static readonly Color FileColor = Color.FromRgb(0x9A, 0x95, 0x8C);
    private static readonly Color GroupColor = Color.FromRgb(0x6E, 0x69, 0x5F);
    private static readonly Brush LabelBrush = Frozen(new SolidColorBrush(Color.FromRgb(0x1A, 0x18, 0x14)));
    private static readonly Typeface Face = new(new FontFamily("Segoe UI Variable Text, Segoe UI"), FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal);
    private static readonly Typeface FaceSmall = new(new FontFamily("Segoe UI Variable Text, Segoe UI"), FontStyles.Normal, FontWeights.Normal, FontStretches.Normal);

    private readonly List<(DiskNode Node, Rect Rect)> _hits = new();
    private DiskNode? _hover;

    public static readonly DependencyProperty NodeProperty = DependencyProperty.Register(nameof(Node), typeof(DiskNode), typeof(TreemapControl),
        new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender));
    public DiskNode? Node { get => (DiskNode?)GetValue(NodeProperty); set => SetValue(NodeProperty, value); }

    /// <summary>Hintergrund (per DynamicResource gebunden → Design-Wechsel zeichnet neu).</summary>
    public static readonly DependencyProperty BackgroundProperty = DependencyProperty.Register(nameof(Background), typeof(Brush), typeof(TreemapControl),
        new FrameworkPropertyMetadata(Brushes.Transparent, FrameworkPropertyMetadataOptions.AffectsRender));
    public Brush Background { get => (Brush)GetValue(BackgroundProperty); set => SetValue(BackgroundProperty, value); }

    public static readonly DependencyProperty HoverNodeProperty = DependencyProperty.Register(nameof(HoverNode), typeof(DiskNode), typeof(TreemapControl),
        new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault));
    public DiskNode? HoverNode { get => (DiskNode?)GetValue(HoverNodeProperty); set => SetValue(HoverNodeProperty, value); }

    /// <summary>Wird beim Klick auf eine Kachel mit dem Eintrag aufgerufen.</summary>
    public static readonly DependencyProperty OpenCommandProperty = DependencyProperty.Register(nameof(OpenCommand), typeof(ICommand), typeof(TreemapControl));
    public ICommand? OpenCommand { get => (ICommand?)GetValue(OpenCommandProperty); set => SetValue(OpenCommandProperty, value); }

    public TreemapControl()
    {
        ClipToBounds = true;
        Cursor = Cursors.Hand;
    }

    private static Brush Frozen(Brush b) { b.Freeze(); return b; }

    protected override void OnRender(DrawingContext dc)
    {
        _hits.Clear();
        var bounds = new Rect(0, 0, ActualWidth, ActualHeight);
        dc.DrawRectangle(Background, null, bounds);
        var node = Node;
        if (node == null || node.Children.Count == 0 || bounds.Width < 4 || bounds.Height < 4) return;
        double dpi = VisualTreeHelper.GetDpi(this).PixelsPerDip;

        var layout = TreemapLayout.Compute(node.Children, n => n.Size, bounds);
        int ci = 0;
        foreach (var (child, r) in layout)
        {
            var baseColor = child.IsGroup ? GroupColor : child.IsDirectory ? Palette[ci++ % Palette.Length] : FileColor;
            DrawTile(dc, child, r, baseColor, dpi, level: 0);
        }
    }

    private void DrawTile(DrawingContext dc, DiskNode n, Rect r, Color color, double dpi, int level)
    {
        var inner = Inset(r, level == 0 ? 1.5 : 1);
        if (inner.Width < 1 || inner.Height < 1) return;
        bool hover = ReferenceEquals(n, _hover);
        var fill = new SolidColorBrush(hover ? Lighten(color, 0.18) : level == 0 ? color : Lighten(color, 0.10 * level));
        fill.Freeze();
        dc.DrawRoundedRectangle(fill, null, inner, level == 0 ? 3 : 2, level == 0 ? 3 : 2);
        _hits.Add((n, inner));

        // Großer Ordner: Kopfzeile mit Namen, darunter eine Ebene tiefer
        const double header = 20;
        bool nest = level == 0 && n.IsDirectory && !n.IsGroup && n.Children.Count > 0 && inner.Width > 140 && inner.Height > 90;
        if (nest)
        {
            DrawLabel(dc, n, new Rect(inner.X + 6, inner.Y + 3, inner.Width - 12, header - 4), dpi, oneLine: true);
            var area = new Rect(inner.X + 3, inner.Y + header, inner.Width - 6, inner.Height - header - 3);
            var shade = Darken(color, 0.18);
            var bg = new SolidColorBrush(shade); bg.Freeze();
            dc.DrawRoundedRectangle(bg, null, area, 2, 2);
            foreach (var (c, cr) in TreemapLayout.Compute(n.Children, x => x.Size, area))
                DrawTile(dc, c, cr, c.IsGroup ? Lighten(shade, 0.05) : c.IsDirectory ? Lighten(color, 0.06) : Lighten(shade, 0.22), dpi, level + 1);
            return;
        }
        if (inner.Width > 46 && inner.Height > 16)
            DrawLabel(dc, n, new Rect(inner.X + 5, inner.Y + 3, inner.Width - 10, inner.Height - 6), dpi, oneLine: inner.Height < 34);
    }

    private static void DrawLabel(DrawingContext dc, DiskNode n, Rect r, double dpi, bool oneLine)
    {
        if (r.Width < 10 || r.Height < 10) return;
        var name = new FormattedText(n.Name, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight, Face, 11.5, LabelBrush, dpi)
        {
            MaxTextWidth = r.Width, MaxLineCount = 1, Trimming = TextTrimming.CharacterEllipsis,
        };
        if (oneLine)
        {
            var both = new FormattedText($"{n.Name}  ·  {n.SizeText}", CultureInfo.CurrentUICulture, FlowDirection.LeftToRight, Face, 11.5, LabelBrush, dpi)
            {
                MaxTextWidth = r.Width, MaxLineCount = 1, Trimming = TextTrimming.CharacterEllipsis,
            };
            dc.DrawText(both, r.TopLeft);
            return;
        }
        dc.DrawText(name, r.TopLeft);
        var size = new FormattedText(n.SizeText, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight, FaceSmall, 11, LabelBrush, dpi)
        {
            MaxTextWidth = r.Width, MaxLineCount = 1, Trimming = TextTrimming.CharacterEllipsis,
        };
        if (r.Height > 30) dc.DrawText(size, new Point(r.X, r.Y + 15));
    }

    private DiskNode? HitTest(Point p)
    {
        // Innerste Kachel zuerst (wurde zuletzt gezeichnet)
        for (int i = _hits.Count - 1; i >= 0; i--)
            if (_hits[i].Rect.Contains(p)) return _hits[i].Node;
        return null;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        var n = HitTest(e.GetPosition(this));
        if (ReferenceEquals(n, _hover)) return;
        _hover = n;
        HoverNode = n;
        InvalidateVisual();
    }

    protected override void OnMouseLeave(MouseEventArgs e)
    {
        _hover = null;
        HoverNode = null;
        InvalidateVisual();
    }

    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
    {
        var n = HitTest(e.GetPosition(this));
        if (n == null) return;
        // Klick in einen verschachtelten Eintrag: Datei → deren Ordner öffnen
        var target = n.CanOpen ? n : n.Parent is { } p && !ReferenceEquals(p, Node) && p.CanOpen ? p : n;
        if (OpenCommand?.CanExecute(target) == true) OpenCommand.Execute(target);
    }

    protected override void OnRenderSizeChanged(SizeChangedInfo info)
    {
        base.OnRenderSizeChanged(info);
        InvalidateVisual();
    }

    private static Rect Inset(Rect r, double d) =>
        new(r.X + d / 2, r.Y + d / 2, Math.Max(0, r.Width - d), Math.Max(0, r.Height - d));

    private static Color Lighten(Color c, double f) => Color.FromRgb(
        (byte)(c.R + (255 - c.R) * f), (byte)(c.G + (255 - c.G) * f), (byte)(c.B + (255 - c.B) * f));

    private static Color Darken(Color c, double f) => Color.FromRgb((byte)(c.R * (1 - f)), (byte)(c.G * (1 - f)), (byte)(c.B * (1 - f)));
}
