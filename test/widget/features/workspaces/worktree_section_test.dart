import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/workspaces/ui/worktree_section.dart';

Widget _buildWorktreeTest(List<String> paths) {
  return MaterialApp(
    theme: AppThemePreset.neonPurple.theme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: WorktreeSection(
          workspacePaths: paths,
          workspaceName: 'test-ws',
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorktreeSection widget tests', () {
    testWidgets('shows Worktrees section header and loading state', (tester) async {
      await tester.pumpWidget(_buildWorktreeTest(['/foo/repo-a']));
      // Initial build: header should always be present
      expect(find.text('Worktrees'), findsOneWidget);
      // Drain all pending timers so test can complete cleanly
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('multiple paths show folder sub-headers after load', (tester) async {
      await tester.pumpWidget(
        _buildWorktreeTest(['/foo/repo-a', '/bar/repo-b']),
      );
      // Wait for async git calls to complete (will error since no real git repo)
      await tester.pump(const Duration(seconds: 3));

      // Sub-headers should be rendered (repo-a, repo-b)
      expect(find.text('repo-a'), findsOneWidget);
      expect(find.text('repo-b'), findsOneWidget);
    });

    testWidgets('multiple paths show Worktrees header once', (tester) async {
      await tester.pumpWidget(
        _buildWorktreeTest(['/foo/repo-a', '/bar/repo-b']),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Worktrees'), findsOneWidget);
    });

    testWidgets('handles errors gracefully when git fails', (tester) async {
      await tester.pumpWidget(
        _buildWorktreeTest(['/nonexistent/path-a', '/nonexistent/path-b']),
      );
      await tester.pump(const Duration(seconds: 3));

      // Section header still shown even with errors — no crash
      expect(find.text('Worktrees'), findsOneWidget);
    });

    testWidgets('single path shows Add worktree button after load', (tester) async {
      await tester.pumpWidget(_buildWorktreeTest(['/foo/repo-a']));
      await tester.pump(const Duration(seconds: 3));

      // Even with git error, the "Add worktree" button appears in single-repo mode
      expect(find.text('Add worktree'), findsOneWidget);
    });
  });
}

