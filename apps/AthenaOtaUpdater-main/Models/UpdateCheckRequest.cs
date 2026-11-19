namespace AthenaOtaUpdater.Models;

public sealed class UpdateCheckRequest
{
    public string Product { get; set; } = "Athena";
    public string KioskId { get; set; } = "";
    public string CurrentVersion { get; set; } = "0.0.0";
    public string Platform { get; set; } = "Windows";
    public string Architecture { get; set; } = "x64";
}
