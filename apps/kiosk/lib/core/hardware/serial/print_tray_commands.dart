/// ESP32 print-tray JSON protocol (shutter + roller on the SPPC controller).
///
/// `{"print":"start"}` → after delay: open shutter and run roller.
/// `{"print":"done"}`  → close the shutter immediately. The app sends this
/// only after the USB page count verifies the job (Print successful).
/// `{"print":"stop"}`  → immediate close. Firmware accepts it; the app does
/// not send it. If `done` never arrives, the firmware closes after 5 minutes.
class PrintTrayCommands {
  PrintTrayCommands._();

  static String start() => '{"print":"start"}';

  static String done() => '{"print":"done"}';

  static String stop() => '{"print":"stop"}';
}
