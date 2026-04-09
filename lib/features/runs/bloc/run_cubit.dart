import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/runs/bloc/run_state.dart';
import 'package:yoloit/features/runs/data/run_config_storage.dart';
import 'package:yoloit/features/runs/data/run_service.dart';
import 'package:yoloit/features/runs/models/run_config.dart';
import 'package:yoloit/features/runs/models/run_session.dart';

class RunCubit extends Cubit<RunState> {
  RunCubit() : super(const RunState());

  static const _maxOutputLines = 5000;

  Future<void> loadForWorkspace(String workspacePath) async {
    final configs = await RunConfigStorage.instance.load(workspacePath);
    if (configs.isEmpty && await _isFlutterProject(workspacePath)) {
      final presets = [
        RunConfig.flutterRunMacos(workspacePath),
        RunConfig.flutterTest(),
        RunConfig.flutterBuildMacos(),
      ];
      await RunConfigStorage.instance.save(workspacePath, presets);
      emit(state.copyWith(configs: presets, workspacePath: workspacePath));
    } else {
      emit(state.copyWith(configs: configs, workspacePath: workspacePath));
    }
  }

  Future<bool> _isFlutterProject(String path) async {
    final pubspec = File('$path/pubspec.yaml');
    if (!await pubspec.exists()) return false;
    final content = await pubspec.readAsString();
    return content.contains('flutter:');
  }

  Future<void> startRun(RunConfig config) async {
    final workspacePath = state.workspacePath;
    if (workspacePath == null) return;

    final sessionId = '${config.id}_${DateTime.now().millisecondsSinceEpoch}';
    final session = RunSession(
      id: sessionId,
      config: config,
      workspacePath: workspacePath,
      status: RunStatus.running,
      startedAt: DateTime.now(),
    );

    emit(state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: sessionId,
    ));

    final effectiveDir = config.workingDir ?? workspacePath;

    await RunService.instance.start(
      sessionId: sessionId,
      command: config.command,
      workingDir: effectiveDir,
      env: config.env,
      onOutput: (line, isError) => _appendOutput(sessionId, line, isError),
      onExit: (code) => _onExit(sessionId, code),
    );
  }

  void stopRun(String sessionId) {
    RunService.instance.stop(sessionId);
    _updateSession(
        sessionId, (s) => s.copyWith(status: RunStatus.stopped));
  }

  void sendHotReload(String sessionId) {
    RunService.instance.sendStdin(sessionId, 'r');
  }

  void sendHotRestart(String sessionId) {
    RunService.instance.sendStdin(sessionId, 'R');
  }

  void clearOutput(String sessionId) {
    _updateSession(sessionId, (s) => s.copyWith(output: []));
  }

  void setActiveSession(String sessionId) {
    emit(state.copyWith(activeSessionId: sessionId));
  }

  void removeSession(String sessionId) {
    RunService.instance.stop(sessionId);
    final sessions =
        state.sessions.where((s) => s.id != sessionId).toList();
    final activeId = state.activeSessionId == sessionId
        ? sessions.lastOrNull?.id
        : state.activeSessionId;
    emit(state.copyWith(
      sessions: sessions,
      activeSessionId: activeId,
      clearActiveSession: activeId == null,
    ));
  }

  Future<void> addConfig(RunConfig config) async {
    final configs = [...state.configs, config];
    await RunConfigStorage.instance.save(state.workspacePath ?? '', configs);
    emit(state.copyWith(configs: configs));
  }

  Future<void> updateConfig(RunConfig config) async {
    final configs =
        state.configs.map((c) => c.id == config.id ? config : c).toList();
    await RunConfigStorage.instance.save(state.workspacePath ?? '', configs);
    emit(state.copyWith(configs: configs));
  }

  Future<void> removeConfig(String id) async {
    final configs = state.configs.where((c) => c.id != id).toList();
    await RunConfigStorage.instance.save(state.workspacePath ?? '', configs);
    emit(state.copyWith(configs: configs));
  }

  void _appendOutput(String sessionId, String line, bool isError) {
    _updateSession(sessionId, (s) {
      final lines = [
        ...s.output,
        RunOutputLine(
            text: line, isError: isError, timestamp: DateTime.now()),
      ];
      return s.copyWith(
        output: lines.length > _maxOutputLines
            ? lines.sublist(lines.length - _maxOutputLines)
            : lines,
      );
    });
  }

  void _onExit(String sessionId, int code) {
    _appendOutput(
        sessionId, '\n[Process exited with code $code]', code != 0);
    _updateSession(
      sessionId,
      (s) => s.copyWith(
        status: code == 0 ? RunStatus.stopped : RunStatus.failed,
        exitCode: code,
      ),
    );
  }

  void _updateSession(
      String sessionId, RunSession Function(RunSession) updater) {
    final sessions = state.sessions
        .map((s) => s.id == sessionId ? updater(s) : s)
        .toList();
    emit(state.copyWith(sessions: sessions));
  }
}
