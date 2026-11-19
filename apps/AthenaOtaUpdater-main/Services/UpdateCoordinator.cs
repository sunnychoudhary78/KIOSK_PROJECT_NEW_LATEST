
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Runtime.ExceptionServices;
using AthenaOtaUpdater.Models;

namespace AthenaOtaUpdater.Services;

public sealed class UpdateCoordinator : IDisposable
{
    private readonly string _settingsPath;
    private readonly Action<string> _status;
    private readonly Action<double> _progress;

    private readonly HttpClient _apiHttp = new()
    {
        Timeout = TimeSpan.FromMinutes(5)
    };

    private readonly HttpClient _downloadHttp = new()
    {
        Timeout = TimeSpan.FromMinutes(15)
    };

    private readonly ApiService _apiService;
    private readonly SemaphoreSlim _gate = new(1, 1);

    private CancellationTokenSource? _loopCts;
    private Settings _settings = new();

    public UpdateCoordinator(
        string settingsPath,
        Action<string> status,
        Action<double> progress)
    {
        _settingsPath = settingsPath;
        _status = status;
        _progress = progress;

        _apiService = new ApiService(_apiHttp);
    }

    // ---------------------------------------------------------
    // STARTUP
    // ---------------------------------------------------------

    public async Task StartAsync()
    {
        try
        {
            string json = await File.ReadAllTextAsync(_settingsPath);

            _settings =
                JsonSerializer.Deserialize<Settings>(
                    json, JsonOptions())
                ?? throw new InvalidDataException(
                    "Could not read updater configuration.");

            ValidateSettings();

            _apiHttp.Timeout = TimeSpan.FromMinutes(
                Math.Clamp(_settings.ApiTimeoutMinutes, 1, 30));

            _downloadHttp.Timeout = TimeSpan.FromMinutes(15);

            EnsureDirectory(_settings.WorkDirectory, nameof(Settings.WorkDirectory));
            EnsureDirectory(_settings.BackupDirectory, nameof(Settings.BackupDirectory));
            EnsureDirectory(_settings.InstallDirectory, nameof(Settings.InstallDirectory));

            EnsureBootIntegration();

            _status("Athena updater started. Checking for updates...");

            await CheckOnceAsync(false);

            _loopCts = new CancellationTokenSource();

            _ = PollLoopAsync(_loopCts.Token);
        }
        catch (Exception ex)
        {
            Log("Startup error: " + ex);

            _status(
                "Updater startup error: " + ex.Message);
        }
    }

    private void ValidateSettings()
    {
        ValidateApiEndpoint(_settings.VersionCheckApiUrl);

        if (string.IsNullOrWhiteSpace(_settings.ApiKey))
            throw new InvalidOperationException(
                "API key is missing from appsettings.json.");

        if (string.IsNullOrWhiteSpace(_settings.ExecutableName))
            throw new InvalidOperationException(
                "Executable name is missing.");

        if (Path.GetFileName(_settings.ExecutableName)
            != _settings.ExecutableName)
            throw new InvalidOperationException(
                "Executable name must not contain a directory path.");

        if (_settings.MaxPackageSizeMB <= 0 ||
            _settings.MaxExtractedSizeMB <= 0)
            throw new InvalidOperationException(
                "Package size limits must be positive.");

        ValidateDirectorySetting(
            _settings.WorkDirectory,
            nameof(Settings.WorkDirectory));
        ValidateDirectorySetting(
            _settings.BackupDirectory,
            nameof(Settings.BackupDirectory));
        ValidateDirectorySetting(
            _settings.InstallDirectory,
            nameof(Settings.InstallDirectory));
    }

