import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
  bool runInShell,
});

typedef ProgressCallback = void Function(double? progress, String status);

/// Platform-aware in-app installer for YoLoIT updates.
///
/// macOS: downloads DMG → mounts → ditto-copies to /Applications → relaunches.
/// Linux/Windows: stubs that fall back to opening the browser.
///
/// Usage:
/// ```dart
/// await PlatformInstaller.instance.install(
///   dmgUrl: 'https://…/YoLoIT.dmg',
///   onProgress: (p, s) { … },
/// );
/// ```
abstract class PlatformInstaller {
  const PlatformInstaller();

  /// Singleton — picks the right implementation based on the current OS.
  static PlatformInstaller? _instance;
  static PlatformInstaller get instance {
    _instance ??= _create();
    return _instance!;
  }

  /// Override the singleton (useful for testing).
  // ignore: use_setters_to_change_properties
  static void setInstance(PlatformInstaller instance) => _instance = instance;

  static PlatformInstaller _create() {
    if (Platform.isMacOS) return const MacosPlatformInstaller();
    if (Platform.isLinux) return const LinuxPlatformInstaller();
    if (Platform.isWindows) return const WindowsPlatformInstaller();
    return const LinuxPlatformInstaller();
  }

  /// Returns true if this platform supports in-app install (not just browser).
  bool get supportsInAppInstall;

  /// Reads the app version from the running binary's Info.plist / metadata.
  /// Falls back to [fallback] if it cannot be determined.
  Future<String> getAppVersion({String fallback = '0.0.0'});

  /// Downloads and installs the update from [downloadUrl].
  /// [onProgress] is called with 0.0–1.0 during download, null during install.
  /// Throws on failure.
  Future<void> install({
    required String downloadUrl,
    required ProgressCallback onProgress,
  });
}

// ── macOS ────────────────────────────────────────────────────────────────────

class MacosPlatformInstaller extends PlatformInstaller {
  const MacosPlatformInstaller({ProcessRunner? processRunner})
      : _run = processRunner ?? Process.run;

  final ProcessRunner _run;

  @override
  bool get supportsInAppInstall => true;

  @override
  Future<String> getAppVersion({String fallback = '0.0.0'}) async {
    try {
      final executable = Platform.resolvedExecutable;
      final appBundle = executable.split('/Contents/').first;
      final plistPath = '$appBundle/Contents/Info.plist';
      final result = await _run(
        '/usr/bin/defaults',
        ['read', plistPath, 'CFBundleShortVersionString'],
      );
      if (result.exitCode == 0) {
        final v = (result.stdout as String).trim();
        if (v.isNotEmpty) return v;
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Future<void> install({
    required String downloadUrl,
    required ProgressCallback onProgress,
  }) async {
    // 1. Download DMG
    onProgress(0.0, 'Downloading…');
    final tmpDir = Directory.systemTemp.createTempSync('yoloit_update_');
    final dmgFile = File('${tmpDir.path}/YoLoIT.dmg');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(downloadUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'YoLoIT/updater');
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
    final mount = await _run('hdiutil', [
      'attach', dmgFile.path,
      '-nobrowse',
      '-mountpoint', mountPoint,
    ]);
    if (mount.exitCode != 0) {
      throw Exception('Mount failed: ${mount.stderr}');
    }

    try {
      // 3. Find .app inside mounted volume
      onProgress(null, 'Installing…');
      final volDir = Directory(mountPoint);
      final appEntry = volDir
          .listSync()
          .whereType<Directory>()
          .firstWhere(
            (d) => d.path.endsWith('.app'),
            orElse: () => throw Exception('No .app found in DMG'),
          );

      // 4. Copy to /Applications preserving code signature
      final appName = appEntry.path.split('/').last;
      final dest = '/Applications/$appName';
      final ditto = await _run('ditto', [appEntry.path, dest]);
      if (ditto.exitCode != 0) {
        throw Exception('Copy failed: ${ditto.stderr}');
      }

      // 5. Relaunch from /Applications
      onProgress(null, 'Relaunching…');
      await _run('open', [dest]);
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } finally {
      await _run('hdiutil', ['detach', mountPoint, '-force']);
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

// ── Linux ────────────────────────────────────────────────────────────────────

/// Linux installer stub — always falls back to opening the browser.
class LinuxPlatformInstaller extends PlatformInstaller {
  const LinuxPlatformInstaller();

  @override
  bool get supportsInAppInstall => false;

  @override
  Future<String> getAppVersion({String fallback = '0.0.0'}) async => fallback;

  @override
  Future<void> install({
    required String downloadUrl,
    required ProgressCallback onProgress,
  }) async {
    throw UnsupportedError(
      'In-app install is not supported on Linux. '
      'Open the release page to download and install manually.',
    );
  }
}

// ── Windows ──────────────────────────────────────────────────────────────────

/// Windows installer stub — always falls back to opening the browser.
class WindowsPlatformInstaller extends PlatformInstaller {
  const WindowsPlatformInstaller();

  @override
  bool get supportsInAppInstall => false;

  @override
  Future<String> getAppVersion({String fallback = '0.0.0'}) async {
    // On Windows we could read a version resource from the PE binary,
    // but for now return the fallback until Windows support is added.
    return fallback;
  }

  @override
  Future<void> install({
    required String downloadUrl,
    required ProgressCallback onProgress,
  }) async {
    throw UnsupportedError(
      'In-app install is not supported on Windows yet. '
      'Open the release page to download and install manually.',
    );
  }
}
