import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ── InstallAction ─────────────────────────────────────────────────────────────

/// Describes how to install a dependency.
class InstallAction {
  const InstallAction({
    required this.executable,
    required this.args,
    this.requiresInteractiveTerminal = false,
    this.interactiveScript,
  });

  final String executable;
  final List<String> args;

  /// If true, this command is interactive (needs sudo/TTY) — opens Terminal.
  final bool requiresInteractiveTerminal;

  /// Shell script to run inside Terminal when [requiresInteractiveTerminal] is true.
  final String? interactiveScript;

  String get displayCommand =>
      interactiveScript ?? '$executable ${args.join(' ')}'.trim();
}

// ── DependencyStatus ──────────────────────────────────────────────────────────

/// Result of a single dependency/agent check.
class DependencyStatus {
  const DependencyStatus({
    required this.id,
    required this.name,
    required this.description,
    required this.installHint,
    required this.isAvailable,
    this.version,
    this.installUrl,
    this.installAction,
    this.isRequired = true,
  });

  final String id;
  final String name;
  final String description;
  final String installHint;
  final bool isAvailable;
  final String? version;
  final String? installUrl;

  /// Structured install action — null means copy-to-clipboard only.
  final InstallAction? installAction;
  final bool isRequired;
}

// ── SetupCheckResult ──────────────────────────────────────────────────────────

/// Result of checking all dependencies and agents.
class SetupCheckResult {
  const SetupCheckResult({
    required this.deps,
    required this.agents,
  });

  final List<DependencyStatus> deps;
  final List<DependencyStatus> agents;

  bool get allRequiredDepsOk =>
      deps.where((d) => d.isRequired).every((d) => d.isAvailable);

  bool get anyAgentAvailable => agents.any((a) => a.isAvailable);
}

// ── SetupCheckService ─────────────────────────────────────────────────────────

/// Checks which system dependencies and AI agents are available.
class SetupCheckService {
  const SetupCheckService._();

  // ── Extended PATH ────────────────────────────────────────────────────────

