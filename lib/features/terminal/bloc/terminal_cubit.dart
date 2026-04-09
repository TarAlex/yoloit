import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/data/workspace_secrets_service.dart';

class TerminalCubit extends Cubit<TerminalState> {
  TerminalCubit() : super(const TerminalInitial());

  final _ptyService = PtyService.instance;

  void initialize() {
    emit(const TerminalLoaded(sessions: [], activeIndex: 0));
  }

  Future<void> spawnSession({
    required AgentType type,
    required String workspacePath,
    String? workspaceId,
  }) async {
    final current = _loaded;
    if (current == null) return;

    final sessionId = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    final session = AgentSession(
      id: sessionId,
      type: type,
      workspacePath: workspacePath,
      status: AgentStatus.live,
      sessionId: _generateSessionId(),
    );

    final secrets = workspaceId != null
        ? await WorkspaceSecretsService.instance.load(workspaceId)
        : <String, String>{};

    final pty = _ptyService.launch(
      sessionId: sessionId,
      workspacePath: workspacePath,
      extraEnv: secrets.isEmpty ? null : secrets,
    );

    _attachPtyToSession(pty, session);

    final sessions = [...current.sessions, session];
    emit(current.copyWith(sessions: sessions, activeIndex: sessions.length - 1));

    // Auto-run the agent command once the shell is ready (skip for plain terminal).
    if (type.launchCommand.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _ptyService.write(sessionId, '${type.launchCommand}\n');
    }
  }

  void switchTab(int index) {
    final current = _loaded;
    if (current == null) return;
    if (index < 0 || index >= current.sessions.length) return;
    emit(current.copyWith(activeIndex: index));
  }

  void closeSession(String sessionId) {
    final current = _loaded;
    if (current == null) return;
    _ptyService.kill(sessionId);
    final sessions = current.sessions.where((s) => s.id != sessionId).toList();
    final newIndex = current.activeIndex.clamp(0, sessions.isEmpty ? 0 : sessions.length - 1);
    emit(current.copyWith(sessions: sessions, activeIndex: newIndex));
  }

  void resizeActiveTerminal(int columns, int rows) {
    final current = _loaded;
    if (current == null) return;
    final active = current.activeSession;
    if (active == null) return;
    _ptyService.resize(active.id, columns, rows);
  }

  void _attachPtyToSession(Pty pty, AgentSession session) {
    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          session.terminal.write,
          onDone: () => _onSessionDone(session.id),
          // ignore: avoid_types_on_closure_parameters
          onError: (Object e) => _onSessionDone(session.id),
        );
  }

  void _onSessionDone(String sessionId) {
    final current = _loaded;
    if (current == null) return;
    final sessions = current.sessions.map((s) {
      if (s.id == sessionId) {
        // Preserve the existing terminal — do NOT create a new one.
        return s.copyWith(status: AgentStatus.idle);
      }
      return s;
    }).toList();
    if (!isClosed) emit(current.copyWith(sessions: sessions));
  }

  String _generateSessionId() {
    final now = DateTime.now();
    return '${_randomHex(8)}-${_randomHex(4)}-${_randomHex(2)}-${now.millisecondsSinceEpoch % 100}';
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final rand = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (i) => chars[(rand >> (i * 4)) & 0xf]).join();
  }

  TerminalLoaded? get _loaded {
    final s = state;
    if (s is TerminalLoaded) return s;
    return null;
  }

  @override
  Future<void> close() {
    _ptyService.killAll();
    return super.close();
  }
}
