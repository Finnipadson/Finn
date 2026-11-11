using System.Globalization;
using System.Windows;
using System.Windows.Data;
using PCAufraeumer.Services;

namespace PCAufraeumer.Converters;

public sealed class BoolToVisibility : IValueConverter
{
    public bool Invert { get; set; }
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        (value is true) ^ Invert ? Visibility.Visible : Visibility.Collapsed;
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class InverseBool : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value is not true;
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => value is not true;
}

public sealed class NullToVisibility : IValueConverter
{
    public bool Invert { get; set; }
    public object Convert(object? value, Type t, object p, CultureInfo c)
    {
        bool has = value != null && !(value is string s && s.Length == 0);
        return has ^ Invert ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class BytesConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value switch
    {
        long l => Format.Bytes(l),
        int i => Format.Bytes(i),
        double d => Format.Bytes((long)d),
        _ => "",
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class DateConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is DateTime d && d.Year > 1601 ? d.ToString("dd.MM.yyyy HH:mm", CultureInfo.GetCultureInfo("de-DE")) : "–";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

/// <summary>Navigation: RadioButton.IsChecked ↔ aktuelle Seite.</summary>
public sealed class EqualsConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => Equals(value?.ToString(), p?.ToString());
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => value is true ? p : Binding.DoNothing;
}

/// <summary>Ampel → Farbe (grün/gelb/grau) bzw. Laufwerksgesundheit.</summary>
public sealed class StatusBrush : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c)
    {
        string key = value switch
        {
            Ampel.Gruen => "Good",
            Ampel.Gelb => "Warn",
            "grün" => "Good",
            "gelb" => "Warn",
            "rot" => "Danger",
            _ => "Neutral",
        };
        return Application.Current.TryFindResource(key) ?? System.Windows.Media.Brushes.Gray;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class AmpelText : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value switch
    {
        Ampel.Gruen => "Aktuell",
        Ampel.Gelb => "Prüfen",
        _ => "Nicht prüfbar",
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

/// <summary>Prozent (0–100) → Farbe für Auslastungs-/Füllbalken.</summary>
public sealed class PercentBrush : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c)
    {
        double v = value is double d ? d : 0;
        string key = v >= 90 ? "Danger" : v >= 75 ? "Warn" : "Accent";
        return Application.Current.TryFindResource(key) ?? System.Windows.Media.Brushes.SteelBlue;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class TypeGlyph : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => (value as string) switch
    {
        "Video" => "",
        "Bild" => "",
        "Audio" => "",
        "PDF" => "",
        "Text" => "",
        "Dokument" => "",
        "Installer" => "",
        "Archiv/Abbild" => "",
        _ => "",
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

/// <summary>Spaltenköpfe im Graphit-Design: Großbuchstaben.</summary>
public sealed class UpperConverter : IValueConverter
{
    public object Convert(object? value, Type t, object p, CultureInfo c) =>
        value is string s ? s.ToUpper(CultureInfo.GetCultureInfo("de-DE")) : value ?? "";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

/// <summary>
/// Größe → Breite eines kleinen Balkens (logarithmisch: 1 MB ≈ 0 px, 100 GB ≈ Max px).
/// So sieht man auf einen Blick, welche Programme viel Platz belegen.
/// </summary>
public sealed class SizeBarConverter : IValueConverter
{
    public double Max { get; set; } = 75;
    public object Convert(object? value, Type t, object p, CultureInfo c)
    {
        double bytes = value switch { long l => l, int i => i, double d => d, _ => 0 };
        if (bytes < 1024 * 1024) return 0.0;
        double w = Math.Log10(bytes / (1024.0 * 1024)) / 5.0 * Max; // 10^5 MB ≈ 100 GB
        w = Math.Clamp(w, 0, Max);
        return w < 3 ? 0.0 : w;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}