    private static void ValidateDirectorySetting(
        string path,
        string settingName)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            throw new InvalidOperationException(
                $"{settingName} is missing from appsettings.json.");
        }

        string fullPath;
        try
        {
            fullPath = Path.GetFullPath(path);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                $"{settingName} is not a valid path: '{path}'.",
                ex);
        }

        string? root = Path.GetPathRoot(fullPath);
        if (string.IsNullOrWhiteSpace(root) ||
            !Directory.Exists(root))
        {
            throw new InvalidOperationException(
                $"{settingName} drive does not exist: '{root}'. " +
                $"Update appsettings.json ({settingName}) to a path on an existing drive.");
        }
    }

    private static void EnsureDirectory(string path, string settingName)
    {
        try
        {
            Directory.CreateDirectory(path);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                $"Could not create {settingName} folder '{path}'. " +
                "Check the path in appsettings.json and folder permissions.",
                ex);
        }
    }

    // ---------------------------------------------------------
    // PERIODIC CHECK
    // ---------------------------------------------------------

    private async Task PollLoopAsync(CancellationToken token)
    {
        using var timer = new PeriodicTimer(
            TimeSpan.FromMinutes(
                Math.Clamp(_settings.CheckIntervalMinutes, 1, 1440)));

        try
        {
            while (await timer.WaitForNextTickAsync(token))
            {
                await CheckOnceAsync(false);
            }
        }
        catch (OperationCanceledException)
        {
            // Normal shutdown.
        }
        catch (Exception ex)
        {
            Log("Polling error: " + ex);
        }
    }

    
// ---------------------------------------------------------
// CHECK FOR UPDATES
// ---------------------------------------------------------

