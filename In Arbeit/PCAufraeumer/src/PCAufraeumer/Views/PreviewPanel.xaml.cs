using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using LibVLCSharp.Shared;
using MediaPlayer = LibVLCSharp.Shared.MediaPlayer;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;
using PCAufraeumer.Models;
using PCAufraeumer.Services;
using PCAufraeumer.ViewModels;

namespace PCAufraeumer.Views;

/// <summary>
/// Vorschau VOR der Freigabe: Videoplayer (LibVLC, spielt auch .mkv usw.), Bilder, Text, PDF (WebView2), sonst Dateiinfos.
/// Nach dem Ansehen wird das „Letzter Zugriff“-Datum zurückgesetzt, damit die Vorschau die Einstufung nicht verfälscht.
/// </summary>
public partial class PreviewPanel : UserControl
{
    public static readonly DependencyProperty ItemProperty = DependencyProperty.Register(
        nameof(Item), typeof(FileCandidate), typeof(PreviewPanel),
        new PropertyMetadata(null, (d, e) => ((PreviewPanel)d).OnItemChanged(e.NewValue as FileCandidate)));

    public FileCandidate? Item
    {
        get => (FileCandidate?)GetValue(ItemProperty);
        set => SetValue(ItemProperty, value);
    }

    private static readonly HashSet<string> TextExt = new(StringComparer.OrdinalIgnoreCase)
    {
        ".txt", ".log", ".md", ".csv", ".json", ".xml", ".ini", ".cfg", ".yml", ".yaml", ".html", ".htm", ".css",
        ".js", ".ts", ".cs", ".py", ".bat", ".ps1", ".sh", ".srt", ".nfo",
    };

