namespace AthenaOtaUpdater.Models;

public sealed class UpdateCheckResponse
{
    public string Version { get; set; } = "";

    public string DownloadUrl { get; set; } = "";

    public string Sha256 { get; set; } = "";

    public long ByteSize { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }
}
