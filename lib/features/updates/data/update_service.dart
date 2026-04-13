import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:yoloit/core/session/session_prefs.dart';

// ── UpdateInfo ────────────────────────────────────────────────────────────────

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseUrl,
    required this.releaseNotes,
    this.downloadUrl,
  });

  /// Clean version string, e.g. "0.0.2"
  final String version;

  /// Tag as published on GitHub, e.g. "v0.0.2"
  final String tagName;

  /// HTML release page URL.
  final String releaseUrl;

  /// Markdown release notes body.
  final String releaseNotes;

  /// Direct DMG/asset download URL (first .dmg asset, if present).
  final String? downloadUrl;
}

// ── UpdateService ─────────────────────────────────────────────────────────────

class UpdateService {
  const UpdateService._();

  static const _owner = 'IstiN';
  static const _repo = 'yoloit';

  /// Current app version — read from Info.plist at runtime.
  /// Falls back to pubspec version if plist read fails.
  static String? _cachedVersion;
  static const _fallbackVersion = '0.0.11';

  static Future<String> getAppVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      // Read CFBundleShortVersionString from running app's Info.plist
      final executable = Platform.resolvedExecutable;
      // .app/Contents/MacOS/YoLoIT → .app
      final appBundle = executable
          .split('/Contents/')
          .first;
      final plistPath = '$appBundle/Contents/Info.plist';
      final result = await Process.run(
        '/usr/bin/defaults',
        ['read', plistPath, 'CFBundleShortVersionString'],
      );
      if (result.exitCode == 0) {
        _cachedVersion = (result.stdout as String).trim();
        return _cachedVersion!;
      }
    } catch (_) {}
    _cachedVersion = _fallbackVersion;
    return _fallbackVersion;
  }

  /// Synchronous getter for cached version (after first async call).
  static String get currentVersion => _cachedVersion ?? _fallbackVersion;

  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// True when running in debug/profile mode (flutter run, DevTools, IDE).
  /// Release builds produced by `flutter build macos --release` return false.
  static bool get isDevBuild => kDebugMode || kProfileMode;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks GitHub for a newer release.
  /// Returns [UpdateInfo] when an update is available, null otherwise.
  /// Also updates the last-check timestamp in prefs.
  ///
  /// Pass [force] = true to skip the dev-build guard (e.g. "Check Now" button).
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    // Never auto-check in dev builds — only allow manual force-check
    if (!force && isDevBuild) return null;

    try {
      final appVersion = await getAppVersion();
      final info = await _fetchLatestRelease();
      await SessionPrefs.saveLastUpdateCheckMs(
          DateTime.now().millisecondsSinceEpoch);
      if (info == null) return null;

      final skipped = await SessionPrefs.getSkippedVersion();
      if (skipped == info.version) return null; // user dismissed this version

      return _isNewer(info.version, appVersion) ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Opens the release page in the system browser (fallback).
  static Future<void> openRelease(UpdateInfo info) async {
    final url = info.releaseUrl;
    await Process.run('open', [url]);
  }

  /// Downloads the DMG, mounts it, copies the app to /Applications, relaunches.
  /// [onProgress] receives values 0.0–1.0 during download, then null during install steps.
  /// Throws on failure.
  static Future<void> downloadAndInstall(
    UpdateInfo info, {
    required void Function(double? progress, String status) onProgress,
  }) async {
    final dmgUrl = info.downloadUrl;
    if (dmgUrl == null) {
      // No DMG — open browser as fallback
      await openRelease(info);
      return;
    }

    // 1. Download DMG
    onProgress(0.0, 'Downloading…');
    final tmpDir = Directory.systemTemp.createTempSync('yoloit_update_');
    final dmgFile = File('${tmpDir.path}/YoLoIT.dmg');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(dmgUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'YoLoIT/$currentVersion');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('Download failed: HTTP ${resp.statusCode}');
      }

      final total = resp.contentLength;
      var received = 0;
      final sink = dmgFile.openWrite();
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total, 'Downloading…');
      }
      await sink.close();
    } finally {
      client.close();
    }

    // 2. Mount DMG
    onProgress(null, 'Mounting…');
    final mountPoint = '${tmpDir.path}/vol';
    await Directory(mountPoint).create();
    final mount = await Process.run('hdiutil', [
      'attach', dmgFile.path,
      '-nobrowse',
      '-mountpoint', mountPoint,
    ]);
    if (mount.exitCode != 0) {
      throw Exception('Mount failed: ${mount.stderr}');
    }

    try {
      // 3. Find .app inside the mounted volume
      onProgress(null, 'Installing…');
      final volDir = Directory(mountPoint);
      final appEntry = volDir
          .listSync()
          .whereType<Directory>()
          .firstWhere(
            (d) => d.path.endsWith('.app'),
            orElse: () => throw Exception('No .app found in DMG'),
          );

      // 4. Copy to /Applications using ditto (preserves code signature)
      final appName = appEntry.path.split('/').last;
      final dest = '/Applications/$appName';
      final ditto = await Process.run('ditto', [appEntry.path, dest]);
      if (ditto.exitCode != 0) {
        throw Exception('Copy failed: ${ditto.stderr}');
      }

      // 5. Relaunch from /Applications
      onProgress(null, 'Relaunching…');
      await Process.run('open', [dest]);
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } finally {
      // Always unmount
      await Process.run('hdiutil', ['detach', mountPoint, '-force']);
      try { tmpDir.deleteSync(recursive: true); } catch (_) {}
    }
  }

  /// Skips this version (don't nag again until a newer one is found).
  static Future<void> skipVersion(String version) =>
      SessionPrefs.saveSkippedVersion(version);

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<UpdateInfo?> _fetchLatestRelease() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(_apiUrl));
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'YoLoIT/$currentVersion');

      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = (json['tag_name'] as String? ?? '').trim();
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final htmlUrl = json['html_url'] as String? ?? '';
      final notes = json['body'] as String? ?? '';

      // Find first .dmg asset
      String? dmgUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final a in assets) {
        final asset = a as Map<String, dynamic>;
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.dmg')) {
          dmgUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        version: version,
        tagName: tagName,
        releaseUrl: htmlUrl,
        releaseNotes: notes,
        downloadUrl: dmgUrl,
      );
    } finally {
      client.close();
    }
  }

  /// Returns true when [candidate] is strictly newer than [current].
  /// Compares semver segments numerically (major.minor.patch).
  static bool _isNewer(String candidate, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final c = parse(candidate);
    final b = parse(current);
    final len = c.length > b.length ? c.length : b.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (cv > bv) return true;
      if (cv < bv) return false;
    }
    return false;
  }
}
