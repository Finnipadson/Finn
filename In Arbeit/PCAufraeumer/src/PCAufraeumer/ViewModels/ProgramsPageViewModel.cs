using CommunityToolkit.Mvvm.ComponentModel;
using PCAufraeumer.Services;

namespace PCAufraeumer.ViewModels;

/// <summary>Seite „Programme“ mit den Tabs Deinstallieren, Erzwungene Deinstallation, Installationen überwachen, Autostart.</summary>
public sealed partial class ProgramsPageViewModel : ObservableObject
{
    public UninstallViewModel Uninstall { get; }
    public ProgramsViewModel List { get; }
    public ForcedUninstallViewModel Forced { get; }
    public RecorderViewModel Recorder { get; }
    public AutostartViewModel Autostart { get; }

    [ObservableProperty] private int _tabIndex;

    public ProgramsPageViewModel(SettingsService settings, DeleteLogService log, Action logChanged)
    {
        InstallRecorder.Configure(settings.Current.Programs);
        Uninstall = new UninstallViewModel(settings, log, logChanged);
        List = new ProgramsViewModel(settings, Uninstall);
        Forced = new ForcedUninstallViewModel(settings, Uninstall, List);
        Recorder = new RecorderViewModel(settings, List);
        Autostart = new AutostartViewModel(log, logChanged);
        AutostartService.StoreNameLookup = pfn =>
            List.Programs.FirstOrDefault(p => string.Equals(p.PackageFamilyName, pfn, StringComparison.OrdinalIgnoreCase))?.Name;
    }

    public async Task EnsureLoadedAsync()
    {
        await List.EnsureLoadedAsync();
        Recorder.Reload();
    }

    partial void OnTabIndexChanged(int value)
    {
        if (value == 3) _ = Autostart.EnsureLoadedAsync();
        if (value == 2) Recorder.Reload();
    }
}
