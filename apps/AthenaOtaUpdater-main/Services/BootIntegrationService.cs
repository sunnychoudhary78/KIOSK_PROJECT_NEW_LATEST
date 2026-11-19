using System.Diagnostics;
using System.IO;
using System.Text;

namespace AthenaOtaUpdater.Services;

/// <summary>
/// Registers AthenaOtaUpdater as a Windows Scheduled Task that starts at user logon.
/// Required on Shell Launcher kiosks because explorer.exe (and its Startup/Run entries) never load.
/// </summary>
public static class BootIntegrationService
{
    public const string DefaultTaskName = "AthenaOtaUpdater";

    public static string EnsureLogonTask(
        string executablePath,
        string taskName,
        Action<string>? log = null)
    {
        if (string.IsNullOrWhiteSpace(executablePath))
            throw new ArgumentException("Executable path is required.", nameof(executablePath));

        if (string.IsNullOrWhiteSpace(taskName))
            taskName = DefaultTaskName;

        string exe = Path.GetFullPath(executablePath);

        if (!File.Exists(exe))
            throw new FileNotFoundException("Updater executable was not found.", exe);

        if (TaskExistsWithSameAction(taskName, exe, log))
        {
            log?.Invoke($"Boot task '{taskName}' is already registered for this executable.");
            return $"Boot task '{taskName}' already registered.";
        }

        // ONLOGON + /IT runs in the interactive user session after Autologon,
        // which is what Shell Launcher kiosks need (WPF + same-session process checks).
        string quotedExe = QuoteForSchtasks(exe);

        var create = RunSchtasks(
            $"/Create /TN \"{taskName}\" /TR {quotedExe} /SC ONLOGON /RL LIMITED /IT /F",
            log);

        if (create.ExitCode != 0)
        {
            throw new InvalidOperationException(
                "Failed to register boot scheduled task. " +
                "Run Install-BootIntegration.ps1 once as an administrator (kadmin). " +
                $"Details: {create.Output}");
        }

        log?.Invoke($"Boot task '{taskName}' registered for logon: {exe}");
        return $"Boot task '{taskName}' registered for logon.";
    }

    public static void RemoveLogonTask(string taskName, Action<string>? log = null)
    {
        if (string.IsNullOrWhiteSpace(taskName))
            taskName = DefaultTaskName;

        if (!TaskExists(taskName))
        {
            log?.Invoke($"Boot task '{taskName}' was not present.");
            return;
        }

        var result = RunSchtasks($"/Delete /TN \"{taskName}\" /F", log);

        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"Failed to remove boot task '{taskName}': {result.Output}");
        }

        log?.Invoke($"Boot task '{taskName}' removed.");
    }

    private static bool TaskExistsWithSameAction(
        string taskName,
        string expectedExe,
        Action<string>? log)
    {
        if (!TaskExists(taskName))
            return false;

        var query = RunSchtasks($"/Query /TN \"{taskName}\" /V /FO LIST", log);

        if (query.ExitCode != 0)
            return false;

        string normalizedExpected = Path.GetFullPath(expectedExe)
            .Trim('"');

        foreach (string line in query.Output.Split(
                     new[] { '\r', '\n' },
                     StringSplitOptions.RemoveEmptyEntries))
        {
            // English locale: "Task To Run:" — also accept generic "Task To Run"
            int separator = line.IndexOf(':');
            if (separator < 0)
                continue;

            string key = line[..separator].Trim();
            string value = line[(separator + 1)..].Trim().Trim('"');

            if (!key.Contains("Task To Run", StringComparison.OrdinalIgnoreCase) &&
                !key.Contains("Task to Run", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            // Value may include arguments; compare on the executable path portion.
            string candidate = value;
            if (candidate.StartsWith('"'))
            {
                int end = candidate.IndexOf('"', 1);
                candidate = end > 0 ? candidate[1..end] : candidate.Trim('"');
            }
            else
            {
                int space = candidate.IndexOf(' ');
                if (space > 0)
                    candidate = candidate[..space];
            }

            try
            {
                candidate = Path.GetFullPath(candidate);
            }
            catch
            {
                // Keep raw candidate for comparison.
            }

            if (string.Equals(
                    candidate,
                    normalizedExpected,
                    StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            log?.Invoke(
                $"Boot task '{taskName}' points to a different path. Recreating. " +
                $"Was: {value}");
            return false;
        }

        // Task exists but we could not confirm the action (locale differences).
        // Recreate to keep the path correct.
        log?.Invoke(
            $"Boot task '{taskName}' exists but action path could not be verified. Recreating.");
        return false;
    }

    private static bool TaskExists(string taskName)
    {
        var query = RunSchtasks($"/Query /TN \"{taskName}\"", log: null);
        return query.ExitCode == 0;
    }

    private static string QuoteForSchtasks(string path)
    {
        // schtasks expects the /TR value quoted when the path contains spaces.
        return $"\"{path}\"";
    }

    private static (int ExitCode, string Output) RunSchtasks(
        string arguments,
        Action<string>? log)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "schtasks.exe",
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            // Avoid locale-dependent parsing issues where possible; query still varies by UI language.
            StandardOutputEncoding = Encoding.Default,
            StandardErrorEncoding = Encoding.Default
        };

        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Could not start schtasks.exe.");

        string stdout = process.StandardOutput.ReadToEnd();
        string stderr = process.StandardError.ReadToEnd();
        process.WaitForExit(15000);

        string output = (stdout + Environment.NewLine + stderr).Trim();
        log?.Invoke($"schtasks {arguments} => exit {process.ExitCode}. {output}");

        return (process.ExitCode, output);
    }
}
