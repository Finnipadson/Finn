using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;

namespace PCAufraeumer.Models;

public enum Confidence { Sicher, Wahrscheinlich, Unsicher }

public enum LeftoverKind { Ordner, Datei, RegistrySchluessel, RegistryWert, Dienst, Aufgabe, Firewall }

/// <summary>Ein gefundener Rest eines Programms. Standardmäßig NICHT ausgewählt.</summary>
public sealed partial class Leftover : ObservableObject
{
    public LeftoverKind Kind { get; init; }
    /// <summary>Datei-/Ordnerpfad, Registry-Schlüssel, „Schlüssel|Wert“, Dienst-, Aufgaben- oder Regelname.</summary>
    public string Path { get; init; } = "";
    public string Display { get; init; } = "";
    public Confidence Confidence { get; set; }
    public string Reason { get; set; } = "";
    public string Program { get; init; } = "";
    public long Size { get; set; }
    /// <summary>Zusätzliche Info (z. B. Registry-Schlüssel eines Dienstes für die Sicherung).</summary>
    public string Extra { get; init; } = "";

    [ObservableProperty] private bool _isChecked;
    [ObservableProperty] private string _status = "";

    public bool IsFileSystem => Kind is LeftoverKind.Ordner or LeftoverKind.Datei;
    public bool IsSafe => Confidence == Confidence.Sicher;
    public string KindLabel => Kind switch
    {
        LeftoverKind.Ordner => "Ordner", LeftoverKind.Datei => "Datei", LeftoverKind.RegistrySchluessel => "Schlüssel",
        LeftoverKind.RegistryWert => "Wert", LeftoverKind.Dienst => "Dienst", LeftoverKind.Aufgabe => "Geplante Aufgabe",
        _ => "Firewall-Regel",
    };
    public string ConfidenceLabel => Confidence switch
    {
        Confidence.Sicher => "sicher", Confidence.Wahrscheinlich => "wahrscheinlich", _ => "unsicher",
    };
}

/// <summary>Knoten der Baumansicht (Programm → Bereich → Fund).</summary>
public sealed class LeftoverNode
{
    public string Title { get; init; } = "";
    public Leftover? Item { get; init; }
    public ObservableCollection<LeftoverNode> Children { get; } = new();
    public bool IsGroup => Item == null;
}

/// <summary>Was die App VOR der Deinstallation über ein Programm weiß (danach ist vieles schon weg).</summary>
public sealed class ProgramFootprint
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Publisher { get; set; } = "";
    public string InstallLocation { get; set; } = "";
    public string MainExe { get; set; } = "";
    public List<string> ExeNames { get; set; } = new();
    public string ProductCode { get; set; } = "";
    public string RegistryPath { get; set; } = "";
    public string PackageFamilyName { get; set; } = "";
    public InstallRecording? Recording { get; set; }
}

/// <summary>Ergebnis von „Installation aufzeichnen“.</summary>
public sealed class InstallRecording
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "";
    public string SetupFile { get; set; } = "";
    public DateTime Date { get; set; } = DateTime.Now;
    /// <summary>„Aufgezeichnet“ (exakt) oder „Geschätzt“ (nachträglich zugeordnet).</summary>
    public bool IsEstimate { get; set; }
    /// <summary>Verknüpfte Programmeinträge (Ids und „name:…“).</summary>
    public List<string> ProgramIds { get; set; } = new();
    public List<string> NewDirectories { get; set; } = new();
    public List<string> NewFiles { get; set; } = new();
    public List<string> ChangedFiles { get; set; } = new();
    public List<string> NewKeys { get; set; } = new();
    public List<string> ChangedKeys { get; set; } = new();
    public List<string> NewValues { get; set; } = new();

    [System.Text.Json.Serialization.JsonIgnore] public string Kind => IsEstimate ? "geschätzt" : "aufgezeichnet";

    [System.Text.Json.Serialization.JsonIgnore] public string Summary =>
        $"{Date:dd.MM.yyyy HH:mm} · {NewDirectories.Count} Ordner, {NewFiles.Count} Dateien, {NewKeys.Count} Registry-Schlüssel neu" +
        (IsEstimate ? " · geschätzt" : "");
}
