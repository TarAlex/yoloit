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
  });

  final List<AgentSession> sessions;
  final int activeIndex;

  AgentSession? get activeSession =>
      sessions.isEmpty ? null : sessions[activeIndex.clamp(0, sessions.length - 1)];

  TerminalLoaded copyWith({
    List<AgentSession>? sessions,
    int? activeIndex,
  }) {
    return TerminalLoaded(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }

  @override
  List<Object?> get props => [sessions.map((s) => s.id).toList(), activeIndex];
}
