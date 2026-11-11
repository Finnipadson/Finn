using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Automation;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.ViewModels;

namespace PCAufraeumer.Views;

public partial class DesktopView : UserControl
{
    private DesktopViewModel? _vm;
    private Point _dragStart;

    public DesktopView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) =>
        {
            if (_vm != null) _vm.PreviewChanged -= OnPreviewChanged;
            _vm = DataContext as DesktopViewModel;
            if (_vm != null) { _vm.PreviewChanged += OnPreviewChanged; OnPreviewChanged(null, EventArgs.Empty); }
        };
    }

    private void OnPreviewChanged(object? sender, EventArgs e)
    {
        if (_vm == null) return;
        DesktopRenderer.Render(BeforeCanvas, _vm, after: false, this);
        DesktopRenderer.Render(AfterCanvas, _vm, after: true, this);
        RenderLayoutCards(LayoutPanel, 54);
    }

    /// <summary>Karten mit den Anordnungs-Vorschlägen (Mini-Vorschau + Name). Klick wählt den Vorschlag.</summary>
    private void RenderLayoutCards(Panel target, double previewHeight)
    {
        if (_vm == null) return;
        target.Children.Clear();
        foreach (var card in _vm.LayoutCards)
        {
            var canvas = new Canvas();
            DesktopRenderer.Render(canvas, _vm, card.Icons, card.Groups, null, mini: true);
            var title = new TextBlock { FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 4, 0, 0), TextTrimming = TextTrimming.CharacterEllipsis };
            title.Inlines.Add(card.Option.Name);
            if (!card.Fits)
                title.Inlines.Add(new System.Windows.Documents.Run("  · passt nicht ganz") { Foreground = (Brush)FindResource("Warn"), FontWeight = FontWeights.Normal, FontSize = 11 });
            var border = new Border
            {
                Margin = new Thickness(0, 0, 10, 0), Padding = new Thickness(8, 6, 8, 6), CornerRadius = new CornerRadius(10), Cursor = Cursors.Hand,
                Background = (Brush)FindResource(card.IsSelected ? "AccentSoft" : "CardBg"),
                BorderBrush = (Brush)FindResource(card.IsSelected ? "Accent" : "Border"),
                BorderThickness = new Thickness(card.IsSelected ? 2 : 1),
                ToolTip = card.Option.Description,
                Child = new StackPanel
                {
                    Children =
                    {
                        new Viewbox { Height = previewHeight, Stretch = Stretch.Uniform, Child = canvas },
                        title,
                    },
                },
            };
            var layout = card.Option.Layout;
            border.MouseLeftButtonUp += (_, _) => _vm.SelectLayoutCommand.Execute(layout);
            AutomationProperties.SetName(border, "Vorschlag " + card.Option.Name);
            target.Children.Add(border);
        }
    }

    // ── Drag & Drop in der Nachher-Ansicht ──
    internal void IconMouseDown(object sender, MouseButtonEventArgs e) => _dragStart = e.GetPosition(this);

    internal void IconMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || sender is not FrameworkElement fe || fe.Tag is not DesktopChange c) return;
        var p = e.GetPosition(this);
        if (Math.Abs(p.X - _dragStart.X) < 4 && Math.Abs(p.Y - _dragStart.Y) < 4) return;
        DragDrop.DoDragDrop(fe, c, DragDropEffects.Move);
    }

    private void AfterCanvas_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(typeof(DesktopChange)) && GroupAt(e.GetPosition(AfterCanvas)) != null
            ? DragDropEffects.Move : DragDropEffects.None;
        e.Handled = true;
    }

    private void AfterCanvas_Drop(object sender, DragEventArgs e)
    {
        if (_vm == null || e.Data.GetData(typeof(DesktopChange)) is not DesktopChange c) return;
        var g = GroupAt(e.GetPosition(AfterCanvas));
        if (g != null) _vm.MoveToGroup(c, g.Name);
    }

    private PreviewGroup? GroupAt(Point canvasPoint)
    {
        if (_vm == null) return null;
        var (minX, minY, _, _) = DesktopRenderer.Extent(_vm);
        double x = canvasPoint.X + minX, y = canvasPoint.Y + minY;
        return _vm.AfterGroups.Where(g => g.IsCategory)
            .FirstOrDefault(g => x >= g.X && x < g.X + g.Width && y >= g.Y - _vm.Spacing.Y && y < g.Y + g.Height + _vm.Spacing.Y);
    }

    internal ContextMenu CategoryMenu(DesktopChange c)
    {
        var menu = new ContextMenu();
        foreach (var cat in _vm?.Categories ?? Array.Empty<string>())
        {
            var mi = new MenuItem { Header = cat, IsChecked = cat == c.Target };
            mi.Click += (_, _) => _vm?.MoveToGroup(c, cat);
            menu.Items.Add(mi);
        }
        return menu;
    }

    private void ZoomBefore_Click(object sender, RoutedEventArgs e) => ShowLarge(false);
    private void ZoomAfter_Click(object sender, RoutedEventArgs e) => ShowLarge(true);

    /// <summary>Große Ansicht. Bei „Nachher“ stehen die Vorschläge oben – Wechseln geht, ohne das Fenster zu schließen.</summary>
    private void ShowLarge(bool after)
    {
        if (_vm == null) return;
        var vm = _vm;
        var canvas = new Canvas();
        var root = new DockPanel { Margin = new Thickness(16) };
        UniformGrid? cards = null;
        if (after)
        {
            cards = new UniformGrid { Rows = 1, Margin = new Thickness(0, 0, 0, 12) };
            DockPanel.SetDock(cards, Dock.Top);
            root.Children.Add(cards);
        }
        root.Children.Add(new Viewbox { Child = canvas, Stretch = Stretch.Uniform });

        void Redraw()
        {
            DesktopRenderer.Render(canvas, vm, after, null);
            if (cards != null) RenderLayoutCards(cards, 80);
        }
        Redraw();
        EventHandler onChanged = (_, _) => Redraw();
        vm.PreviewChanged += onChanged;

        var w = new Window
        {
            Title = after ? "Nachher – geplant (Vorschlag oben wählen, Esc schließt)" : "Vorher – dein Desktop jetzt",
            Owner = Window.GetWindow(this), WindowState = WindowState.Maximized,
            Background = (Brush)FindResource("WindowBg"), Foreground = (Brush)FindResource("Text"),
            Content = root,
        };
        w.SourceInitialized += (_, _) => ThemeManager.ApplyTitleBar(w);
        w.KeyDown += (_, k) => { if (k.Key == Key.Escape) w.Close(); };
        w.Closed += (_, _) => vm.PreviewChanged -= onChanged;
        w.ShowDialog();
    }
}

