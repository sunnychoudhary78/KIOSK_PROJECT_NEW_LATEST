using System.Runtime.InteropServices;
namespace AthenaOtaUpdater.Services;

public static class WindowsIdleDetector
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static TimeSpan GetIdleTime()
    {
        var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
        if (!GetLastInputInfo(ref info)) return TimeSpan.Zero;
        uint tick = unchecked((uint)Environment.TickCount);
        uint elapsed = tick - info.dwTime;
        return TimeSpan.FromMilliseconds(elapsed);
    }
}
