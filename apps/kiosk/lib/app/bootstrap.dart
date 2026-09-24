import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await _configureWindow();
  AppLogger.info('Kiosk bootstrap complete');
}

Future<void> _configureWindow() async {
  try {
    await windowManager.ensureInitialized();
    const debugSize = Size(1280, 720);
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: kDebugMode ? debugSize : null,
        center: kDebugMode,
        minimumSize: kDebugMode ? debugSize : null,
        skipTaskbar: false,
        titleBarStyle: kDebugMode ? TitleBarStyle.normal : TitleBarStyle.hidden,
        fullScreen: false,
      ),
    );
    await windowManager.show();
    await windowManager.focus();
    if (!kDebugMode) {
      await windowManager.setFullScreen(true);
    }
  } catch (error) {
    AppLogger.error('Window configure failed; continuing with native chrome', error);
  }
}
