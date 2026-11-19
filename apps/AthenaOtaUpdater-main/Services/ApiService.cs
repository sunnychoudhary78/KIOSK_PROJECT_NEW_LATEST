using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace AthenaOtaUpdater.Services;

public sealed class ApiService
{
    private readonly HttpClient _httpClient;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public ApiService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    // Sends a JSON request and returns the raw JSON response.
    public async Task<string> PostJsonAsync(
        string endpoint,
        object request,
        string? apiKey = null,
        CancellationToken cancellationToken = default)
    {
        string json = JsonSerializer.Serialize(request);

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            endpoint);

        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            httpRequest.Headers.TryAddWithoutValidation(
                "X-Update-Key",
                apiKey);
        }

        httpRequest.Content = new StringContent(
            json,
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(
            httpRequest,
            cancellationToken);

        response.EnsureSuccessStatusCode();

        return await response.Content.ReadAsStringAsync(
            cancellationToken);
    }

    /// <summary>
    /// Uploads updater log files as multipart/form-data.
    /// Form fields: kioskId, machineName, uploadedAt, installedVersion, plus file parts named "files".
    /// </summary>
    public async Task UploadLogFilesAsync(
        string endpoint,
        string apiKey,
        string kioskId,
        string machineName,
        string installedVersion,
        IReadOnlyList<(string FileName, string FilePath)> files,
        CancellationToken cancellationToken = default)
    {
        using var form = new MultipartFormDataContent();

        form.Add(new StringContent(kioskId ?? ""), "kioskId");
        form.Add(new StringContent(machineName ?? ""), "machineName");
        form.Add(
            new StringContent(DateTimeOffset.UtcNow.ToString("O")),
            "uploadedAt");
        form.Add(
            new StringContent(installedVersion ?? ""),
            "installedVersion");

        var streams = new List<FileStream>();

        try
        {
            foreach (var (fileName, filePath) in files)
            {
                var stream = new FileStream(
                    filePath,
                    FileMode.Open,
                    FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete);

                streams.Add(stream);

                var fileContent = new StreamContent(stream);
                fileContent.Headers.ContentType =
                    new System.Net.Http.Headers.MediaTypeHeaderValue(
                        "text/plain");

                form.Add(fileContent, "files", fileName);
            }

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                endpoint);

            request.Headers.TryAddWithoutValidation(
                "X-Update-Key",
                apiKey);

            request.Content = form;

            using var response = await _httpClient.SendAsync(
                request,
                cancellationToken);

            response.EnsureSuccessStatusCode();
        }
        finally
        {
            foreach (var stream in streams)
                await stream.DisposeAsync();
        }
    }

    // Sends a JSON request and deserializes the response.
    public async Task<TResponse> PostJsonAsync<TResponse>(
        string endpoint,
        object request,
        string? apiKey = null,
        CancellationToken cancellationToken = default)
    {
        string responseJson = await PostJsonAsync(
            endpoint,
            request,
            apiKey,
            cancellationToken);

        return JsonSerializer.Deserialize<TResponse>(
            responseJson,
            JsonOptions)
            ?? throw new InvalidDataException(
                "API returned an empty or invalid response.");
    }


public async Task<TResponse> GetJsonAsync<TResponse>(
    string endpoint,
    string apiKey,
    CancellationToken cancellationToken = default)
{
    using var request = new HttpRequestMessage(
        HttpMethod.Get,
        endpoint);

    request.Headers.TryAddWithoutValidation(
        "X-Update-Key",
        apiKey);

    using var response = await _httpClient.SendAsync(
        request,
        HttpCompletionOption.ResponseHeadersRead,
        cancellationToken);

    response.EnsureSuccessStatusCode();

    string responseJson = await response.Content.ReadAsStringAsync(
        cancellationToken);

    return JsonSerializer.Deserialize<TResponse>(
        responseJson,
        JsonOptions)
        ?? throw new InvalidDataException(
            "Version API returned an empty or invalid response.");
}


    // Downloads a file from an HTTP GET endpoint.
    public async Task DownloadFileAsync(
        string endpoint,
        string destinationPath,
        IProgress<double>? progress = null,
        CancellationToken cancellationToken = default)
    {
        using var response = await _httpClient.GetAsync(
            endpoint,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);

        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength;

        await using var input =
            await response.Content.ReadAsStreamAsync(cancellationToken);

        await using var output = new FileStream(
            destinationPath,
            FileMode.Create,
            FileAccess.Write,
            FileShare.None,
            81920,
            true);

        var buffer = new byte[81920];
        long totalRead = 0;
        int bytesRead;

        while ((bytesRead = await input.ReadAsync(
            buffer.AsMemory(0, buffer.Length),
            cancellationToken)) > 0)
        {
            await output.WriteAsync(
                buffer.AsMemory(0, bytesRead),
                cancellationToken);

            totalRead += bytesRead;

            if (totalBytes.HasValue && totalBytes.Value > 0)
            {
                progress?.Report(
                    totalRead * 100d / totalBytes.Value);
            }
        }

        progress?.Report(100);
    }
}
