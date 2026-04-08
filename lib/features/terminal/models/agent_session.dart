import 'package:equatable/equatable.dart';
import 'package:xterm/xterm.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

enum AgentStatus { idle, live, error }

class AgentSession extends Equatable {
  AgentSession({
    required this.id,
    required this.type,
    required this.workspacePath,
    this.status = AgentStatus.idle,
    this.sessionId,
  }) : terminal = Terminal(maxLines: 10000);

  final String id;
  final AgentType type;
  final String workspacePath;
  final AgentStatus status;
  final String? sessionId;
  final Terminal terminal;

  AgentSession copyWith({
    AgentStatus? status,
    String? sessionId,
  }) {
    return AgentSession(
      id: id,
      type: type,
      workspacePath: workspacePath,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  String get displayName => type.displayName;

  @override
  List<Object?> get props => [id, type.name, workspacePath, status, sessionId];
}
