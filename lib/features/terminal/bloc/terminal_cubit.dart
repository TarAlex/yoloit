import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/logging_service.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/data/session_persistence_service.dart';
import 'package:yoloit/features/terminal/data/tmux_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/data/workspace_secrets_service.dart';

class TerminalCubit extends Cubit<TerminalState> {
  TerminalCubit() : super(const TerminalInitial());

  final _ptyService = PtyService.instance;
  final _persistence = SessionPersistenceService.instance;
  final _logging = LoggingService.instance;
  final _tmux = TmuxService.instance;

  /// All sessions across all workspaces (PTYs kept alive when switching workspaces).
  final List<AgentSession> _allSessions = [];
  String? _activeWorkspaceId;

  List<AgentSession> get _workspaceSessions =>
      _allSessions.where((s) => s.workspaceId == _activeWorkspaceId).toList();

  /// Initialises services (no sessions loaded yet — call setActiveWorkspace).
  Future<void> initialize() async {
    await Future.wait([
      _logging.init(),
      _tmux.init(),
    ]);
    emit(const TerminalLoaded(sessions: [], activeIndex: 0));
  }

  /// Switch to a workspace: load its sessions or spawn a default terminal.
  Future<void> setActiveWorkspace({
    required String workspaceId,
    required String workspacePath,
  }) async {
    _activeWorkspaceId = workspaceId;

    // Show workspace sessions that are already running in memory.
    final running = _workspaceSessions;
    if (running.isNotEmpty) {
      emit(TerminalLoaded(sessions: running, activeIndex: 0));
      return;
    }

    emit(const TerminalLoaded(sessions: [], activeIndex: 0));

    // Restore persisted sessions for this workspace.
    final saved = await _persistence.load(workspaceId);
    if (saved.isNotEmpty) {
      for (var i = 0; i < saved.length; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 200));
        final s = saved[i];
        await spawnSession(
          type: s.type,
          workspacePath: s.workspacePath,
          workspaceId: s.workspaceId ?? workspaceId,
          savedSessionId: s.id,
        );
      }
    } else {
      // No saved sessions → spawn a default plain terminal for this workspace.
      await spawnSession(
        type: AgentType.terminal,
        workspacePath: workspacePath,
        workspaceId: workspaceId,
      );
    }
  }

  Future<void> spawnSession({
    required AgentType type,
    required String workspacePath,
    String? workspaceId,
    String? savedSessionId,
  }) async {
    if (state is! TerminalLoaded) return;

    final sessionId =
        savedSessionId ?? '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    final session = AgentSession(
      id: sessionId,
      type: type,
      workspacePath: workspacePath,
      workspaceId: workspaceId,
      status: AgentStatus.live,
      sessionId: _generateSessionId(),
    );

    final secrets = workspaceId != null
        ? await WorkspaceSecretsService.instance.load(workspaceId)
        : <String, String>{};
    final extraEnv = secrets.isEmpty ? null : secrets;

    final Pty pty;
    if (_tmux.isActive) {
      pty = _ptyService.launchTmux(
        sessionId: sessionId,
        workspacePath: workspacePath,
        tmuxLauncher: _tmux.launch,
        extraEnv: extraEnv,
      );
    } else {
      pty = _ptyService.launch(
        sessionId: sessionId,
        workspacePath: workspacePath,
        extraEnv: extraEnv,
      );
    }

    unawaited(_logging.startSession(sessionId, '${type.displayName} @ $workspacePath'));
    _attachPtyToSession(pty, session);

    _allSessions.add(session);
    final visible = _workspaceSessions;
    emit(TerminalLoaded(sessions: visible, activeIndex: visible.length - 1));

    final effectiveWorkspaceId = workspaceId ?? _activeWorkspaceId;
    if (effectiveWorkspaceId != null) {
      unawaited(_persistence.save(
        _allSessions.where((s) => s.workspaceId == effectiveWorkspaceId).toList(),
        effectiveWorkspaceId,
      ));
    }

    // Auto-run agent command (skip for plain terminal and when restoring tmux session).
    final isRestore = savedSessionId != null;
    if (type.launchCommand.isNotEmpty && !(isRestore && _tmux.isActive)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _ptyService.write(sessionId, '${type.launchCommand}\n');
    }
  }

  void switchTab(int index) {
    final current = _loaded;
    if (current == null) return;
    if (index < 0 || index >= current.sessions.length) return;
    emit(current.copyWith(activeIndex: index));
    unawaited(SessionPrefs.saveActiveTerminalIdx(index));
  }

  void closeSession(String sessionId) {
    final current = _loaded;
    if (current == null) return;
    _ptyService.kill(
      sessionId,
      onKillTmux: _tmux.isActive ? _tmux.killSession : null,
    );
    unawaited(_logging.endSession(sessionId));
    _allSessions.removeWhere((s) => s.id == sessionId);
    final visible = _workspaceSessions;
    final newIndex = visible.isEmpty ? 0 : current.activeIndex.clamp(0, visible.length - 1);
    emit(current.copyWith(sessions: visible, activeIndex: newIndex));
    final wsId = _activeWorkspaceId;
    if (wsId != null) unawaited(_persistence.save(visible, wsId));
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
          (data) {
            session.terminal.write(data);
            _logging.write(session.id, data);
          },
          onDone: () => _onSessionDone(session.id),
          // ignore: avoid_types_on_closure_parameters
          onError: (Object e) => _onSessionDone(session.id),
        );
  }

  void _onSessionDone(String sessionId) {
    final current = _loaded;
    if (current == null) return;
    // Update status in _allSessions
    final idx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      _allSessions[idx] = _allSessions[idx].copyWith(status: AgentStatus.idle);
    }
    final visible = _workspaceSessions;
    if (!isClosed) emit(current.copyWith(sessions: visible));
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

// ignore_for_file: discarded_futures
void unawaited(Future<void> future) {}
