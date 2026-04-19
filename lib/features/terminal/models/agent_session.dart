import 'package:equatable/equatable.dart';
import 'package:xterm/xterm.dart';
import 'package:yoloit/features/terminal/data/terminal_output_bus.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

enum AgentStatus { idle, live, error }

class AgentSession extends Equatable {
  AgentSession({
    required this.id,
    required this.type,
    required this.workspacePath,
    this.workspaceId,
    this.status = AgentStatus.idle,
    this.sessionId,
    this.customName,
    this.worktreeContexts,
  }) : terminal = Terminal(maxLines: 10000);

  // Private constructor that preserves an existing terminal instance.
  AgentSession._preserve({
    required this.id,
    required this.type,
    required this.workspacePath,
    required this.terminal,
    this.workspaceId,
    this.status = AgentStatus.idle,
    this.sessionId,
    this.customName,
    this.worktreeContexts,
  });

  final String id;
  final AgentType type;
  final String workspacePath;
  /// ID of the parent workspace — used to re-inject secrets on restore.
  final String? workspaceId;
  final AgentStatus status;
  final String? sessionId;
  final String? customName;
  final Terminal terminal;
  /// Maps repoPath → selectedWorktreePath. Null = default workspace dir.
  final Map<String, String>? worktreeContexts;

  /// Rolling plain-text buffer of recent PTY output (max 300 lines).
  /// NOT included in [props] — mutations don't trigger state rebuilds.
  final List<String> recentLines = [];

  static const _maxRecentLines = 300;

  /// Append raw PTY data: strips ANSI codes, splits into lines, trims buffer.
  void appendOutput(String rawData) {
    final plain = stripAnsi(rawData);
    final incoming = plain.split('\n');
    recentLines.addAll(incoming);
    if (recentLines.length > _maxRecentLines) {
      recentLines.removeRange(0, recentLines.length - _maxRecentLines);
    }
    TerminalOutputBus.instance.write(id, plain);
  }

  /// Last [n] non-empty plain-text lines for display in the browser.
  List<String> lastLines([int n = 80]) {
    final nonEmpty = recentLines.where((l) => l.trim().isNotEmpty).toList();
    return nonEmpty.length <= n ? nonEmpty : nonEmpty.sublist(nonEmpty.length - n);
  }

  AgentSession copyWith({
    AgentStatus? status,
    String? sessionId,
    String? customName,
    bool clearCustomName = false,
    Map<String, String>? worktreeContexts,
  }) {
    return AgentSession._preserve(
      id: id,
      type: type,
      workspacePath: workspacePath,
      workspaceId: workspaceId,
      terminal: terminal,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      customName: clearCustomName ? null : (customName ?? this.customName),
      worktreeContexts: worktreeContexts ?? this.worktreeContexts,
    );
  }

  String get displayName => customName?.isNotEmpty == true ? customName! : type.displayName;

  @override
  List<Object?> get props => [id, type.name, workspacePath, status, sessionId, customName, worktreeContexts];
}
