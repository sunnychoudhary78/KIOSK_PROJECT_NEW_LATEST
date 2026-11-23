using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Reflection;
using System.Threading;

namespace SkpPrinterUsb
{
    /// <summary>
    /// Brother HttpToUsbBridge is a per-user process (not a Windows service).
    /// Opening the USB EWS requires Brother's BridgeClient.GetDeviceUrl — a raw
    /// control-port string returns 400 and never brings up :60910. That is why
    /// ink/pages only appeared after logging into kadmin (Brother UI opens the
    /// device) and then switching to the kiosk user.
    /// </summary>
    static class BridgeEnsure
    {
        const string ProcessName = "HttpToUsbBridge";
        const string RelativeExe = @"Brother\HttpToUsbBridge\HttpToUsbBridge.exe";
        const string RelativeClientDll = @"Brother\BrLauncher\HttpToUsbBridge.NetFramework.dll";
        const int ControlPort = 50000;
        const int DefaultEwsPort = 60910;
        const string DefaultVid = "04f9";
        const string DefaultPid = "0714"; // DCP-T830DW

        static DateTime _lastStartAttemptUtc = DateTime.MinValue;
        static DateTime _lastClientAttemptUtc = DateTime.MinValue;
        static string _resolvedBaseUrl;
        static object _bridgeClient;
        static MethodInfo _getDeviceUrl;
        static bool _clientLookupDone;

        public static string BaseUrl
        {
            get { return string.IsNullOrEmpty(_resolvedBaseUrl) ? "http://127.0.0.1:" + DefaultEwsPort : _resolvedBaseUrl; }
        }

        /// <summary>
        /// Starts the bridge if needed and opens the USB EWS URL when possible.
        /// Safe to call on every capture; client calls are rate-limited slightly.
        /// </summary>
        public static void EnsureRunning()
        {
            // Prefer Brother's managed client: it launches the bridge and opens
            // the device (EWS). Our handmade control-port GET returns 400.
            if (TryOpenWithBrotherClient())
            {
                return;
            }

            if (!IsProcessRunning())
            {
                TryStartProcess();
            }

            if (!WaitForPort(ControlPort, TimeSpan.FromSeconds(4)))
            {
                return;
            }

            // Client may have loaded on a later poll after the DLL path is ready.
            TryOpenWithBrotherClient();
        }

        static bool TryOpenWithBrotherClient()
        {
            if (!EnsureBrotherClient())
            {
                return false;
            }

            // Avoid hammering USB open on the 2s poll while the printer is unplugged.
            if (DateTime.UtcNow - _lastClientAttemptUtc < TimeSpan.FromSeconds(3) &&
                !string.IsNullOrEmpty(_resolvedBaseUrl) &&
                CanConnect(DefaultEwsPortFromBase()))
            {
                return true;
            }
            _lastClientAttemptUtc = DateTime.UtcNow;

            try
            {
                string vid;
                string pid;
                ReadVidPid(out vid, out pid);

                // Tuple<ResultCode, string> GetDeviceUrl(string vid, string pid)
                var result = _getDeviceUrl.Invoke(_bridgeClient, new object[] { vid, pid });
                if (result == null) return false;

                var item1 = result.GetType().GetProperty("Item1");
                var item2 = result.GetType().GetProperty("Item2");
                if (item1 == null || item2 == null) return false;

                var code = item1.GetValue(result, null);
                var url = item2.GetValue(result, null) as string;
                var codeName = code == null ? "" : code.ToString();

                if (!string.Equals(codeName, "NoErrors", StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }

                if (string.IsNullOrWhiteSpace(url))
                {
                    if (CanConnect(DefaultEwsPort))
                    {
                        _resolvedBaseUrl = "http://127.0.0.1:" + DefaultEwsPort;
                        return true;
                    }
                    return false;
                }

                _resolvedBaseUrl = NormalizeBaseUrl(url);
                WaitForPort(DefaultEwsPortFromBase(), TimeSpan.FromSeconds(3));
                return true;
            }
            catch
            {
                return false;
            }
        }

        static bool EnsureBrotherClient()
        {
            if (_clientLookupDone && _getDeviceUrl != null && _bridgeClient != null)
            {
                return true;
            }
            if (_clientLookupDone && _getDeviceUrl == null)
            {
                return false;
            }

            _clientLookupDone = true;
            try
            {
                var dllPath = ResolveBrotherClientDll();
                if (dllPath == null) return false;

                var assembly = Assembly.LoadFrom(dllPath);
                var type = assembly.GetType("HttpToUsbBridgeClient.BridgeClient");
                if (type == null) return false;

                _bridgeClient = Activator.CreateInstance(type);
                _getDeviceUrl = type.GetMethod("GetDeviceUrl", new[] { typeof(string), typeof(string) });
                return _bridgeClient != null && _getDeviceUrl != null;
            }
            catch
            {
                _getDeviceUrl = null;
                _bridgeClient = null;
                return false;
            }
        }

        static string ResolveBrotherClientDll()
        {
            var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrEmpty(pf86))
            {
                var candidate = Path.Combine(pf86, RelativeClientDll);
                if (File.Exists(candidate)) return candidate;
            }

            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            if (!string.IsNullOrEmpty(pf))
            {
                var candidate = Path.Combine(pf, RelativeClientDll);
                if (File.Exists(candidate)) return candidate;
            }

            return null;
        }

