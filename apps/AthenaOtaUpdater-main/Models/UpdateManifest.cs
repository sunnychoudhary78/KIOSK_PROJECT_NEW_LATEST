
namespace AthenaOtaUpdater.Models;

public sealed class UpdateManifest
{
    public string Product { get; set; } = "Athena";

    public string Version { get; set; } = "";

    public string DownloadUrl { get; set; } = "";

    public string Sha256 { get; set; } = "";

    public string ExecutableName { get; set; } = "skp_kiosk.exe";
}
