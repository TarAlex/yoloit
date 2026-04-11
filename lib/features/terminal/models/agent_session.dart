import 'package:equatable/equatable.dart';
import 'package:xterm/xterm.dart';
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

  AgentSession copyWith({
    AgentStatus? status,
    String? sessionId,
    String? customName,
    bool clearCustomName = false,
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
    );
  }

  String get displayName => customName?.isNotEmpty == true ? customName! : type.displayName;

  @override
  List<Object?> get props => [id, type.name, workspacePath, status, sessionId, customName];
}