        static bool IsProcessRunning()
        {
            try
            {
                var processes = Process.GetProcessesByName(ProcessName);
                try
                {
                    return processes != null && processes.Length > 0;
                }
                finally
                {
                    if (processes != null)
                    {
                        for (var i = 0; i < processes.Length; i++)
                        {
                            processes[i].Dispose();
                        }
                    }
                }
            }
            catch
            {
                return false;
            }
        }

        static void TryStartProcess()
        {
            if (DateTime.UtcNow - _lastStartAttemptUtc < TimeSpan.FromSeconds(20))
            {
                return;
            }
            _lastStartAttemptUtc = DateTime.UtcNow;

            var path = ResolveBridgeExe();
            if (path == null) return;

            try
            {
                // Match kiosk_shell.bat: start "" /MIN — Brother needs a normal
                // shell launch; CreateNoWindow often leaves EWS closed.
                var start = new ProcessStartInfo
                {
                    FileName = path,
                    WorkingDirectory = Path.GetDirectoryName(path) ?? "",
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Minimized,
                };
                using (var process = Process.Start(start))
                {
                    // Detach — bridge stays resident for the user session.
                }
            }
            catch
            {
                // Next poll retries.
            }
        }

        static string ResolveBridgeExe()
        {
            var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrEmpty(pf86))
            {
                var candidate = Path.Combine(pf86, RelativeExe);
                if (File.Exists(candidate)) return candidate;
            }

            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            if (!string.IsNullOrEmpty(pf))
            {
                var candidate = Path.Combine(pf, RelativeExe);
                if (File.Exists(candidate)) return candidate;
            }

            return null;
        }

        static bool WaitForPort(int port, TimeSpan budget)
        {
            var deadline = DateTime.UtcNow + budget;
            while (DateTime.UtcNow < deadline)
            {
                if (CanConnect(port)) return true;
                Thread.Sleep(200);
            }
            return CanConnect(port);
        }

        static bool CanConnect(int port)
        {
            try
            {
                using (var client = new TcpClient())
                {
                    var result = client.BeginConnect("127.0.0.1", port, null, null);
                    var ok = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(400));
                    if (!ok) return false;
                    client.EndConnect(result);
                    return client.Connected;
                }
            }
            catch
            {
                return false;
            }
        }

        static int DefaultEwsPortFromBase()
        {
            try
            {
                var uri = new Uri(BaseUrl);
                return uri.Port > 0 ? uri.Port : DefaultEwsPort;
            }
            catch
            {
                return DefaultEwsPort;
            }
        }

        static void ReadVidPid(out string vid, out string pid)
        {
            vid = DefaultVid;
            pid = DefaultPid;
            try
            {
                using (var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                    @"SOFTWARE\WOW6432Node\Brother\Brother MFL-Pro\BrMfInfo\DCP-T830DW"))
                {
                    if (key == null) return;
                    var usbPid = key.GetValue("USBPID") as string;
                    if (string.IsNullOrEmpty(usbPid)) return;
                    // USB\Vid_04f9&Pid_0714
                    var lower = usbPid.ToLowerInvariant();
                    var vidAt = lower.IndexOf("vid_", StringComparison.Ordinal);
                    var pidAt = lower.IndexOf("pid_", StringComparison.Ordinal);
                    if (vidAt >= 0 && vidAt + 4 + 4 <= lower.Length)
                    {
                        vid = lower.Substring(vidAt + 4, 4);
                    }
                    if (pidAt >= 0 && pidAt + 4 + 4 <= lower.Length)
                    {
                        pid = lower.Substring(pidAt + 4, 4);
                    }
                }
            }
            catch
            {
                // keep defaults
            }
        }

        static string NormalizeBaseUrl(string url)
        {
            try
            {
                var uri = new Uri(url);
                return uri.GetLeftPart(UriPartial.Authority);
            }
            catch
            {
                return url.TrimEnd('/');
            }
        }
    }
}
