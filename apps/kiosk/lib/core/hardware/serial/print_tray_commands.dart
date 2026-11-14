/// ESP32 print-tray JSON protocol (shutter + roller on the SPPC controller).
///
/// Aligned with `firmware/sppc_controller/new.ino`:
/// `{"print":"start"}` → after 3s: open shutter (and roller if enabled).
/// `{"print":"done"}`  → after 5s: stop motor + close shutter. The app sends
/// this only after the USB page count verifies the job (Print successful).
/// `{"print":"stop"}`  → immediate close. Firmware accepts it; the app does
/// not send it. If `done` never arrives, the firmware aborts after 240s
/// (`PRINT_MAX_S`); open shutter also auto-closes after 300s idle.
///
/// Admin manual open/close uses [ShutterCommands], not these print commands.
class PrintTrayCommands {
  PrintTrayCommands._();

  static String start() => '{"print":"start"}';

  static String done() => '{"print":"done"}';

  static String stop() => '{"print":"stop"}';
}
