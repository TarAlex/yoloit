import 'dart:io';

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
    this.isRequired = true,
  });

  final String id;
  final String name;
  final String description;
  final String installHint;
  final bool isAvailable;
  final String? version;
  final String? installUrl;
  final bool isRequired;
}

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

/// Checks which system dependencies and AI agents are available.
class SetupCheckService {
  const SetupCheckService._();

  static Future<SetupCheckResult> check() async {
    final results = await Future.wait([
      _checkAll(),
    ]);
    return results.first;
  }

  static Future<SetupCheckResult> _checkAll() async {
    final depFutures = [
      _checkTool(
        id: 'git',
        name: 'git',
        description: 'Version control — required for file tree, diff, branches',
        command: 'git',
        versionArgs: ['--version'],
        installHint: 'brew install git',
        installUrl: 'https://git-scm.com/downloads',
        isRequired: true,
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
      ),
      _checkTool(
        id: 'brew',
        name: 'Homebrew',
        description: 'macOS package manager — needed to install other dependencies',
        command: 'brew',
        versionArgs: ['--version'],
        installHint: '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        installUrl: 'https://brew.sh',
        isRequired: false,
      ),
      _checkTool(
        id: 'node',
        name: 'Node.js',
        description: 'Required by GitHub Copilot CLI',
        command: 'node',
        versionArgs: ['--version'],
        installHint: 'brew install node',
        installUrl: 'https://nodejs.org',
        isRequired: false,
      ),
      _checkTool(
        id: 'bash',
        name: 'bash',
        description: 'Shell used for running commands in terminal sessions',
        command: 'bash',
        versionArgs: ['--version'],
        installHint: 'brew install bash',
        isRequired: true,
      ),
    ];

    final agentFutures = [
      _checkTool(
        id: 'copilot',
        name: 'GitHub Copilot',
        description: 'AI coding agent by GitHub — run with copilot --allow-all',
        command: 'copilot',
        versionArgs: ['--version'],
        installHint: 'npm install -g @github/copilot-cli',
        installUrl: 'https://docs.github.com/en/copilot/github-copilot-in-the-cli',
        isRequired: false,
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
      ),
    ];

    final deps = await Future.wait(depFutures);
    final agents = await Future.wait(agentFutures);

    return SetupCheckResult(deps: deps, agents: agents);
  }

  static Future<DependencyStatus> _checkTool({
    required String id,
    required String name,
    required String description,
    required String command,
    required List<String> versionArgs,
    required String installHint,
    String? installUrl,
    bool isRequired = false,
  }) async {
    try {
      // First check if it's in PATH
      final whichResult = await Process.run('which', [command]);
      if (whichResult.exitCode != 0) {
        return DependencyStatus(
          id: id,
          name: name,
          description: description,
          installHint: installHint,
          installUrl: installUrl,
          isAvailable: false,
          isRequired: isRequired,
        );
      }

      // Get version string
      final versionResult = await Process.run(command, versionArgs)
          .timeout(const Duration(seconds: 5));
      final versionOutput = (versionResult.stdout as String).trim().isNotEmpty
          ? (versionResult.stdout as String).trim().split('\n').first
          : (versionResult.stderr as String).trim().split('\n').first;

      return DependencyStatus(
        id: id,
        name: name,
        description: description,
        installHint: installHint,
        installUrl: installUrl,
        isAvailable: true,
        version: _cleanVersion(versionOutput),
        isRequired: isRequired,
      );
    } catch (_) {
      return DependencyStatus(
        id: id,
        name: name,
        description: description,
        installHint: installHint,
        installUrl: installUrl,
        isAvailable: false,
        isRequired: isRequired,
      );
    }
  }

  static String _cleanVersion(String raw) {
    // Extract just the version number if possible
    final match = RegExp(r'[\d]+\.[\d]+[\.\d]*').firstMatch(raw);
    return match != null ? match.group(0)! : raw.length > 40 ? raw.substring(0, 40) : raw;
  }
}
