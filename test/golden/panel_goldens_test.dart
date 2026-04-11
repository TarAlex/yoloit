import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/ui/workspace_panel.dart';

Widget _reviewShell({required ReviewState state, double width = 360, double height = 800}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ReviewCubit>(create: (_) => ReviewCubit()..emit(state)),
      BlocProvider<RunCubit>(create: (_) => RunCubit()),
      BlocProvider<FileEditorCubit>(create: (_) => FileEditorCubit()),
    ],
    child: MaterialApp(
      theme: AppThemePreset.neonPurple.theme,
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: const ReviewPanel()),
      ),
    ),
  );
}

Widget _shell({required Widget child, double width = 260, double height = 800}) {
  return MaterialApp(
    theme: AppThemePreset.neonPurple.theme,
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Golden tests — WorkspacePanel', () {
    testGoldens('empty workspace panel', (tester) async {
      await tester.pumpWidgetBuilder(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => WorkspaceCubit()),
            BlocProvider(create: (_) => TerminalCubit()),
            BlocProvider(create: (_) => ReviewCubit()),
            BlocProvider(create: (_) => RunCubit()),
          ],
          child: _shell(child: const WorkspacePanel()),
        ),
        surfaceSize: const Size(260, 800),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'workspace_panel_empty');
    });

    testGoldens('workspace panel with active workspace', (tester) async {
      await tester.pumpWidgetBuilder(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [
                    Workspace(
                      id: 'ws_1',
                      name: 'yoloit-core',
                      paths: ['/project/yoloit-core'],
                      gitBranch: 'main',
                      addedLines: 450,
                      removedLines: 120,
                    ),
                    Workspace(
                      id: 'ws_2',
                      name: 'client-app-v2',
                      paths: ['/project/client-app-v2'],
                      gitBranch: 'develop',
                      addedLines: 150,
                      removedLines: 50,
                    ),
                  ],
                  activeWorkspaceId: 'ws_1',
                )),
            ),
            BlocProvider(create: (_) => TerminalCubit()),
            BlocProvider(create: (_) => ReviewCubit()),
            BlocProvider(create: (_) => RunCubit()),
          ],
          child: _shell(child: const WorkspacePanel()),
        ),
        surfaceSize: const Size(260, 800),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'workspace_panel_with_workspaces');
    });
  });

  group('Golden tests — TerminalPanel', () {
    testGoldens('empty terminal panel', (tester) async {
      await tester.pumpWidgetBuilder(
        MultiBlocProvider(
          providers: [
            BlocProvider<TerminalCubit>(
              create: (_) => TerminalCubit()..emit(const TerminalInitial()),
            ),
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()..emit(const WorkspaceLoaded(workspaces: [])),
            ),
          ],
          child: _shell(child: const TerminalPanel(), width: 780, height: 600),
        ),
        surfaceSize: const Size(780, 600),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'terminal_panel_empty');
    });

    testGoldens('terminal panel with active workspace shows launch buttons', (tester) async {
      await tester.pumpWidgetBuilder(
        MultiBlocProvider(
          providers: [
            BlocProvider<TerminalCubit>(
              create: (_) => TerminalCubit()
                ..emit(const TerminalLoaded(sessions: [], activeIndex: 0)),
            ),
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [Workspace(id: 'ws_1', name: 'project', paths: ['/proj'])],
                  activeWorkspaceId: 'ws_1',
                )),
            ),
          ],
          child: _shell(child: const TerminalPanel(), width: 780, height: 600),
        ),
        surfaceSize: const Size(780, 600),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'terminal_panel_with_workspace');
    });

    testGoldens('terminal panel with session tab custom name', (tester) async {
      final session = AgentSession(
        id: 'sess_1',
        type: AgentType.copilot,
        workspacePath: '/project',
        workspaceId: 'ws_1',
      ).copyWith(customName: 'my-task');

      await tester.pumpWidgetBuilder(
        MultiBlocProvider(
          providers: [
            BlocProvider<TerminalCubit>(
              create: (_) => TerminalCubit()
                ..emit(TerminalLoaded(
                  sessions: [session],
                  activeIndex: 0,
                  allSessions: [session],
                )),
            ),
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [Workspace(id: 'ws_1', name: 'project', paths: ['/project'])],
                  activeWorkspaceId: 'ws_1',
                )),
            ),
          ],
          child: _shell(child: const TerminalPanel(), width: 780, height: 600),
        ),
        surfaceSize: const Size(780, 600),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'terminal_panel_with_session_tab');
    });
  });

  group('Golden tests — ReviewPanel', () {
    testGoldens('empty review panel', (tester) async {
      await tester.pumpWidgetBuilder(
        _reviewShell(state: const ReviewInitial()),
        surfaceSize: const Size(360, 800),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'review_panel_empty');
    });

    testGoldens('review panel with file tree and changed files', (tester) async {
      await tester.pumpWidgetBuilder(
        _reviewShell(
          state: const ReviewLoaded(
            fileTree: [
              FileTreeNode(name: 'lib', path: '/proj/lib', isDirectory: true),
              FileTreeNode(name: 'main.dart', path: '/proj/main.dart', isDirectory: false),
            ],
            changedFiles: [
              FileChange(path: 'lib/app.dart', status: FileChangeStatus.modified),
              FileChange(path: 'lib/new_feature.dart', status: FileChangeStatus.added),
            ],
          ),
        ),
        surfaceSize: const Size(360, 800),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'review_panel_with_files');
    });

    testGoldens('review panel diff view with hunks', (tester) async {
      await tester.pumpWidgetBuilder(
        _reviewShell(
          state: const ReviewLoaded(
            fileTree: [],
            changedFiles: [],
            selectedFilePath: '/proj/lib/main.dart',
            viewMode: ReviewViewMode.diff,
            diffHunks: [
              DiffHunk(
                header: '@@ -1,4 +1,5 @@',
                lines: [
                  DiffLine(type: DiffLineType.header, content: '@@ -1,4 +1,5 @@'),
                  DiffLine(type: DiffLineType.context, content: 'void main() {', oldLineNum: 1, newLineNum: 1),
                  DiffLine(type: DiffLineType.remove, content: '  print("old");', oldLineNum: 2),
                  DiffLine(type: DiffLineType.add, content: '  print("new");', newLineNum: 2),
                  DiffLine(type: DiffLineType.add, content: '  print("extra");', newLineNum: 3),
                  DiffLine(type: DiffLineType.context, content: '}', oldLineNum: 3, newLineNum: 4),
                ],
                oldStart: 1,
                newStart: 1,
              ),
            ],
          ),
        ),
        surfaceSize: const Size(360, 800),
      );
      await tester.pump();
      await screenMatchesGolden(tester, 'review_panel_diff_view');
    });
  });
}
