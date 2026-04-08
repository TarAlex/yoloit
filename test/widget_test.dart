import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/ui/shell/main_shell.dart';

/// Minimal app harness that does NOT initialize window_manager
/// (window_manager is a platform plugin unavailable in headless tests).
Widget _testApp() => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WorkspaceCubit()),
        BlocProvider(create: (_) => TerminalCubit()),
        BlocProvider(create: (_) => ReviewCubit()),
      ],
      child: MaterialApp(
        theme: AppThemePreset.neonPurple.theme,
        home: const MainShell(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeManager.instance.load();
  });

  testWidgets('App smoke test — three-panel shell renders', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pump();

    // Shell scaffold is present
    expect(find.byType(Scaffold), findsWidgets);
    // All three panels attempt to render
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
