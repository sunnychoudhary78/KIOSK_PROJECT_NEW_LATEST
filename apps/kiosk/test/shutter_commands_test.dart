import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/hardware/serial/print_tray_commands.dart';
import 'package:skp_kiosk/core/hardware/serial/shutter_commands.dart';

void main() {
  test('admin shutter commands are distinct from print tray protocol', () {
    expect(ShutterCommands.open(), '{"shutter":"open"}');
    expect(ShutterCommands.close(), '{"shutter":"close"}');
    expect(PrintTrayCommands.start(), '{"print":"start"}');
    expect(PrintTrayCommands.done(), '{"print":"done"}');
    expect(ShutterCommands.open(), isNot(PrintTrayCommands.start()));
    expect(ShutterCommands.close(), isNot(PrintTrayCommands.done()));
  });
}