/// <summary>Zeichnet einen verkleinerten Desktop (Monitore, Gruppen, echte Symbole mit Namen).</summary>
internal static class DesktopRenderer
{
    private static ImageSource? _folderIcon;

    /// <summary>Sichtbarer Ausschnitt: nur der Bereich mit Symbolen (+ Rand), damit die Vorschau groß genug bleibt.</summary>
    public static (int minX, int minY, int maxX, int maxY) Extent(DesktopViewModel vm, IReadOnlyList<PreviewIcon>? after = null)
    {
        int sx = vm.Spacing.X, sy = vm.Spacing.Y;
        // Vorher und Nachher mit demselben Ausschnitt, damit man sie vergleichen kann.
        var all = vm.BeforeIcons.Concat(after ?? vm.AfterIcons).ToList();
        if (all.Count == 0)
        {
            var mons = vm.Monitors;
            if (mons.Count == 0) return (0, 0, 1920, 1080);
            return (mons.Min(m => m.Left), mons.Min(m => m.Top), mons.Max(m => m.Left + m.Width), mons.Max(m => m.Top + m.Height));
        }
        int minX = all.Min(i => i.X) - sx / 2, minY = all.Min(i => i.Y) - 48; // Platz für die Gruppen-Etiketten
        int maxX = all.Max(i => i.X) + sx + sx / 2, maxY = all.Max(i => i.Y) + sy + sy / 2;
        return (minX, minY, maxX, maxY);
    }

    public static void Render(Canvas canvas, DesktopViewModel vm, bool after, DesktopView? owner) =>
        Render(canvas, vm, after ? vm.AfterIcons : vm.BeforeIcons, after ? vm.AfterGroups : null, owner, mini: false);