public async Task CheckOnceAsync(bool forceIdle = false)
{
    if (!await _gate.WaitAsync(0))
        return;

    try
    {
        _status("Connecting to Athena update server...");
        Log("Starting update check.");

        Uri apiUri = ValidateApiEndpoint(
            _settings.VersionCheckApiUrl);

        var update = await _apiService
            .GetJsonAsync<UpdateCheckResponse>(
                apiUri.AbsoluteUri,
                _settings.ApiKey);

        ValidateVersionResponse(update);

        string currentVersion = ReadInstalledVersion();

        if (!Version.TryParse(currentVersion, out var current))
        {
            throw new InvalidDataException(
                "Installed Athena version is invalid.");
        }

        if (!Version.TryParse(update.Version, out var latest))
        {
            throw new InvalidDataException(
                "Server returned an invalid version.");
        }

        _status(
            $"Installed: {currentVersion} | Available: {update.Version}");

        Log($"Installed version: {currentVersion}. Available version: {update.Version}.");

        if (latest <= current)
        {
            _status($"Athena is up to date ({currentVersion}).");
            Log("No update required.");
            return;
        }

        _status($"New Athena version available: {update.Version}");

        ValidateUpdatePackage(update);

        string zipPath = Path.Combine(
            _settings.WorkDirectory,
            $"athena-{update.Version}.zip");

        Directory.CreateDirectory(_settings.WorkDirectory);

        bool packageReady = false;

        // Reuse an existing package if its hash is correct.
        if (File.Exists(zipPath))
        {
            _status("Checking previously downloaded package...");

            Log("Checking existing update package.");

            packageReady = await HashMatchesAsync(
                zipPath,
                update.Sha256);

            if (packageReady)
            {
                Log("Existing package passed SHA-256 verification.");
            }
            else
            {
                Log("Existing package failed verification. Downloading again.");
                TryDeleteFile(zipPath);
            }
        }

        // Download only when a valid package is not available.
        if (!packageReady)
        {
            if (DateTimeOffset.UtcNow >= update.ExpiresAt)
            {
                throw new InvalidDataException(
                    "Download URL has expired. A fresh API response is required.");
            }

            _status($"Downloading Athena {update.Version}...");
            _progress(0);

            Log($"Downloading Athena version {update.Version}.");

            await DownloadAsync(update, zipPath);

            _status("Verifying downloaded package...");

            if (!await HashMatchesAsync(zipPath, update.Sha256))
            {
                TryDeleteFile(zipPath);

                throw new InvalidDataException(
                    "SHA-256 verification failed. Package rejected.");
            }

            Log("Downloaded package passed SHA-256 verification.");
        }

        _status("Package verified successfully.");

        // Wait automatically for the configured idle period.
        if (!forceIdle)
        {
            Log("Waiting for Windows idle condition.");

            while (WindowsIdleDetector.GetIdleTime() <
                   TimeSpan.FromMinutes(_settings.IdleMinutes))
            {
                _status(
                    $"Update downloaded and verified. Waiting for kiosk idle ({_settings.IdleMinutes} minute required)...");

                await Task.Delay(TimeSpan.FromSeconds(5));
            }
        }

        Log("Idle condition satisfied. Starting installation.");

        _status("Kiosk is idle. Installing Athena update...");

        await InstallAsync(zipPath, update);

        Log($"Update installation completed successfully: {update.Version}");
    }
    catch (Exception ex)
    {
        Log("Update check failed: " + ex);

        _status("Update error: " + ex.Message);
    }
    finally
    {
        _gate.Release();
    }
}


    // ---------------------------------------------------------
    // API RESPONSE VALIDATION
    // ---------------------------------------------------------

    private static void ValidateVersionResponse(
        UpdateCheckResponse response)
    {
        if (response == null)
            throw new InvalidDataException(
                "Version API returned an empty response.");

        if (!Version.TryParse(response.Version, out _))
            throw new InvalidDataException(
                "API returned an invalid version number.");

        if (string.IsNullOrWhiteSpace(response.DownloadUrl))
            throw new InvalidDataException(
                "API did not provide a download URL.");

        if (string.IsNullOrWhiteSpace(response.Sha256) ||
            response.Sha256.Length != 64 ||
            !response.Sha256.All(Uri.IsHexDigit))
        {
            throw new InvalidDataException(
                "API returned an invalid SHA-256 checksum.");
        }

        if (response.ByteSize <= 0)
            throw new InvalidDataException(
                "API returned an invalid package size.");

        if (response.ExpiresAt == default)
            throw new InvalidDataException(
                "API returned an invalid URL expiry time.");
    }

    private void ValidateUpdatePackage(
        UpdateCheckResponse update)
    {
        if (!Uri.TryCreate(
            update.DownloadUrl,
            UriKind.Absolute,
            out var downloadUri))
        {
            throw new InvalidDataException(
                "Invalid download URL.");
        }

        if (downloadUri.Scheme != Uri.UriSchemeHttps)
        {
            throw new InvalidDataException(
                "Signed download URL must use HTTPS.");
        }

        long maximumBytes =
            (long)_settings.MaxPackageSizeMB * 1024 * 1024;

        if (update.ByteSize > maximumBytes)
        {
            throw new InvalidDataException(
                "Package exceeds the configured maximum download size.");
        }
    }

    // ---------------------------------------------------------
    // INSTALLED VERSION
    // ---------------------------------------------------------

    private string ReadInstalledVersion()
    {
        string recordedVersionFile = Path.Combine(
            _settings.WorkDirectory,
            "installed-version.txt");

        if (File.Exists(recordedVersionFile))
        {
            string recorded = File.ReadAllText(
                recordedVersionFile).Trim();

            if (Version.TryParse(recorded, out _))
                return recorded;
        }

        string exe = Path.Combine(
            _settings.InstallDirectory,
            _settings.ExecutableName);

        if (!File.Exists(exe))
            return "0.0.0";

        var info = FileVersionInfo.GetVersionInfo(exe);

        string? version = info.ProductVersion;

        if (!Version.TryParse(version, out _))
            version = info.FileVersion;

        return Version.TryParse(version, out _)
            ? version!
            : "0.0.0";
    }


// ---------------------------------------------------------
// VERSION INSTALLATION HISTORY
// ---------------------------------------------------------

