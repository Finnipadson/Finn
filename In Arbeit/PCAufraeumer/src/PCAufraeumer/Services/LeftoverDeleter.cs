using PCAufraeumer.Models;

namespace PCAufraeumer.Services;

/// <summary>
/// Entfernt ausgewählte Reste: Dateien/Ordner → Papierkorb, Registry → vorher als .reg gesichert, dann gelöscht,
/// Dienste/Aufgaben/Firewall-Regeln über den Admin-Helfer. Alles wird protokolliert.
/// </summary>
public sealed class LeftoverDeleter
{
    private readonly DeleteLogService _log;
    public LeftoverDeleter(DeleteLogService log) => _log = log;

    public static string BackupDir
    {
        get { var d = Path.Combine(AppPaths.BaseDir, "Registry-Sicherungen"); Directory.CreateDirectory(d); return d; }
    }

    private static bool UserScope(Leftover l)
    {
        if (l.IsFileSystem)
        {
            var profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return ProtectionService.IsUnder(l.Path, profile);
        }
        return l.Kind is LeftoverKind.RegistrySchluessel or LeftoverKind.RegistryWert &&
               l.Path.StartsWith("HKEY_CURRENT_USER", StringComparison.OrdinalIgnoreCase);
    }

    private static AdminOp ToOp(Leftover l, string backupFolder, int index) => l.Kind switch
    {
        LeftoverKind.Ordner or LeftoverKind.Datei => new AdminOp { Kind = "recycle", Target = l.Path },
        LeftoverKind.RegistrySchluessel or LeftoverKind.RegistryWert => new AdminOp
        {
            Kind = "regdelete", Target = l.Path, Extra = Path.Combine(backupFolder, $"{index:000}.reg"),
        },
        LeftoverKind.Dienst => new AdminOp { Kind = "servicedelete", Target = l.Path },
        LeftoverKind.Aufgabe => new AdminOp { Kind = "taskdelete", Target = l.Path },
        _ => new AdminOp { Kind = "firewalldelete", Target = l.Path },
    };

    public async Task<(int ok, int failed, string backupFolder)> DeleteAsync(IReadOnlyList<Leftover> items, IProgress<string>? progress)
    {
        var backupFolder = Path.Combine(BackupDir, DateTime.Now.ToString("yyyyMMdd-HHmmss"));
        var indexed = items.Select((l, i) => (l, op: ToOp(l, backupFolder, i + 1))).ToList();

        // 1) Benutzerbereich ohne Adminrechte
        var user = indexed.Where(x => UserScope(x.l)).ToList();
        progress?.Report($"Entferne {user.Count} Einträge im Benutzerbereich …");
        var userResults = await StaTask.Run(() => AdminHelper.Execute(user.Select(x => x.op).ToList()));
        var results = new Dictionary<Leftover, AdminResult>();
        for (int i = 0; i < user.Count; i++) results[user[i].l] = userResults[i];

        // 2) Rest (und Benutzer-Einträge ohne Zugriff) mit Adminrechten – ein UAC-Fenster
        var elevated = indexed.Where(x => !results.ContainsKey(x.l) ||
                                          (!results[x.l].Success && results[x.l].Message.Contains("Adminrechte"))).ToList();
        if (elevated.Count > 0)
        {
            progress?.Report($"Entferne {elevated.Count} Einträge mit Adminrechten (Windows fragt nach) …");
            var r = await AdminHelper.RunElevatedAsync(elevated.Select(x => x.op).ToList());
            for (int i = 0; i < elevated.Count && i < r.Count; i++) results[elevated[i].l] = r[i];
        }

        var log = new List<DeleteLogEntry>();
        int ok = 0, failed = 0;
        foreach (var (l, op) in indexed)
        {
            var res = results.TryGetValue(l, out var rr) ? rr : new AdminResult { Success = false, Message = "Nicht ausgeführt." };
            l.Status = res.Success ? "entfernt" : "nicht entfernt: " + res.Message;
            if (res.Success) ok++; else failed++;
            log.Add(new DeleteLogEntry
            {
                Timestamp = DateTime.Now, Path = l.Path, Size = l.Size, Category = $"Programm: {l.Program}",
                Method = l.IsFileSystem ? "Rest entfernt (Papierkorb)" : l.Kind is LeftoverKind.RegistrySchluessel or LeftoverKind.RegistryWert
                    ? "Rest entfernt (Registry, gesichert)" : $"Rest entfernt ({l.KindLabel})",
                Success = res.Success,
                Error = res.Success ? (op.Kind == "regdelete" ? "Sicherung: " + op.Extra : "") : res.Message,
            });
        }
        _log.Append(log);
        return (ok, failed, backupFolder);
    }
}
