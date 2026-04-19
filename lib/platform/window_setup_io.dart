import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

export 'package:window_manager/window_manager.dart' show WindowListener, windowManager;

Future<void> initWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(900, 600),
    center: true,
    title: 'YoLoIT',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