private async Task RecordVersionHistoryAsync(string version)
{
    string historyFile = Path.Combine(
        _settings.WorkDirectory,
        "version-history.txt");

    string temporaryFile = historyFile + ".tmp";

    Directory.CreateDirectory(_settings.WorkDirectory);

    string timestamp = DateTimeOffset.Now.ToString(
        "yyyy-MM-dd HH:mm:ss zzz");

    string newEntry =
        $"Version: {version} | Installed: {timestamp}";

    string existingHistory = File.Exists(historyFile)
        ? await File.ReadAllTextAsync(historyFile)
        : string.Empty;

    string updatedHistory = string.IsNullOrWhiteSpace(existingHistory)
        ? newEntry + Environment.NewLine
        : newEntry + Environment.NewLine + existingHistory;

    await File.WriteAllTextAsync(
        temporaryFile,
        updatedHistory);

    File.Move(
        temporaryFile,
        historyFile,
        true);
}

    // ---------------------------------------------------------
    // DOWNLOAD
    // ---------------------------------------------------------

    private async Task DownloadAsync(
        UpdateCheckResponse update,
        string destination)
    {
        string temporaryPath = destination + ".part";

        TryDeleteFile(temporaryPath);

        try
        {
            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                update.DownloadUrl);

            using var response = await _downloadHttp.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead);

            response.EnsureSuccessStatusCode();

            var finalUri = response.RequestMessage?.RequestUri;

            if (finalUri == null ||
                finalUri.Scheme != Uri.UriSchemeHttps)
            {
                throw new InvalidDataException(
                    "Download redirected to a non-HTTPS URL.");
            }

            long expectedBytes = update.ByteSize;

            if (response.Content.Headers.ContentLength.HasValue &&
                response.Content.Headers.ContentLength.Value != expectedBytes)
            {
                throw new InvalidDataException(
                    "Server download size does not match the API response.");
            }

            await using var input =
                await response.Content.ReadAsStreamAsync();

            await using var output = new FileStream(
                temporaryPath,
                FileMode.Create,
                FileAccess.Write,
                FileShare.None,
                81920,
                true);

            var buffer = new byte[81920];

            long received = 0;
            int read;

            while ((read = await input.ReadAsync(buffer)) > 0)
            {
                received += read;

                if (received > expectedBytes)
                {
                    throw new InvalidDataException(
                        "Downloaded package exceeds expected size.");
                }

                await output.WriteAsync(
                    buffer.AsMemory(0, read));

                _progress(
                    received * 100d / expectedBytes);
            }

            await output.FlushAsync();

            if (received != expectedBytes)
            {
                throw new InvalidDataException(
                    $"Incomplete download. Expected {expectedBytes} bytes, received {received} bytes.");
            }

            output.Close();

            if (File.Exists(destination))
                File.Delete(destination);

            File.Move(temporaryPath, destination);

            _progress(100);
        }
        catch
        {
            TryDeleteFile(temporaryPath);
            throw;
        }
    }

    private static async Task<bool> HashMatchesAsync(
        string path,
        string expected)
    {
        if (!File.Exists(path))
            return false;

        await using var stream = File.OpenRead(path);

        string hash = Convert.ToHexString(
            await SHA256.HashDataAsync(stream));

        return hash.Equals(
            expected,
            StringComparison.OrdinalIgnoreCase);
    }

    
// ---------------------------------------------------------
// INSTALLATION
// ---------------------------------------------------------

