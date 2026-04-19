import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/features/settings/data/agent_config_service.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/logging_service.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/data/session_persistence_service.dart';
import 'package:yoloit/features/terminal/data/tmux_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/data/agent_workspace_dir_service.dart';
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

  /// Remembers the active tab index per workspace so switching back restores it.
  final Map<String, int> _activeIndexPerWorkspace = {};

  List<AgentSession> get _workspaceSessions =>
      _allSessions.where((s) => s.workspaceId == _activeWorkspaceId).toList();

  /// Emits a TerminalLoaded with both visible (workspace) sessions and allSessions.
  void _emitLoaded(List<AgentSession> visible, int activeIndex) {
    emit(TerminalLoaded(
      sessions: visible,
      activeIndex: activeIndex,
      allSessions: List.unmodifiable(_allSessions),
    ));
  }

  /// Initialises services (no sessions loaded yet — call setActiveWorkspace).
  Future<void> initialize() async {
    await Future.wait([
      _logging.init(),
      _tmux.init(),
      AgentConfigService.instance.load(), // pre-load agent configs + default
    ]);
    _emitLoaded([], 0);
  }

  /// Loads persisted session metadata for other (non-active) workspaces so
  /// the mindmap view can render them as idle cards without spawning PTYs.
  /// Existing sessions are preserved; new stubs get status=idle.
  Future<void> loadPersistedMetadataForWorkspaces(List<String> workspaceIds) async {
    var added = false;
    final existingIds = _allSessions.map((s) => s.id).toSet();
    for (final wsId in workspaceIds) {
      if (wsId == _activeWorkspaceId) continue;
      final saved = await _persistence.load(wsId);
      for (final s in saved) {
        if (existingIds.contains(s.id)) continue;
        _allSessions.add(AgentSession(
          id: s.id,
          type: s.type,
          workspacePath: s.workspacePath,
          workspaceId: s.workspaceId ?? wsId,
          status: AgentStatus.idle,
        ));
        existingIds.add(s.id);
        added = true;
      }
    }
    if (added) {
      final cur = _loaded;
      if (cur != null) {
        _emitLoaded(cur.sessions, cur.activeIndex);
      } else {
        _emitLoaded(const [], 0);
      }
    }
  }

  /// Switch to a workspace: load its sessions or spawn a default terminal.
  Future<void> setActiveWorkspace({
    required String workspaceId,
    required String workspacePath,
  }) async {
    // Save current workspace's active index before switching
    final prevWsId = _activeWorkspaceId;
    final prevState = _loaded;
    if (prevWsId != null && prevState != null) {
      _activeIndexPerWorkspace[prevWsId] = prevState.activeIndex;
    }

    _activeWorkspaceId = workspaceId;

    // Show workspace sessions that are already running in memory.
    final running = _workspaceSessions;
    if (running.isNotEmpty) {
      final savedIdx = (_activeIndexPerWorkspace[workspaceId] ?? 0)
          .clamp(0, running.length - 1);
      _emitLoaded(running, savedIdx);
      return;
    }

    _emitLoaded([], 0);

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
          isRestore: true,
        );
      }
    } else {
      // No saved sessions → spawn the user-configured default agent.
      final defaultType = AgentConfigService.instance.defaultAgentType;
      await spawnSession(
        type: defaultType,
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
    bool isRestore = false,
    Map<String, String>? worktreeContexts,
  }) async {
    if (state is! TerminalLoaded) return;

    final sessionId =
        savedSessionId ?? '${type.name}_${DateTime.now().millisecondsSinceEpoch}';

    String effectivePath = workspacePath;
    if (worktreeContexts != null && workspaceId != null) {
      effectivePath = await AgentWorkspaceDirService.instance
          .createAgentDir(workspaceId, sessionId, worktreeContexts);
    }

    final session = AgentSession(
      id: sessionId,
      type: type,
      workspacePath: effectivePath,
      workspaceId: workspaceId,
      status: AgentStatus.live,
      sessionId: _generateSessionId(),
      worktreeContexts: worktreeContexts,
    );

    final secrets = workspaceId != null
        ? await WorkspaceSecretsService.instance.load(workspaceId)
        : <String, String>{};
    final extraEnv = secrets.isEmpty ? null : secrets;

    final Pty pty;
    if (_tmux.isActive) {
      pty = _ptyService.launchTmux(
        sessionId: sessionId,
        label: type.displayName,
        workspacePath: effectivePath,
        tmuxLauncher: _tmux.launch,
        extraEnv: extraEnv,
      );
    } else {
      pty = _ptyService.launch(
        sessionId: sessionId,
        label: type.displayName,
        workspacePath: effectivePath,
        extraEnv: extraEnv,
      );
    }

    unawaited(_logging.startSession(sessionId, '${type.displayName} @ $effectivePath'));
    _attachPtyToSession(pty, session);

    // Remove any idle metadata stub with the same id (from loadPersistedMetadata).
    _allSessions.removeWhere((s) => s.id == sessionId);
    _allSessions.add(session);
    final visible = _workspaceSessions;
    _emitLoaded(visible, visible.length - 1);

    final effectiveWorkspaceId = workspaceId ?? _activeWorkspaceId;
    if (effectiveWorkspaceId != null) {
      unawaited(_persistence.save(
        _allSessions.where((s) => s.workspaceId == effectiveWorkspaceId).toList(),
        effectiveWorkspaceId,
      ));
    }

    // Auto-run agent command (skip for plain terminal and when restoring tmux session).
    final effectiveCommand = AgentConfigService.instance.effectiveLaunchCommand(type);
    if (effectiveCommand.isNotEmpty && !(isRestore && _tmux.isActive)) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _ptyService.write(sessionId, '$effectiveCommand\n');
    }
  }

  void switchTab(int index) {
    final current = _loaded;
    if (current == null) return;
    if (index < 0 || index >= current.sessions.length) return;
    emit(current.copyWith(activeIndex: index, allSessions: List.unmodifiable(_allSessions)));
    if (_activeWorkspaceId != null) {
      _activeIndexPerWorkspace[_activeWorkspaceId!] = index;
    }
    unawaited(SessionPrefs.saveActiveTerminalIdx(index));
  }

  /// Switches the active session to the one with [sessionId].
  /// No-op if the session is not in the current workspace or already active.
  void setActiveSessionById(String sessionId) {
    final current = _loaded;
    if (current == null) return;
    final idx = current.sessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1 || idx == current.activeIndex) return;
    switchTab(idx);
  }

  void renameSession(String sessionId, String name) {
    final idx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    _allSessions[idx] = _allSessions[idx].copyWith(
      customName: name.trim().isEmpty ? null : name.trim(),
      clearCustomName: name.trim().isEmpty,
    );
    final visible = _workspaceSessions;
    final current = _loaded;
    _emitLoaded(visible, current?.activeIndex ?? 0);
    final wsId = _activeWorkspaceId;
    if (wsId != null) unawaited(_persistence.save(visible, wsId));
  }

  /// Updates the worktree path for [repoPath] inside [sessionId].
  /// Returns the updated [AgentSession] so callers can react (e.g. reload file tree).
  AgentSession? updateSessionWorktree(String sessionId, String repoPath, String newWorktreePath) {
    final idx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return null;
    final old = _allSessions[idx];
    final updatedContexts = Map<String, String>.from(old.worktreeContexts ?? {});
    updatedContexts[repoPath] = newWorktreePath;
    _allSessions[idx] = old.copyWith(worktreeContexts: updatedContexts);
    final visible = _workspaceSessions;
    final current = _loaded;
    _emitLoaded(visible, current?.activeIndex ?? 0);
    final wsId = _activeWorkspaceId;
    if (wsId != null) unawaited(_persistence.save(visible, wsId));
    return _allSessions[idx];
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
    _emitLoaded(visible, newIndex);
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
    if (!isClosed) emit(current.copyWith(sessions: visible, allSessions: List.unmodifiable(_allSessions)));
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
