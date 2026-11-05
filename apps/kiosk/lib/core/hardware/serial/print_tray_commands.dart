/// ESP32 print-tray JSON protocol (shutter + roller on the SPPC controller).
///
/// `{"print":"start"}` → after delay: open shutter and run roller.
/// `{"print":"done"}`  → after delay: stop roller and close shutter.
/// `{"print":"stop"}`  → immediate stop + close.
class PrintTrayCommands {
  PrintTrayCommands._();

  static String start() => '{"print":"start"}';

  static String done() => '{"print":"done"}';

  static String stop() => '{"print":"stop"}';
}
