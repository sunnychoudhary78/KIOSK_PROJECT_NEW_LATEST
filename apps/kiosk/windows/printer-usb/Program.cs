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
                var session = new UsbSession();
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
                            var full = request != null &&
                                       request.IndexOf("\"full\"", StringComparison.OrdinalIgnoreCase) >= 0;
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
                if (buffer.Length > 4096) break;
            }
            return buffer.ToString();
        }
    }
}
