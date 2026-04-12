import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// File-based logging for terminal session output.
///
/// Logs are written to `~/.yoloit/logs/` as plain-text files with ANSI codes
/// intact (viewable with `cat -v` or `less -R`).
class LoggingService {
  LoggingService._();
  static final instance = LoggingService._();

  static const _enabledKey = 'logging_enabled_v1';

  bool _enabled = false;
  bool get enabled => _enabled;

  final Map<String, IOSink> _sinks = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) await _closeAllSinks();
  }

  Future<Directory> get logsDir async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final dir = Directory('$home/.yoloit/logs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> startSession(String sessionId, String label) async {
    if (!_enabled) return;
    final dir = await logsDir;
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '-${now.minute.toString().padLeft(2, '0')}'
        '-${now.second.toString().padLeft(2, '0')}';
    final safeId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/${stamp}_$safeId.log');
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln('# YoLoIT session log — $label — $stamp');
    sink.writeln('# ─────────────────────────────────────');
    _sinks[sessionId] = sink;
  }

  void write(String sessionId, String data) {
    if (!_enabled) return;
    _sinks[sessionId]?.write(data);
  }

  Future<void> endSession(String sessionId) async {
    final sink = _sinks.remove(sessionId);
    if (sink == null) return;
    sink.writeln('\n# ─── session ended ───');
    await sink.flush();
    await sink.close();
  }

  Future<List<LogFile>> listLogs() async {
    final dir = await logsDir;
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
    return files.map((f) {
      final stat = f.statSync();
      return LogFile(path: f.path, size: stat.size, modified: stat.modified);
    }).toList();
  }

  Future<String> readLog(String path) async => File(path).readAsString();

  Future<void> deleteLog(String path) async => File(path).delete();

  Future<void> clearAll() async {
    await _closeAllSinks();
    final dir = await logsDir;
    if (!dir.existsSync()) return;
    for (final f
        in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.log'))) {
      await f.delete();
    }
  }

  Future<void> _closeAllSinks() async {
    for (final sink in _sinks.values) {
      await sink.flush();
      await sink.close();
    }
    _sinks.clear();
  }
}

class LogFile {
  const LogFile({
    required this.path,
    required this.size,
    required this.modified,
  });

  final String path;
  final int size;
  final DateTime modified;

  String get name => path.split('/').last;

  String get sizeLabel {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