    private static readonly HashSet<string> ImageExt = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tif", ".tiff", ".ico", ".heic", ".jfif",
    };

    private static LibVLC? _libVlc;
    private MediaPlayer? _player;
    private readonly DispatcherTimer _posTimer = new() { Interval = TimeSpan.FromMilliseconds(250) };
    private bool _dragging;
    private WebView2? _web;
    private int _loadToken;

    // Zugriffszeit der aktuell angezeigten Datei (wird beim Wechsel wiederhergestellt).
    private string? _accessPath;
    private DateTime _accessTime;

    public PreviewPanel()
    {
        InitializeComponent();
        _posTimer.Tick += (_, _) => UpdatePosition();
        Unloaded += (_, _) => StopVideo();
        Dispatcher.ShutdownStarted += (_, _) => { StopVideo(); RestoreAccessTime(); _player?.Dispose(); };
    }

    private ResultsViewModel? Vm => DataContext as ResultsViewModel;

    private async void OnItemChanged(FileCandidate? c)
    {
        int token = ++_loadToken;
        StopVideo();
        RestoreAccessTime();
        ResetAreas();

        if (c == null)
        {
            EmptyState.Visibility = Visibility.Visible;
            ContentArea.Visibility = Visibility.Collapsed;
            return;
        }
        EmptyState.Visibility = Visibility.Collapsed;
        ContentArea.Visibility = Visibility.Visible;

        TitleText.Text = c.Name;
        SubText.Text = $"{Format.Bytes(c.Size)} · {c.TypeLabel} · {c.CategoryLabel}";
        ReasonText.Text = c.Reason + $"  (Grundlage: {c.BasisLabel})";
        PathText.Text = c.FullPath;
        BtnKeepCopy.Visibility = c.Category == FindingCategory.Duplicates && !c.IsKeep && !c.IsDeleted ? Visibility.Visible : Visibility.Collapsed;
        BtnKeepFolder.Visibility = c.IsRecording && !c.IsDeleted ? Visibility.Visible : Visibility.Collapsed;
        BtnNever.IsEnabled = !c.IsDeleted;
        BtnOpen.IsEnabled = !c.IsDeleted;

        if (c.IsDeleted || !File.Exists(c.FullPath))
        {
            ShowInfo(c, "Diese Datei ist nicht mehr vorhanden (gelöscht oder verschoben).");
            return;
        }

        try
        {
            if (ProtectionService.IsCloudOnly(File.GetAttributes(c.FullPath)))
            {
                ShowInfo(c, "Nur online verfügbar (OneDrive) – wird für die Vorschau nicht heruntergeladen.");
                return;
            }
        }
        catch { }

        RememberAccessTime(c.FullPath);
        var ext = c.Extension;
        try
        {
            if (ScanService.VideoExtensions.Contains(ext)) await ShowVideoAsync(c, token);
            else if (ImageExt.Contains(ext)) await ShowImageAsync(c, token);
            else if (TextExt.Contains(ext)) await ShowTextAsync(c, token);
            else if (ext == ".pdf") await ShowPdfAsync(c, token);
            else ShowInfo(c, null);
        }
        catch (Exception ex)
        {
            ErrorLog.Write($"Vorschau fehlgeschlagen: {c.FullPath}", ex);
            ShowInfo(c, "Vorschau nicht möglich: " + ex.Message);
        }
    }

    private void ResetAreas()
    {
        MediaArea.Visibility = Visibility.Collapsed;
        PreviewImage.Source = null;
        Video.Visibility = Visibility.Collapsed;
        BigPlay.Visibility = Visibility.Collapsed;
        MediaMessage.Visibility = Visibility.Collapsed;
        VideoControls.Visibility = Visibility.Collapsed;
        TextPreview.Visibility = Visibility.Collapsed;
        TextPreview.Text = "";
        PdfHost.Visibility = Visibility.Collapsed;
        if (_web != null) { try { _web.Source = new Uri("about:blank"); } catch { } }
        InfoPanel.Visibility = Visibility.Collapsed;
        InfoStack.Children.Clear();
    }

    private void RememberAccessTime(string path)
    {
        try { _accessTime = File.GetLastAccessTimeUtc(path); _accessPath = path; }
        catch { _accessPath = null; }
    }

    private void RestoreAccessTime()
    {
        if (_accessPath == null) return;
        try { if (File.Exists(_accessPath)) File.SetLastAccessTimeUtc(_accessPath, _accessTime); } catch { }
        _accessPath = null;
    }

    // ───────────── Info ─────────────

    private void ShowInfo(FileCandidate c, string? message)
    {
        InfoPanel.Visibility = Visibility.Visible;
        void Row(string label, string value)
        {
            InfoStack.Children.Add(new TextBlock { Text = label, Style = (Style)FindResource("Label") });
            InfoStack.Children.Add(new TextBlock { Text = value, Style = (Style)FindResource("Value") });
        }
        InfoStack.Children.Add(new TextBlock
        {
            Text = (string)new Converters.TypeGlyph().Convert(c.TypeLabel, typeof(string), null!, null!),
            Style = (Style)FindResource("Icon"), FontSize = 36, Margin = new Thickness(0, 0, 0, 10),
            Foreground = (Brush)FindResource("TextMuted"),
        });
        if (message != null)
            InfoStack.Children.Add(new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) });
        Row("Dateityp", $"{c.TypeLabel} ({c.Extension})");
        Row("Größe", Format.Bytes(c.Size) + $" ({c.Size:N0} Bytes)");
        Row("Erstellt", c.Created.ToString("dd.MM.yyyy HH:mm"));
        Row("Zuletzt geändert", c.LastWrite.ToString("dd.MM.yyyy HH:mm"));
        Row("Zuletzt geöffnet", c.LastAccess.ToString("dd.MM.yyyy HH:mm"));
        if (c.Category == FindingCategory.Duplicates && c.Hash.Length > 0) Row("Inhalts-Hash (xxHash128)", c.Hash);
        if (message == null)
            InfoStack.Children.Add(new TextBlock
            {
                Text = "Für diesen Dateityp gibt es keine eingebaute Vorschau. Nutze „Im Explorer anzeigen“ oder „Mit Standardprogramm öffnen“.",
                Style = (Style)FindResource("Muted"), Margin = new Thickness(0, 12, 0, 0),
            });
    }

    // ───────────── Bild ─────────────

    private async Task ShowImageAsync(FileCandidate c, int token)
    {
        MediaArea.Visibility = Visibility.Visible;
        var path = c.FullPath;
        var img = await Task.Run(() => ProtectionService.PreserveAccessTime(path, () =>
        {
            try
            {
                var bi = new BitmapImage();
                bi.BeginInit();
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
                bi.DecodePixelWidth = 1000;
                bi.UriSource = new Uri(path);
                bi.EndInit();
                bi.Freeze();
                return (ImageSource?)bi;
            }
            catch
            {
                return ThumbnailService.Create(path, 512);
            }
        }));
        if (token != _loadToken) return;
        if (img == null) { MediaMessage.Text = "Bild kann nicht angezeigt werden."; MediaMessage.Visibility = Visibility.Visible; }
        PreviewImage.Source = img;
    }

    // ───────────── Text ─────────────

    private async Task ShowTextAsync(FileCandidate c, int token)
    {
        var path = c.FullPath;
        var text = await Task.Run(() => ProtectionService.PreserveAccessTime(path, () =>
        {
            const int max = 256 * 1024;
            using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            using var sr = new StreamReader(fs, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
            var buf = new char[max];
            int n = sr.ReadBlock(buf, 0, max);
            var s = new string(buf, 0, n);
            if (fs.Length > max) s += "\n\n… (gekürzt – nur der Anfang wird angezeigt)";
            return s;
        }));
        if (token != _loadToken) return;
        TextPreview.Text = text;
        TextPreview.Visibility = Visibility.Visible;
    }

    // ───────────── PDF ─────────────

    private async Task ShowPdfAsync(FileCandidate c, int token)
    {
        PdfHost.Visibility = Visibility.Visible;
        try
        {
            if (_web == null)
            {
                _web = new WebView2();
                PdfHost.Child = _web;
                var dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCAufraeumer", "WebView2");
                var env = await CoreWebView2Environment.CreateAsync(null, dataDir);
                await _web.EnsureCoreWebView2Async(env);
                _web.CoreWebView2.Settings.AreDevToolsEnabled = false;
                _web.CoreWebView2.Settings.IsStatusBarEnabled = false;
                // Nichts aus dem Internet laden – nur die lokale PDF-Datei.
                _web.CoreWebView2.AddWebResourceRequestedFilter("http*", CoreWebView2WebResourceContext.All);
                _web.CoreWebView2.WebResourceRequested += (_, e) =>
                    e.Response = _web.CoreWebView2.Environment.CreateWebResourceResponse(null, 403, "Blocked", "");
            }
            if (token != _loadToken) return;
            _web.Source = new Uri(c.FullPath);
        }
        catch (Exception ex)
        {
            PdfHost.Visibility = Visibility.Collapsed;
            ShowInfo(c, "PDF-Vorschau nicht verfügbar (Microsoft Edge WebView2 fehlt?): " + ex.Message);
        }
    }

    // ───────────── Video ─────────────

    private async Task ShowVideoAsync(FileCandidate c, int token)
    {
        MediaArea.Visibility = Visibility.Visible;
        VideoControls.Visibility = Visibility.Visible;
        BigPlay.Visibility = Visibility.Visible;
        PositionSlider.Value = 0;
        TimeText.Text = "0:00 / 0:00";
        PlayIcon.Text = "";
        var path = c.FullPath;
        var thumb = await Task.Run(() => { try { return ThumbnailService.Create(path, 640); } catch { return null; } });
        if (token != _loadToken) return;
        PreviewImage.Source = thumb;
    }

    private bool EnsurePlayer()
    {
        if (_player != null) return true;
        try
        {
            if (_libVlc == null)
            {
                Core.Initialize();
                _libVlc = new LibVLC("--no-video-title-show", "--quiet");
            }
            _player = new MediaPlayer(_libVlc)
            {
                Volume = (int)VolumeSlider.Value,
                // Maus/Tastatur an die App weiterreichen (Doppelklick/Esc im Vollbild).
                EnableKeyInput = false,
                EnableMouseInput = false,
            };
            _player.EndReached += (_, _) => Dispatcher.BeginInvoke(() =>
            {
                PlayIcon.Text = "";
                _posTimer.Stop();
                PositionSlider.Value = 0;
            });
            _player.EncounteredError += (_, _) => Dispatcher.BeginInvoke(() =>
            {
                MediaMessage.Text = "Dieses Video kann nicht abgespielt werden.";
                MediaMessage.Visibility = Visibility.Visible;
                Video.Visibility = Visibility.Collapsed;
            });
            Video.MediaPlayer = _player;
            return true;
        }
        catch (Exception ex)
        {
            ErrorLog.Write("Videoplayer (LibVLC) konnte nicht gestartet werden.", ex);
            MediaMessage.Text = "Videoplayer konnte nicht gestartet werden: " + ex.Message;
            MediaMessage.Visibility = Visibility.Visible;
            return false;
        }
    }

    private void Play_Click(object sender, RoutedEventArgs e) => StartVideo();

    private void StartVideo()
    {
        var c = Item;
        if (c == null || !EnsurePlayer()) return;
        BigPlay.Visibility = Visibility.Collapsed;
        PreviewImage.Source = null;
        Video.Visibility = Visibility.Visible;
        using var media = new Media(_libVlc!, c.FullPath, FromType.FromPath);
        _player!.Play(media);
        PlayIcon.Text = "";
        _posTimer.Start();
    }

    private void PlayPause_Click(object sender, RoutedEventArgs e)
    {
        if (_player == null || _player.Media == null || Video.Visibility != Visibility.Visible) { StartVideo(); return; }
        if (_player.IsPlaying) { _player.Pause(); PlayIcon.Text = ""; }
        else if (_player.State == VLCState.Ended || _player.State == VLCState.Stopped) StartVideo();
        else { _player.Play(); PlayIcon.Text = ""; _posTimer.Start(); }
    }

    private void StopVideo()
    {
        _posTimer.Stop();
        if (_player != null)
        {
            try { if (_player.IsPlaying || _player.State == VLCState.Paused) _player.Stop(); } catch { }
        }
    }

    private void UpdatePosition()
    {
        if (_player == null || _dragging) return;
        PositionSlider.Value = Math.Clamp(_player.Position, 0, 1);
        TimeText.Text = $"{Fmt(_player.Time)} / {Fmt(_player.Length)}";
    }

    private static string Fmt(long ms)
    {
        if (ms <= 0) return "0:00";
        var t = TimeSpan.FromMilliseconds(ms);
        return t.TotalHours >= 1 ? t.ToString(@"h\:mm\:ss") : t.ToString(@"m\:ss");
    }

    private void Position_MouseDown(object sender, MouseButtonEventArgs e) => _dragging = true;

    private void Position_MouseUp(object sender, MouseButtonEventArgs e)
    {
        _dragging = false;
        if (_player is { IsSeekable: true }) _player.Position = (float)PositionSlider.Value;
    }

    private void Volume_Changed(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_player != null) _player.Volume = (int)e.NewValue;
    }

    private void Mute_Click(object sender, RoutedEventArgs e)
    {
        if (_player == null) return;
        _player.Mute = !_player.Mute;
        MuteIcon.Text = _player.Mute ? "" : "";
    }

    private void Fullscreen_Click(object sender, RoutedEventArgs e)
    {
        if (_player == null || Video.Visibility != Visibility.Visible) StartVideo();
        if (_player == null || Item == null) return;
        var path = Item.FullPath;
        long time = _player.Time;
        bool wasPlaying = _player.IsPlaying || _player.State == VLCState.Opening || _player.State == VLCState.Buffering;
        _player.Stop();
        Video.MediaPlayer = null;
        _posTimer.Stop();

        var win = new FullscreenVideoWindow(_libVlc!, _player, path, time) { Owner = Window.GetWindow(this) };
        win.ShowDialog();

        // Zurück in die Vorschau
        long back = win.LastTime;
        _player.Stop();
        Video.MediaPlayer = _player;
        if (wasPlaying || back > 0)
        {
            using var media = new Media(_libVlc!, path, FromType.FromPath);
            _player.Play(media);
            if (back > 0) _player.Time = back;
            PlayIcon.Text = "";
            _posTimer.Start();
        }
    }

    // ───────────── Aktionen ─────────────

    private void Explorer_Click(object sender, RoutedEventArgs e) { if (Item != null) Shell.ShowInExplorer(Item.FullPath); }

    private void OpenDefault_Click(object sender, RoutedEventArgs e)
    {
        if (Item == null) return;
        StopVideo();
        Shell.Open(Item.FullPath);
    }

    private void KeepCopy_Click(object sender, RoutedEventArgs e)
    {
        var c = Item;
        if (c == null) return;
        Vm?.KeepThisCopyCommand.Execute(c);
        OnItemChanged(c);
    }

    private void Never_Click(object sender, RoutedEventArgs e)
    {
        var c = Item;
        if (c == null) return;
        StopVideo();
        RestoreAccessTime();
        Vm?.NeverSuggestCommand.Execute(c);
    }

    private void KeepFolder_Click(object sender, RoutedEventArgs e)
    {
        var c = Item;
        if (c == null) return;
        StopVideo();          // VLC gibt die Datei frei
        RestoreAccessTime();
        Vm?.MoveOneToKeepCommand.Execute(c);
    }

    private void ExcludeFolder_Click(object sender, RoutedEventArgs e)
    {
        var c = Item;
        if (c == null) return;
        StopVideo();
        Vm?.ExcludeFolderCommand.Execute(c);
    }
}
