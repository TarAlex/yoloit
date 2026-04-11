import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

Widget _buildTerminalTest({
  required TerminalState terminalState,
  WorkspaceState? workspaceState,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<TerminalCubit>(
        create: (_) => TerminalCubit()..emit(terminalState),
      ),
      BlocProvider<WorkspaceCubit>(
        create: (_) {
          final cubit = WorkspaceCubit();
          if (workspaceState != null) cubit.emit(workspaceState);
          return cubit;
        },
      ),
    ],
    child: MaterialApp(
      theme: AppThemePreset.neonPurple.theme,
      home: const Scaffold(body: TerminalPanel()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TerminalPanel widget tests', () {
    testWidgets('empty state shows AI Agents header', (tester) async {
      await tester.pumpWidget(_buildTerminalTest(
        terminalState: const TerminalInitial(),
      ));
      await tester.pump();

      expect(find.text('AI Agents'), findsAtLeastNWidgets(1));
    });

    testWidgets('empty state shows instruction text', (tester) async {
      await tester.pumpWidget(_buildTerminalTest(
        terminalState: const TerminalInitial(),
      ));
      await tester.pump();

      expect(find.text('Open a workspace and start an AI agent to begin'), findsOneWidget);
    });

    testWidgets('shows launch buttons when workspace is active', (tester) async {
      await tester.pumpWidget(_buildTerminalTest(
        terminalState: const TerminalInitial(),
        workspaceState: const WorkspaceLoaded(
          workspaces: [Workspace(id: 'ws_1', name: 'proj', paths: ['/proj'])],
          activeWorkspaceId: 'ws_1',
        ),
      ));
      await tester.pump();

      expect(find.text('Copilot'), findsWidgets);
      expect(find.text('Claude'), findsWidgets);
    });

    testWidgets('shows select workspace hint when no active workspace', (tester) async {
      await tester.pumpWidget(_buildTerminalTest(
        terminalState: const TerminalLoaded(sessions: [], activeIndex: 0),
        workspaceState: const WorkspaceLoaded(workspaces: []),
      ));
      await tester.pump();

      expect(find.text('Select a workspace from the left panel first'), findsOneWidget);
    });
  });
}
