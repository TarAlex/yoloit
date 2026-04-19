import 'package:flutter/widgets.dart';
import 'package:yoloit/app_guest.dart';

/// Web entry point — only loads guest app, no native dependencies.
/// Build with: flutter build web --target lib/main_web.dart
void main() {
  runApp(const GuestApp());
}
