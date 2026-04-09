import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/ui/workspace_panel.dart';

Widget _buildTestWidget(Widget child) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => WorkspaceCubit()),
      BlocProvider(create: (_) => TerminalCubit()),
      BlocProvider(create: (_) => ReviewCubit()),
    ],
    child: MaterialApp(
      theme: AppThemePreset.neonPurple.theme,
      home: Scaffold(body: SizedBox(width: 260, child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkspacePanel widget tests', () {
    testWidgets('renders logo and title', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      expect(find.text('yoloit'), findsOneWidget);
      expect(find.text('AI ORCHESTRATOR'), findsOneWidget);
    });

    testWidgets('renders Workspaces / Repositories header', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      expect(find.text('Workspaces / Repositories'), findsOneWidget);
    });

    testWidgets('shows empty state prompt when no workspaces', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      expect(find.text('Open a folder...'), findsOneWidget);
    });

    testWidgets('Setup section is hidden (items removed)', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      expect(find.text('Environment Scripts'), findsNothing);
      expect(find.text('API Keys & Secrets'), findsNothing);
      expect(find.text('Docker Configs'), findsNothing);
    });

    testWidgets('renders Color Themes and Settings at bottom', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      expect(find.text('Color Themes'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows workspace tile when workspace is loaded', (tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [
                    Workspace(
                      id: 'ws_1',
                      name: 'my-project',
                      path: '/project',
                      gitBranch: 'main',
                    ),
                  ],
                  activeWorkspaceId: 'ws_1',
                )),
            ),
            BlocProvider(create: (_) => TerminalCubit()),
            BlocProvider(create: (_) => ReviewCubit()),
          ],
          child: MaterialApp(
            theme: AppThemePreset.neonPurple.theme,
            home: const Scaffold(body: SizedBox(width: 260, child: WorkspacePanel())),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('my-project'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows git branch when available', (tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [
                    Workspace(
                      id: 'ws_1',
                      name: 'project',
                      path: '/p',
                      gitBranch: 'feature/my-feature',
                    ),
                  ],
                )),
            ),
            BlocProvider(create: (_) => TerminalCubit()),
            BlocProvider(create: (_) => ReviewCubit()),
          ],
          child: MaterialApp(
            theme: AppThemePreset.neonPurple.theme,
            home: const Scaffold(body: SizedBox(width: 260, child: WorkspacePanel())),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('feature/my-feature'), findsOneWidget);
    });

    testWidgets('shows diff stats when present', (tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(
              create: (_) => WorkspaceCubit()
                ..emit(const WorkspaceLoaded(
                  workspaces: [
                    Workspace(
                      id: 'ws_1',
                      name: 'project',
                      path: '/p',
                      addedLines: 42,
                      removedLines: 17,
                    ),
                  ],
                )),
            ),
            BlocProvider(create: (_) => TerminalCubit()),
            BlocProvider(create: (_) => ReviewCubit()),
          ],
          child: MaterialApp(
            theme: AppThemePreset.neonPurple.theme,
            home: const Scaffold(body: SizedBox(width: 260, child: WorkspacePanel())),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('+42'), findsOneWidget);
      expect(find.text('-17'), findsOneWidget);
    });

    testWidgets('tapping Color Themes shows theme swatches', (tester) async {
      await tester.pumpWidget(_buildTestWidget(const WorkspacePanel()));
      await tester.pump();

      await tester.tap(find.text('Color Themes'));
      await tester.pump();

      expect(find.text('Neon Purple'), findsOneWidget);
      expect(find.text('Cyber Green'), findsOneWidget);
      expect(find.text('Deep Blue'), findsOneWidget);
    });
  });
}
