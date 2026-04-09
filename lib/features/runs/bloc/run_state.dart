import 'package:equatable/equatable.dart';
import 'package:yoloit/features/runs/models/run_config.dart';
import 'package:yoloit/features/runs/models/run_session.dart';

class RunState extends Equatable {
  const RunState({
    this.configs = const [],
    this.sessions = const [],
    this.activeSessionId,
    this.workspacePath,
  });

  final List<RunConfig> configs;
  final List<RunSession> sessions;
  final String? activeSessionId;
  final String? workspacePath;

  RunSession? get activeSession =>
      sessions.where((s) => s.id == activeSessionId).firstOrNull;

  RunState copyWith({
    List<RunConfig>? configs,
    List<RunSession>? sessions,
    String? activeSessionId,
    bool clearActiveSession = false,
    String? workspacePath,
  }) {
    return RunState(
      configs: configs ?? this.configs,
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      workspacePath: workspacePath ?? this.workspacePath,
    );
  }

  @override
  List<Object?> get props =>
      [configs, sessions, activeSessionId, workspacePath];
}
