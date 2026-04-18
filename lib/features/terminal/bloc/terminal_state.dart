import 'package:equatable/equatable.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';

abstract class TerminalState extends Equatable {
  const TerminalState();

  @override
  List<Object?> get props => [];
}

class TerminalInitial extends TerminalState {
  const TerminalInitial();
}

class TerminalLoaded extends TerminalState {
  const TerminalLoaded({
    required this.sessions,
    required this.activeIndex,
    this.allSessions = const [],
  });

  /// Sessions visible in current workspace.
  final List<AgentSession> sessions;
  final int activeIndex;
  /// All sessions across all workspaces — used by the sidebar active-sessions panel.
  final List<AgentSession> allSessions;

  AgentSession? get activeSession =>
      sessions.isEmpty ? null : sessions[activeIndex.clamp(0, sessions.length - 1)];

  TerminalLoaded copyWith({
    List<AgentSession>? sessions,
    int? activeIndex,
    List<AgentSession>? allSessions,
  }) {
    return TerminalLoaded(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
      allSessions: allSessions ?? this.allSessions,
    );
  }

  @override
  List<Object?> get props => [sessions, activeIndex, allSessions];
}
