using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using LibVLCSharp.Shared;
using MediaPlayer = LibVLCSharp.Shared.MediaPlayer;
using LibVLCSharp.WPF;

namespace PCAufraeumer.Views;

/// <summary>Vollbild-Wiedergabe. Esc, Doppelklick oder F schließt; Leertaste = Pause; Pfeile = ±10 s.</summary>
public sealed class FullscreenVideoWindow : Window
{
    private readonly MediaPlayer _player;
    private readonly VideoView _view;
    public long LastTime { get; private set; }

    public FullscreenVideoWindow(LibVLC vlc, MediaPlayer player, string path, long startTime)
    {
        _player = player;
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        WindowState = WindowState.Maximized;
        Background = Brushes.Black;
        Title = "Vollbild";
        ShowInTaskbar = false;

        _view = new VideoView();
        Content = _view;

        Loaded += (_, _) =>
        {
            _view.MediaPlayer = _player;
            using var media = new Media(vlc, path, FromType.FromPath);
            _player.Play(media);
            if (startTime > 0) _player.Time = startTime;
            Activate();
            Focus();
        };
        PreviewKeyDown += OnKey;
        // Das Video liegt in einem eigenen Fenster-Handle → Tastatur über das Fenster abfangen.
        MouseDoubleClick += (_, _) => Close();
        Closing += (_, _) =>
        {
            LastTime = _player.Time;
            _player.Stop();
            _view.MediaPlayer = null;
        };
    }

    private void OnKey(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Escape:
            case Key.F:
                Close();
                break;
            case Key.Space:
                if (_player.IsPlaying) _player.Pause(); else _player.Play();
                break;
            case Key.Right:
                _player.Time = Math.Min(_player.Length, _player.Time + 10000);
                break;
            case Key.Left:
                _player.Time = Math.Max(0, _player.Time - 10000);
                break;
        }
        e.Handled = true;
    }
}
