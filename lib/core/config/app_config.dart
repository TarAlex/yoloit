import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Lightweight per-user config stored at ~/.yoloit/config.json.
/// Unlike SharedPreferences this file is shared across all builds
/// (production, debug, any future variant) because it lives in a
/// well-known location that is NOT tied to the app bundle identifier.
class AppConfig {
  AppConfig._();

  static final instance = AppConfig._();

  static File get _file {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final dir = Directory(p.join(home, '.yoloit'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File(p.join(dir.path, 'config.json'));
  }

  Map<String, dynamic> _data = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = _file;
      if (f.existsSync()) {
        final raw = f.readAsStringSync();
        if (raw.trim().isNotEmpty) {
          _data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        }
      }
    } catch (_) {
      _data = {};
    }
    _loaded = true;
  }

  Future<void> _save() async {
    _file.writeAsStringSync(jsonEncode(_data));
  }

  // ── Workspaces storage path ─────────────────────────────────────────────

  static const _kWorkspacesFile = 'workspacesFile';

  /// Default path to the shared workspaces JSON file.
  static String get defaultWorkspacesFilePath {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.yoloit', 'workspaces.json');
  }

  /// Path to the shared workspaces JSON file.
  /// Defaults to ~/.yoloit/workspaces.json.
  String get workspacesFilePath {
    final v = _data[_kWorkspacesFile];
    if (v is String && v.isNotEmpty) return v;
    return defaultWorkspacesFilePath;
  }

  bool get hasCustomWorkspacesPath => _data[_kWorkspacesFile] is String;

  Future<void> setWorkspacesFilePath(String path) async {
    _data[_kWorkspacesFile] = path;
    await _save();
  }

  Future<void> resetWorkspacesFilePath() async {
    _data.remove(_kWorkspacesFile);
    await _save();
  }
}
