import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yoloit/app.dart';
import 'package:yoloit/core/theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeManager.instance.load();

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

  runApp(const App());
}
