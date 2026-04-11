import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures Flutter debug output and unhandled errors to a rotating log file.
///
/// Log file: `~/.config/yoloit/app.log` (kept ≤ 5 MB, rotated on start).
/// Enabled/disabled via SharedPreferences key [_enabledKey].
///
/// Usage:
/// ```dart
/// await AppLogger.instance.init();
/// AppLogger.instance.install(); // hooks debugPrint and FlutterError
/// ```
class AppLogger {
  AppLogger._();
  static final instance = AppLogger._();

  static const _enabledKey = 'app_logging_enabled_v1';
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB

  bool _enabled = false;
  bool get enabled => _enabled;

  IOSink? _sink;

  // Saved originals so we can restore on disable
  DebugPrintCallback? _originalDebugPrint;

  // ──────────────────────────────────────────────────────────── lifecycle ──

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true; // on by default
  }

  /// Hooks [debugPrint] and [FlutterError.onError]. Call once after [init].
  void install() {
    if (!_enabled) return;
    _startSink();
    _hookDebugPrint();
    _hookFlutterError();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (value) {
      _startSink();
      _hookDebugPrint();
      _hookFlutterError();
    } else {
      _unhookDebugPrint();
      await _closeSink();
    }
  }

  // ──────────────────────────────────────────────────────────── public ──

  /// Path to the current log file (may not exist yet if logging is off).
  Future<String> get logPath async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Library/Logs/yoloit/app.log';
  }

  Future<String> readLog() async {
    final path = await logPath;
    final f = File(path);
    if (!f.existsSync()) return '(no log file)';
    return f.readAsString();
  }

  Future<void> clearLog() async {
    await _closeSink();
    final path = await logPath;
    final f = File(path);
    if (f.existsSync()) await f.delete();
    if (_enabled) _startSink();
  }

  // ──────────────────────────────────────────────────────── internals ──

  void _startSink() {
    _openFile().then((f) {
      _sink = f.openWrite(mode: FileMode.append);
      _writeLine('');
      _writeLine('══════ yoloit started ${DateTime.now().toIso8601String()} ══════');
    }).catchError((e) {
      // Ignore — file logging unavailable (e.g. permission issue)
    });
  }

  Future<File> _openFile() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    // Write to ~/Library/Logs/yoloit/ to respect macOS sandbox app container
    // while still being easily accessible.
    final dir = Directory('$home/Library/Logs/yoloit');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final f = File('${dir.path}/app.log');
    // Rotate if > 5 MB
    if (f.existsSync() && f.statSync().size > _maxBytes) {
      f.renameSync('${dir.path}/app.log.1');
      return File('${dir.path}/app.log');
    }
    return f;
  }

  void _writeLine(String line) {
    if (_sink == null) return;
    final ts = DateTime.now().toIso8601String();
    _sink!.writeln('$ts  $line');
  }

  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }

  void _hookDebugPrint() {
    _originalDebugPrint ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
      if (_sink != null && message != null) _writeLine(message);
    };
  }

  void _unhookDebugPrint() {
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
  }

  void _hookFlutterError() {
    final original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      original?.call(details);
      _writeLine('[FlutterError] ${details.exceptionAsString()}');
      _writeLine(details.stack.toString());
    };
  }
}
