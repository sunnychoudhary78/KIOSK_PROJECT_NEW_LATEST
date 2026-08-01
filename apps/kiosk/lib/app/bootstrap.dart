import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppLogger.info('Kiosk bootstrap complete');
}
