using System.Globalization;

namespace PCAufraeumer.Services;

public static class Format
{
    private static readonly CultureInfo De = CultureInfo.GetCultureInfo("de-DE");

    public static string Bytes(long bytes)
    {
        if (bytes < 0) bytes = 0;
        string[] units = { "B", "KB", "MB", "GB", "TB" };
        double v = bytes;
        int u = 0;
        while (v >= 1024 && u < units.Length - 1) { v /= 1024; u++; }
        return u == 0 ? $"{bytes} B" : v.ToString(v >= 100 ? "0" : "0.0", De) + " " + units[u];
    }

    /// <summary>„seit 14 Monaten“, „seit 3 Tagen“ …</summary>
    public static string Since(DateTime when, DateTime now)
    {
        var days = (now - when).TotalDays;
        if (days < 1) return "seit heute";
        if (days < 60) { int d = (int)days; return d == 1 ? "seit 1 Tag" : $"seit {d} Tagen"; }
        int months = (int)(days / 30.44);
        if (months < 24) return $"seit {months} Monaten";
        double years = days / 365.25;
        return $"seit {years.ToString("0.#", De)} Jahren";
    }

    public static string Duration(TimeSpan t)
    {
        if (t.TotalDays >= 1) return $"{(int)t.TotalDays} T {t.Hours} Std {t.Minutes} Min";
        if (t.TotalHours >= 1) return $"{t.Hours} Std {t.Minutes} Min";
        return $"{t.Minutes} Min";
    }

    public static string Number(double v, string fmt = "0.#") => v.ToString(fmt, De);
}