private async Task InstallAsync(
    string zipPath,
    UpdateCheckResponse update)
{
    string stage = Path.Combine(
        _settings.WorkDirectory,
        "Staging");

    string install = Path.GetFullPath(
        _settings.InstallDirectory);

    string backup = Path.Combine(
        _settings.BackupDirectory,
        "PreviousBuild");

    string parent = Directory.GetParent(install)?.FullName
        ?? throw new InvalidOperationException(
            "Install directory must have a parent.");

    Directory.CreateDirectory(parent);
    Directory.CreateDirectory(_settings.BackupDirectory);

    if (Directory.Exists(stage))
        Directory.Delete(stage, true);

    Directory.CreateDirectory(stage);

    _status("Extracting Athena update...");

    Log("Extracting update package.");

    SafeExtract(zipPath, stage);

    // Find the executable anywhere inside the extracted package.
    string[] executableFiles = Directory.GetFiles(
        stage,
        _settings.ExecutableName,
        SearchOption.AllDirectories);

    if (executableFiles.Length == 0)
    {
        throw new InvalidDataException(
            $"ZIP does not contain {_settings.ExecutableName}.");
    }

    if (executableFiles.Length > 1)
    {
        throw new InvalidDataException(
            $"ZIP contains multiple copies of {_settings.ExecutableName}. Installation rejected.");
    }

    // Use the directory containing the executable as the application root.
    string stagedAppDirectory =
        Path.GetDirectoryName(executableFiles[0])!;

    Log($"Application files found in: {stagedAppDirectory}");

    // Confirm the application root is inside staging.
    string fullStage = Path.GetFullPath(stage)
        + Path.DirectorySeparatorChar;

    string fullStagedApp = Path.GetFullPath(stagedAppDirectory);

    if (!fullStagedApp.StartsWith(
        fullStage,
        StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidDataException(
            "Extracted application directory is outside staging.");
    }

    _status("Athena package validated successfully.");

    Log("Package structure validated.");

    _status("Waiting to stop Athena...");

    // Stop the main app and any helpers launched from the install folder
    // (e.g. skp_printer_usb.exe). Otherwise Directory.Move fails with
    // "file is being used by another process".
    await StopInstallDirectoryProcessesAsync();

    await Task.Delay(1500);

    if (IsInstallDirectoryInUse())
    {
        throw new InvalidOperationException(
            "Could not stop all processes using the Athena install folder. Installation cancelled.");
    }

    bool movedOld = false;
    bool newInstallationMoved = false;

    try
    {
        if (Directory.Exists(backup))
            Directory.Delete(backup, true);

        if (Directory.Exists(install))
        {
            Log($"Moving current install to backup: {install} -> {backup}");
            await MoveDirectoryReliableAsync(install, backup);
            movedOld = true;
        }

        // Move the actual application folder, not the outer ZIP folder.
        Log($"Moving staged build into place: {stagedAppDirectory} -> {install}");
        await MoveDirectoryReliableAsync(stagedAppDirectory, install);
        newInstallationMoved = true;

        _status("Starting updated Athena...");

        Log("Starting updated Athena.");

        StartAthena();

        await Task.Delay(
            TimeSpan.FromSeconds(
                Math.Clamp(_settings.HealthCheckSeconds, 5, 120)));

        if (!IsAthenaRunning())
        {
            throw new InvalidOperationException(
                "Athena did not remain running after the update.");
        }


// Record current version after successful launch check.
string versionFile = Path.Combine(
    _settings.WorkDirectory,
    "installed-version.txt");

string temporaryVersionFile = versionFile + ".tmp";

await File.WriteAllTextAsync(
    temporaryVersionFile,
    update.Version);

File.Move(
    temporaryVersionFile,
    versionFile,
    true);

// Maintain installation history separately.
// History failure must not invalidate a successful installation.
try
{
    await RecordVersionHistoryAsync(update.Version);

    Log($"Version history recorded: {update.Version}");
}
catch (Exception historyError)
{
    Log(
        "WARNING: Could not update version history: " +
        historyError.Message);
}


        _status(
            $"Athena successfully updated to {update.Version}.");

        Log($"Update successful: {update.Version}");

        // Remove remaining staging folders.
        if (Directory.Exists(stage))
        {
            try
            {
                Directory.Delete(stage, true);
            }
            catch (Exception ex)
            {
                Log("Staging cleanup failed: " + ex.Message);
            }
        }

        if (!_settings.KeepBackup &&
            Directory.Exists(backup))
        {
            try
            {
                Directory.Delete(backup, true);
            }
            catch (Exception ex)
            {
                Log(
                    "Update succeeded, but backup cleanup failed: " +
                    ex.Message);
            }
        }
    }
    catch (Exception installationError)
    {
        _status(
            "Update failed. Attempting to restore previous version...");

        try
        {
            await StopInstallDirectoryProcessesAsync();

            if (newInstallationMoved &&
                Directory.Exists(install))
            {
                Directory.Delete(install, true);
            }

            if (movedOld && Directory.Exists(backup))
            {
                await MoveDirectoryReliableAsync(backup, install);
            }

            if (Directory.Exists(install))
            {
                StartAthena();
            }

            Log(
                "Previous Athena installation restored successfully.");
        }
        catch (Exception rollbackError)
        {
            Log("Installation error: " + installationError);

            Log("ROLLBACK ERROR: " + rollbackError);

            throw new AggregateException(
                "Installation failed and automatic rollback also failed. " +
                "The backup folder has been preserved for recovery.",
                installationError,
                rollbackError);
        }

        ExceptionDispatchInfo.Capture(
            installationError).Throw();

        throw;
    }
}

    // ---------------------------------------------------------
    // SAFE ZIP EXTRACTION
    // ---------------------------------------------------------

    private void SafeExtract(
        string zipPath,
        string destination)
    {
        string root = Path.GetFullPath(destination)
            + Path.DirectorySeparatorChar;

        long maximumExtractedBytes =
            (long)_settings.MaxExtractedSizeMB * 1024 * 1024;

        long extractedBytes = 0;

        using var archive = ZipFile.OpenRead(zipPath);

        foreach (var entry in archive.Entries)
        {
            string target = Path.GetFullPath(
                Path.Combine(destination, entry.FullName));

            if (!target.StartsWith(
                root,
                StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException(
                    "ZIP contains an unsafe path.");
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(target);
                continue;
            }

            extractedBytes += entry.Length;

            if (extractedBytes > maximumExtractedBytes)
            {
                throw new InvalidDataException(
                    "Extracted package exceeds the configured size limit.");
            }

            Directory.CreateDirectory(
                Path.GetDirectoryName(target)!);

            entry.ExtractToFile(target, true);
        }
    }

    // ---------------------------------------------------------
    // PROCESS MANAGEMENT
    // ---------------------------------------------------------

    private string GetInstallRoot()
    {
        return Path.GetFullPath(_settings.InstallDirectory)
            .TrimEnd(
                Path.DirectorySeparatorChar,
                Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
    }

    private Process[] GetProcessesUsingInstallDirectory()
    {
        string installRoot = GetInstallRoot();
        var matchingProcesses = new List<Process>();

        foreach (var process in Process.GetProcesses())
        {
            try
            {
                string? actualPath = process.MainModule?.FileName;

                if (string.IsNullOrWhiteSpace(actualPath))
                {
                    process.Dispose();
                    continue;
                }

                string full = Path.GetFullPath(actualPath);

                if (full.StartsWith(
                        installRoot,
                        StringComparison.OrdinalIgnoreCase))
                {
                    matchingProcesses.Add(process);
                }
                else
                {
                    process.Dispose();
                }
            }
            catch (Exception)
            {
                // Access denied / system process — ignore.
                process.Dispose();
            }
        }

        return matchingProcesses.ToArray();
    }

    private async Task StopInstallDirectoryProcessesAsync()
    {
        var processes = GetProcessesUsingInstallDirectory();

        if (processes.Length == 0)
        {
            Log("No processes were running from the Athena install folder.");
            return;
        }

        foreach (var process in processes)
        {
            try
            {
                string name = process.ProcessName;
                int id = process.Id;
                string? path = null;

                try
                {
                    path = process.MainModule?.FileName;
                }
                catch
                {
                    // Best-effort path for logging.
                }

                Log($"Stopping process {name} ({id}): {path}");

                try
                {
                    process.CloseMainWindow();
                }
                catch
                {
                    // Some helpers have no UI — Kill below.
                }

                if (!process.WaitForExit(8000))
                {
                    process.Kill(true);
                    process.WaitForExit(5000);
                }

                if (!process.HasExited)
                {
                    throw new InvalidOperationException(
                        $"Process {name} ({id}) could not be stopped.");
                }
            }
            catch (Exception ex)
            {
                Log("Could not stop install-folder process: " + ex.Message);
                throw;
            }
            finally
            {
                process.Dispose();
            }
        }

        // Give Windows a moment to release file handles.
        await Task.Delay(1000);

        for (int attempt = 1; attempt <= 5; attempt++)
        {
            if (!IsInstallDirectoryInUse())
                return;

            Log($"Install folder still in use after stop (attempt {attempt}). Waiting...");
            await Task.Delay(1000 * attempt);
            await StopRemainingInstallProcessesOnceAsync();
        }
    }

    private async Task StopRemainingInstallProcessesOnceAsync()
    {
        foreach (var process in GetProcessesUsingInstallDirectory())
        {
            try
            {
                process.Kill(true);
                process.WaitForExit(3000);
            }
            catch (Exception ex)
            {
                Log("Force-stop failed: " + ex.Message);
            }
            finally
            {
                process.Dispose();
            }
        }

        await Task.Delay(500);
    }

    private bool IsInstallDirectoryInUse()
    {
        var processes = GetProcessesUsingInstallDirectory();

        foreach (var process in processes)
            process.Dispose();

        return processes.Length > 0;
    }

    private bool IsAthenaRunning()
    {
        string expectedPath = Path.GetFullPath(
            Path.Combine(
                _settings.InstallDirectory,
                _settings.ExecutableName));

        var processes = GetProcessesUsingInstallDirectory();
        bool running = false;

        foreach (var process in processes)
        {
            try
            {
                string? actualPath = process.MainModule?.FileName;
                if (!string.IsNullOrWhiteSpace(actualPath) &&
                    string.Equals(
                        Path.GetFullPath(actualPath),
                        expectedPath,
                        StringComparison.OrdinalIgnoreCase))
                {
                    running = true;
                }
            }
            catch
            {
                // Ignore access issues for health check.
            }
            finally
            {
                process.Dispose();
            }
        }

        return running;
    }

    private async Task MoveDirectoryReliableAsync(
        string source,
        string destination)
    {
        const int maxAttempts = 8;

        for (int attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                if (!Directory.Exists(source))
                {
                    throw new DirectoryNotFoundException(
                        $"Source folder does not exist: {source}");
                }

                if (Directory.Exists(destination))
                {
                    throw new IOException(
                        $"Destination folder already exists: {destination}");
                }

                Directory.Move(source, destination);
                return;
            }
            catch (IOException ex) when (attempt < maxAttempts)
            {
                Log(
                    $"Directory move attempt {attempt}/{maxAttempts} failed " +
                    $"({source} -> {destination}): {ex.Message}");

                await StopRemainingInstallProcessesOnceAsync();
                await Task.Delay(500 * attempt);
            }
        }

        Log(
            $"Directory.Move failed repeatedly. Falling back to copy+delete: " +
            $"{source} -> {destination}");

        CopyDirectoryRecursive(source, destination);

        try
        {
            Directory.Delete(source, true);
        }
        catch (Exception ex)
        {
            Log(
                "Copy succeeded but source cleanup failed (safe to remove later): " +
                ex.Message);
        }
    }

    private static void CopyDirectoryRecursive(
        string source,
        string destination)
    {
        Directory.CreateDirectory(destination);

        foreach (string file in Directory.GetFiles(source))
        {
            string targetFile = Path.Combine(
                destination,
                Path.GetFileName(file));

            File.Copy(file, targetFile, true);
        }

        foreach (string directory in Directory.GetDirectories(source))
        {
            string targetDirectory = Path.Combine(
                destination,
                Path.GetFileName(directory));

            CopyDirectoryRecursive(directory, targetDirectory);
        }
    }

    private void StartAthena()
    {
        string exe = Path.Combine(
            _settings.InstallDirectory,
            _settings.ExecutableName);

        if (!File.Exists(exe))
        {
            throw new FileNotFoundException(
                "Athena executable is missing.",
                exe);
        }

        var process = Process.Start(
            new ProcessStartInfo
            {
                FileName = exe,
                Arguments = _settings.StartupArguments,
                WorkingDirectory = _settings.InstallDirectory,
                UseShellExecute = true
            });

        if (process == null)
        {
            throw new InvalidOperationException(
                "Windows could not start Athena.");
        }

        process.Dispose();
    }

    // ---------------------------------------------------------
    // BOOT INTEGRATION (Task Scheduler @ logon)
    // ---------------------------------------------------------

    private void EnsureBootIntegration()
    {
        if (!_settings.EnsureBootTask)
        {
            Log("Boot task registration skipped (ensureBootTask=false).");
            return;
        }

        try
        {
            string exePath = Environment.ProcessPath
                ?? Path.Combine(AppContext.BaseDirectory, "AthenaOtaUpdater.exe");

            string message = BootIntegrationService.EnsureLogonTask(
                exePath,
                _settings.BootTaskName,
                Log);

            _status(message);
        }
        catch (Exception ex)
        {
            // Do not block update checks if registration fails (e.g. first run without rights).
            Log("Boot task registration failed: " + ex);
            _status(
                "Boot task not registered. Run Install-BootIntegration.ps1 as kadmin once. " +
                ex.Message);
        }
    }

    // ---------------------------------------------------------
    // UTILITIES
    // ---------------------------------------------------------

    private static Uri ValidateApiEndpoint(string endpoint)
    {
        if (!Uri.TryCreate(
            endpoint,
            UriKind.Absolute,
            out var uri))
        {
            throw new InvalidOperationException(
                "Version API endpoint is missing or invalid.");
        }

        if (uri.Scheme != Uri.UriSchemeHttps &&
            !(uri.Scheme == Uri.UriSchemeHttp && uri.IsLoopback))
        {
            throw new InvalidOperationException(
                "API endpoint must use HTTPS.");
        }

        return uri;
    }

    private static JsonSerializerOptions JsonOptions()
    {
        return new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };
    }

    private void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(_settings.WorkDirectory);

            File.AppendAllText(
                Path.Combine(
                    _settings.WorkDirectory,
                    "updater.log"),
                $"[{DateTimeOffset.Now:O}] {message}{Environment.NewLine}");
        }
        catch
        {
            // Logging must not crash the updater.
        }
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
                File.Delete(path);
        }
        catch
        {
            // Best-effort cleanup.
        }
    }

    public void Dispose()
    {
        _loopCts?.Cancel();
        _loopCts?.Dispose();

        _apiHttp.Dispose();
        _downloadHttp.Dispose();

        _gate.Dispose();
    }

    // ---------------------------------------------------------
    // SETTINGS
    // ---------------------------------------------------------

    public sealed class Settings
    {
        public string VersionCheckApiUrl { get; set; } = "";

        public string ApiKey { get; set; } = "";

        public string KioskId { get; set; } = "";

        public int ApiTimeoutMinutes { get; set; } = 5;

        public string InstallDirectory { get; set; }
            = @"C:\AthenaOTA\App";

        public string BackupDirectory { get; set; }
            = @"C:\AthenaOTA\Backup";

        public string WorkDirectory { get; set; }
            = @"C:\AthenaOTA\Updates";

        public string ExecutableName { get; set; }
            = "skp_kiosk.exe";

        public int CheckIntervalMinutes { get; set; } = 15;

        public int IdleMinutes { get; set; } = 1;

        public string StartupArguments { get; set; } = "";

        public int HealthCheckSeconds { get; set; } = 15;

        public bool KeepBackup { get; set; } = true;

        public int MaxPackageSizeMB { get; set; } = 500;

        public int MaxExtractedSizeMB { get; set; } = 1500;

        /// <summary>
        /// When true, ensure a Task Scheduler ONLOGON task exists for this executable.
        /// Needed on Shell Launcher kiosks where explorer Startup/Run never run.
        /// </summary>
        public bool EnsureBootTask { get; set; } = true;

        public string BootTaskName { get; set; } =
            BootIntegrationService.DefaultTaskName;
    }
}