    /// <param name="mini">Kleine Vorschlags-Karte: nur Symbole und Gruppenflächen, keine Texte.</param>
    public static void Render(Canvas canvas, DesktopViewModel vm, IReadOnlyList<PreviewIcon> icons,
        IReadOnlyList<PreviewGroup>? groups, DesktopView? owner, bool mini)
    {
        canvas.Children.Clear();
        var (minX, minY, maxX, maxY) = Extent(vm, groups != null ? icons : null);
        canvas.Width = Math.Max(100, maxX - minX);
        canvas.Height = Math.Max(100, maxY - minY);
        canvas.ClipToBounds = true;
        int sx = vm.Spacing.X, sy = vm.Spacing.Y;

        // Monitore als „Bildschirme“ mit dunklem Hintergrund (Text immer lesbar, egal ob Hell/Dunkel-Design)
        foreach (var m in vm.Monitors)
        {
            var b = new Border
            {
                Width = m.Width, Height = m.Height, CornerRadius = new CornerRadius(18),
                Background = new LinearGradientBrush(Color.FromRgb(0x2A, 0x28, 0x25), Color.FromRgb(0x14, 0x13, 0x12), 90),
                BorderBrush = new SolidColorBrush(Color.FromRgb(0x4A, 0x46, 0x40)), BorderThickness = new Thickness(6),
            };
            Canvas.SetLeft(b, m.Left - minX);
            Canvas.SetTop(b, m.Top - minY);
            canvas.Children.Add(b);
            if (vm.Monitors.Count > 1 && !mini)
            {
                var label = new TextBlock
                {
                    Text = m.IsPrimary ? "Hauptmonitor" : "Weiterer Monitor", FontSize = 34, Opacity = 0.35,
                    Foreground = Brushes.White,
                };
                Canvas.SetLeft(label, m.Left - minX + 24);
                Canvas.SetTop(label, m.Top - minY + m.Height - 70);
                canvas.Children.Add(label);
            }
        }

        foreach (var g in groups ?? Array.Empty<PreviewGroup>())
        {
            var accent = g.IsCategory ? Color.FromArgb(0x30, 0xE0, 0xA4, 0x3A) : Color.FromArgb(0x30, 0x86, 0xB8, 0x6F);
            var r = new Border
            {
                Width = g.Width - 6, Height = g.Height, CornerRadius = new CornerRadius(12),
                Background = new SolidColorBrush(mini ? Color.FromArgb(0x60, accent.R, accent.G, accent.B) : accent),
                BorderBrush = new SolidColorBrush(Color.FromArgb(0x90, accent.R, accent.G, accent.B)), BorderThickness = new Thickness(mini ? 8 : 3),
            };
            Canvas.SetLeft(r, g.X - minX - 3);
            Canvas.SetTop(r, g.Y - minY - 4);
            canvas.Children.Add(r);
            if (mini) continue;
            // Beschriftung als „Etikett“ über der Gruppe (verdeckt keine Symbole)
            var t = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(0xE6, accent.R, accent.G, accent.B)),
                CornerRadius = new CornerRadius(8), Padding = new Thickness(10, 2, 10, 4),
                MaxWidth = Math.Max(g.Width + sx * Math.Max(0, vm.GapColumns) - 10, sx * 2),
                ToolTip = g.Name,
                Child = new TextBlock
                {
                    Text = g.Name, FontSize = 22, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(0x1A, 0x18, 0x14)),
                    TextTrimming = TextTrimming.CharacterEllipsis,
                },
            };
            Canvas.SetLeft(t, g.X - minX - 3);
            Canvas.SetTop(t, g.Y - minY - 40);
            Panel.SetZIndex(t, 10);
            canvas.Children.Add(t);
        }

        var iconByPath = vm.Changes.Select(c => c.Item)
            .GroupBy(i => i.Path, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First().Icon, StringComparer.OrdinalIgnoreCase);
        bool interactive = groups != null && owner != null && !mini;

        foreach (var ic in icons)
        {
            if (!iconByPath.TryGetValue(ic.Path, out var img) || img == null)
                img = ic.IsNewFolder ? (_folderIcon ??= ShellIcons.Get(Path.GetTempPath(), 48)) : ShellIcons.Get(ic.Path, 48);
            if (mini)
            {
                var im = new Image { Source = img, Width = 64, Height = 64 };
                Canvas.SetLeft(im, ic.X - minX + (sx - 64) / 2);
                Canvas.SetTop(im, ic.Y - minY + 4);
                canvas.Children.Add(im);
                continue;
            }
            var panel = new StackPanel { Width = sx - 4, Cursor = interactive && ic.Change?.IsAppIcon == true ? Cursors.Hand : Cursors.Arrow };
            panel.Children.Add(new Image { Source = img, Width = 48, Height = 48, Margin = new Thickness(0, 4, 0, 2) });
            panel.Children.Add(new TextBlock
            {
                Text = ic.Name + (ic.IsNewFolder ? " (neu)" : ""), Foreground = Brushes.White, FontSize = 13,
                TextAlignment = TextAlignment.Center, TextWrapping = TextWrapping.Wrap, MaxHeight = 36, TextTrimming = TextTrimming.CharacterEllipsis,
                Effect = new DropShadowEffect { ShadowDepth = 1, BlurRadius = 3, Opacity = 0.9 },
            });
            panel.ToolTip = ic.Name + (ic.Change != null ? "\n" + ic.Change.Description : "");
            if (interactive && ic.Change is { IsAppIcon: true } ch)
            {
                panel.Tag = ch;
                panel.Background = Brushes.Transparent; // trifft Mausklicks auch zwischen Bild und Text
                panel.PreviewMouseLeftButtonDown += owner!.IconMouseDown;
                panel.PreviewMouseMove += owner.IconMouseMove;
                panel.ContextMenu = owner.CategoryMenu(ch);
            }
            Canvas.SetLeft(panel, ic.X - minX + 2);
            Canvas.SetTop(panel, ic.Y - minY);
            canvas.Children.Add(panel);
        }
    }
}
