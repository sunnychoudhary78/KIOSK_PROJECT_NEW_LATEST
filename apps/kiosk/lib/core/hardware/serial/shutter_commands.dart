/// Manual shutter JSON for admin overrides (SPPC `new.ino`).
///
/// Print jobs must keep using [PrintTrayCommands] (`print:start` / `done`).
/// These commands start the servo move immediately (no print delays).
class ShutterCommands {
  ShutterCommands._();

  static String open() => '{"shutter":"open"}';

  static String close() => '{"shutter":"close"}';
}
