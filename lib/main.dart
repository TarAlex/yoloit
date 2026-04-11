import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yoloit/app.dart';
import 'package:yoloit/core/hotkeys/hotkey_registry.dart';
import 'package:yoloit/core/services/resource_monitor_service.dart';
import 'package:yoloit/core/theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress Flutter keyboard state assertion errors that occur when the PTY
  // terminal emulator causes macOS to re-inject key events (duplicate KeyDown).
  // This is a known Flutter + terminal emulator issue and does not indicate a
  // real application bug.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('_pressedKeys.containsKey') ||
        msg.contains('physical key is already pressed') ||
        msg.contains('KeyDownEvent is dispatched')) {
      return; // suppress — terminal PTY duplicate key events
    }
    originalOnError?.call(details);
  };

  await ThemeManager.instance.load();
  await HotkeyRegistry.instance.load();

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(900, 600),
    center: true,
    title: 'yoloit',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  ResourceMonitorService.instance.start();
  runApp(const App());
}
