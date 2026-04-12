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

  /// Current app version — must match the release tag (without leading "v").
  static const currentVersion = '0.0.1';

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
      final info = await _fetchLatestRelease();
      await SessionPrefs.saveLastUpdateCheckMs(
          DateTime.now().millisecondsSinceEpoch);
      if (info == null) return null;

      final skipped = await SessionPrefs.getSkippedVersion();
      if (skipped == info.version) return null; // user dismissed this version

      return _isNewer(info.version, currentVersion) ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Opens the release URL or download URL in the system browser.
  static Future<void> openRelease(UpdateInfo info) async {
    final url = info.downloadUrl ?? info.releaseUrl;
    await Process.run('open', [url]);
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