  /// Builds an extended PATH that includes common macOS tool locations which
  /// are not present in the GUI app's minimal process environment.
  static String _buildExtendedPath() {
    final current = Platform.environment['PATH'] ?? '';
    final home = Platform.environment['HOME'] ?? '';

    final candidates = <String>[
      '/opt/homebrew/bin',
      '/opt/homebrew/sbin',
      '/usr/local/bin',
      '/usr/local/sbin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ];

    if (home.isNotEmpty) {
      candidates.addAll([
        '$home/.nvm/versions/node/current/bin',
        '$home/.volta/bin',
        '$home/.pyenv/shims',
        '$home/.pyenv/bin',
        '$home/.cargo/bin',
        '$home/.local/bin',
        '$home/bin',
      ]);

      // Probe NVM directory for installed versions (highest first)
      final nvmDir = '$home/.nvm/versions/node';
      try {
        final dir = Directory(nvmDir);
        if (dir.existsSync()) {
          final versions = dir
              .listSync()
              .whereType<Directory>()
              .map((d) => d.path)
              .toList()
            ..sort((a, b) => b.compareTo(a));
          for (final v in versions.take(3)) {
            candidates.add('$v/bin');
          }
        }
      } catch (_) {}
    }

    final existing = current.split(':').where((p) => p.isNotEmpty).toSet();
    final merged = <String>[
      ...candidates.where((c) => !existing.contains(c)),
      ...current.split(':').where((p) => p.isNotEmpty),
    ];
    return merged.join(':');
  }

  static String? _extendedPath;
  static String get _path => _extendedPath ??= _buildExtendedPath();

  static Map<String, String> get _env =>
      Map<String, String>.from(Platform.environment)..['PATH'] = _path;

  // ── Check ────────────────────────────────────────────────────────────────

  static Future<SetupCheckResult> check() async {
    _extendedPath = null; // reset so newly installed tools are detected
    return _checkAll();
  }

  static Future<SetupCheckResult> _checkAll() async {
    // Order matters: Homebrew first (other deps may use it to install)
    final depFutures = [
      _checkTool(
        id: 'brew',
        name: 'Homebrew',
        description: 'macOS package manager — needed to install other dependencies',
        command: 'brew',
        versionArgs: ['--version'],
        installHint: '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        installUrl: 'https://brew.sh',
        isRequired: false,
        installAction: const InstallAction(
          executable: '/bin/bash',
          args: [],
          requiresInteractiveTerminal: true,
          interactiveScript: r'/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        ),
      ),
      _checkTool(
        id: 'git',
        name: 'git',
        description: 'Version control — required for file tree, diff, branches',
        command: 'git',
        versionArgs: ['--version'],
        installHint: 'brew install git',
        installUrl: 'https://git-scm.com/downloads',
        isRequired: true,
        installAction: const InstallAction(executable: 'brew', args: ['install', 'git']),
      ),
      _checkTool(
        id: 'node',
        name: 'Node.js',
        description: 'Required for npm-based AI agents (Copilot, Claude, Gemini)',
        command: 'node',
        versionArgs: ['--version'],
        installHint: 'brew install node',
        installUrl: 'https://nodejs.org',
        isRequired: false,
        installAction: const InstallAction(executable: 'brew', args: ['install', 'node']),
      ),
      _checkTool(
        id: 'tmux',
        name: 'tmux',
        description: 'Terminal multiplexer — required for persistent agent sessions',
        command: 'tmux',
        versionArgs: ['-V'],
        installHint: 'brew install tmux',
        installUrl: 'https://github.com/tmux/tmux',
        isRequired: true,
        installAction: const InstallAction(executable: 'brew', args: ['install', 'tmux']),
      ),
      _checkTool(
        id: 'bash',
        name: 'bash',
        description: 'Shell used for running commands in terminal sessions',
        command: 'bash',
        versionArgs: ['--version'],
        installHint: 'brew install bash',
        isRequired: true,
        installAction: const InstallAction(executable: 'brew', args: ['install', 'bash']),
      ),
    ];

    final agentFutures = [
      _checkTool(
        id: 'copilot',
        name: 'GitHub Copilot',
        description: 'AI coding agent by GitHub — run with gh copilot or copilot --allow-all',
        command: 'gh',
        versionArgs: ['copilot', '--version'],
        fallbackCommand: 'copilot',
        fallbackVersionArgs: ['--version'],
        installHint: 'gh extension install github/gh-copilot',
        installUrl: 'https://docs.github.com/en/copilot/github-copilot-in-the-cli',
        isRequired: false,
        installAction: const InstallAction(
          executable: 'gh',
          args: ['extension', 'install', 'github/gh-copilot'],
        ),
      ),
      _checkTool(
        id: 'claude',
        name: 'Claude Code',
        description: 'AI coding agent by Anthropic',
        command: 'claude',
        versionArgs: ['--version'],
        installHint: 'npm install -g @anthropic-ai/claude-code',
        installUrl: 'https://claude.ai/code',
        isRequired: false,
        installAction: const InstallAction(
          executable: 'npm',
          args: ['install', '-g', '@anthropic-ai/claude-code'],
        ),
      ),
      _checkTool(
        id: 'gemini',
        name: 'Gemini CLI',
        description: 'AI coding agent by Google',
        command: 'gemini',
        versionArgs: ['--version'],
        installHint: 'npm install -g @google/gemini-cli',
        installUrl: 'https://gemini.google.com/cli',
        isRequired: false,
        installAction: const InstallAction(
          executable: 'npm',
          args: ['install', '-g', '@google/gemini-cli'],
        ),
      ),
      _checkTool(
        id: 'cursor',
        name: 'Cursor Agent',
        description: 'AI-first code editor with agent mode',
        command: 'cursor',
        versionArgs: ['--version'],
        installHint: 'Download from cursor.com',
        installUrl: 'https://cursor.com',
        isRequired: false,
      ),
      _checkTool(
        id: 'aider',
        name: 'Aider',
        description: 'AI pair programming in your terminal',
        command: 'aider',
        versionArgs: ['--version'],
        installHint: 'pip install aider-chat',
        installUrl: 'https://aider.chat',
        isRequired: false,
        installAction: const InstallAction(
          executable: 'pip',
          args: ['install', 'aider-chat'],
        ),
      ),
    ];

    final deps = await Future.wait(depFutures);
    final agents = await Future.wait(agentFutures);
    return SetupCheckResult(deps: deps, agents: agents);
  }

  // ── Install (streaming) ──────────────────────────────────────────────────

  /// Runs the install action and streams output lines.
  /// Yields lines from stdout and stderr interleaved, then a final status line.
  static Stream<String> install(InstallAction action) {
    final controller = StreamController<String>();

    () async {
      try {
        if (action.requiresInteractiveTerminal) {
          // Open a Terminal window with the install script
          await _openInTerminal(action.displayCommand);
          controller.add('ℹ️  Opened Terminal to run the installer.');
          controller.add('   Please follow the instructions there, then click Re-check.');
          await controller.close();
          return;
        }

        final process = await Process.start(
          action.executable,
          action.args,
          environment: _env,
        );

        final outSub = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(controller.add);

        final errSub = process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(controller.add);

        final exitCode = await process.exitCode;
        await Future.wait([outSub.asFuture<void>(), errSub.asFuture<void>()]);
        await outSub.cancel();
        await errSub.cancel();

        if (exitCode == 0) {
          controller.add('\n✅ Installation complete!');
        } else {
          controller.add('\n❌ Failed (exit code $exitCode)');
        }
      } catch (e) {
        controller.add('❌ Error: $e');
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Opens a new Terminal window running the given shell command.
  static Future<void> _openInTerminal(String command) async {
    final escaped = command.replaceAll('"', r'\"');
    await Process.run('osascript', [
      '-e',
      'tell application "Terminal" to do script "$escaped"',
    ], environment: _env);
    await Process.run('osascript', [
      '-e',
      'tell application "Terminal" to activate',
    ], environment: _env);
  }

  // ── Internal check helper ────────────────────────────────────────────────

  static Future<DependencyStatus> _checkTool({
    required String id,
    required String name,
    required String description,
    required String command,
    required List<String> versionArgs,
    required String installHint,
    String? fallbackCommand,
    List<String>? fallbackVersionArgs,
    String? installUrl,
    InstallAction? installAction,
    bool isRequired = false,
  }) async {
    final env = _env;

    Future<DependencyStatus?> tryCommand(String cmd, List<String> verArgs) async {
      try {
        final whichResult = await Process.run('which', [cmd], environment: env);
        if (whichResult.exitCode != 0) return null;

        final versionResult = await Process.run(cmd, verArgs, environment: env)
            .timeout(const Duration(seconds: 5));
        final versionOutput =
            (versionResult.stdout as String).trim().isNotEmpty
                ? (versionResult.stdout as String).trim().split('\n').first
                : (versionResult.stderr as String).trim().split('\n').first;

        return DependencyStatus(
          id: id,
          name: name,
          description: description,
          installHint: installHint,
          installUrl: installUrl,
          installAction: installAction,
          isAvailable: true,
          version: _cleanVersion(versionOutput),
          isRequired: isRequired,
        );
      } catch (_) {
        return null;
      }
    }

    final primary = await tryCommand(command, versionArgs);
    if (primary != null) return primary;

    if (fallbackCommand != null) {
      final fallback =
          await tryCommand(fallbackCommand, fallbackVersionArgs ?? versionArgs);
      if (fallback != null) return fallback;
    }

    return DependencyStatus(
      id: id,
      name: name,
      description: description,
      installHint: installHint,
      installUrl: installUrl,
      installAction: installAction,
      isAvailable: false,
      isRequired: isRequired,
    );
  }

  static String _cleanVersion(String raw) {
    final match = RegExp(r'[\d]+\.[\d]+[\.\d]*').firstMatch(raw);
    return match != null
        ? match.group(0)!
        : raw.length > 40 ? raw.substring(0, 40) : raw;
  }
}
