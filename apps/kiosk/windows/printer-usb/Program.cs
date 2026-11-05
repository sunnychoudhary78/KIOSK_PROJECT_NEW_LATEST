using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading;

namespace SkpPrinterUsb
{
    static class Program
    {
        const string MutexName = @"Local\skp-printer-usb";
        const string PipeName = "skp-brother-usb";

        static int Main()
        {
            bool created;
            Mutex mutex;
            try
            {
                mutex = new Mutex(true, MutexName, out created);
            }
            catch (AbandonedMutexException)
            {
                mutex = new Mutex(true, MutexName, out created);
            }
            using (mutex)
            {
                if (!created) return 0;
                using (var session = new HttpBridgeSession())
                {
                    while (true)
                    {
                        using (var pipe = new NamedPipeServerStream(
                            PipeName,
                            PipeDirection.InOut,
                            1,
                            PipeTransmissionMode.Byte,
                            PipeOptions.Asynchronous))
                        {
                            pipe.WaitForConnection();
                            try
                            {
                                var request = ReadLine(pipe);
                                var full = RequestHasFull(request);
                                var password = ExtractJsonString(request, "password");
                                session.SetPassword(password);
                                var json = session.Capture(full).ToJson();
                                var payload = Encoding.UTF8.GetBytes(json + "\n");
                                pipe.Write(payload, 0, payload.Length);
                                pipe.Flush();
                            }
                            catch (Exception ex)
                            {
                                try
                                {
                                    var json = Snapshot.Fail(ex.GetBaseException().Message).ToJson();
                                    var payload = Encoding.UTF8.GetBytes(json + "\n");
                                    pipe.Write(payload, 0, payload.Length);
                                    pipe.Flush();
                                }
                                catch
                                {
                                    // The kiosk retries the next poll.
                                }
                            }
                            try { pipe.Disconnect(); }
                            catch { /* already closed */ }
                        }
                    }
                }
            }
        }

        static bool RequestHasFull(string request)
        {
            if (string.IsNullOrEmpty(request)) return false;
            return request.IndexOf("\"full\"", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        /// <summary>
        /// Minimal JSON string field reader. Does not log the request (may contain password).
        /// </summary>
        static string ExtractJsonString(string json, string name)
        {
            if (string.IsNullOrEmpty(json) || string.IsNullOrEmpty(name)) return null;
            var key = "\"" + name + "\"";
            var start = json.IndexOf(key, StringComparison.OrdinalIgnoreCase);
            if (start < 0) return null;
            var colon = json.IndexOf(':', start + key.Length);
            if (colon < 0) return null;
            var i = colon + 1;
            while (i < json.Length && char.IsWhiteSpace(json[i])) i++;
            if (i >= json.Length || json[i] != '"') return null;
            i++;
            var sb = new StringBuilder();
            while (i < json.Length)
            {
                var c = json[i++];
                if (c == '\\' && i < json.Length)
                {
                    var next = json[i++];
                    if (next == 'n') sb.Append('\n');
                    else if (next == 'r') sb.Append('\r');
                    else if (next == 't') sb.Append('\t');
                    else sb.Append(next);
                    continue;
                }
                if (c == '"') break;
                sb.Append(c);
            }
            var value = sb.ToString();
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }

        static string ReadLine(Stream stream)
        {
            var buffer = new StringBuilder();
            var one = new byte[1];
            while (true)
            {
                var read = stream.Read(one, 0, 1);
                if (read == 0) break;
                var c = (char)one[0];
                if (c == '\n') break;
                if (c != '\r') buffer.Append(c);
                // Password may be present; keep room for a normal request line.
                if (buffer.Length > 8192) break;
            }
            return buffer.ToString();
        }
    }
}
