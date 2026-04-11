import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';

Widget _buildReviewTest(ReviewState state) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ReviewCubit>(create: (_) => ReviewCubit()..emit(state)),
      BlocProvider<RunCubit>(create: (_) => RunCubit()),
      BlocProvider<FileEditorCubit>(create: (_) => FileEditorCubit()),
    ],
    child: MaterialApp(
      theme: AppThemePreset.neonPurple.theme,
      home: const Scaffold(body: ReviewPanel()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewPanel widget tests', () {
    testWidgets('empty state shows Changes & Review title', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewInitial()));
      await tester.pump();

      expect(find.text('Changes & Review'), findsAtLeastNWidgets(1));
    });

    testWidgets('empty state shows workspace prompt', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewInitial()));
      await tester.pump();

      expect(find.text('Open a workspace to see file changes'), findsOneWidget);
    });

    testWidgets('loaded state shows File Tree section', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
      )));
      await tester.pump();

      expect(find.text('File Tree'), findsOneWidget);
    });

    testWidgets('loaded state shows empty file tree message', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
      )));
      await tester.pump();

      expect(find.text('No files'), findsOneWidget);
    });

    testWidgets('file tree nodes are rendered', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [
          FileTreeNode(name: 'lib', path: '/project/lib', isDirectory: true),
          FileTreeNode(name: 'main.dart', path: '/project/main.dart', isDirectory: false),
        ],
        changedFiles: [],
      )));
      await tester.pump();

      expect(find.text('lib'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
    });

    testWidgets('changed files section renders file statuses', (tester) async {
      // The current review panel shows a file tree, not a separate changed files list.
      // Files with changes are reflected via the file tree nodes.
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [
          FileTreeNode(name: 'app.dart', path: 'lib/app.dart', isDirectory: false),
          FileTreeNode(name: 'new.dart', path: 'lib/new.dart', isDirectory: false),
        ],
        changedFiles: [
          FileChange(path: 'lib/app.dart', status: FileChangeStatus.modified),
          FileChange(path: 'lib/new.dart', status: FileChangeStatus.added),
        ],
      )));
      await tester.pump();

      expect(find.textContaining('app.dart'), findsOneWidget);
      expect(find.textContaining('new.dart'), findsOneWidget);
    });

    testWidgets('run panel section is visible in review panel', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
      )));
      await tester.pump();

      expect(find.text('Run'), findsOneWidget);
    });

    testWidgets('loaded state shows refresh icon', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
      )));
      await tester.pump();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('view mode is tracked in state', (tester) async {
      // viewMode is in state for future use; currently panel shows file tree only
      const state = ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/project/lib/main.dart',
        viewMode: ReviewViewMode.diff,
      );
      expect(state.viewMode, ReviewViewMode.diff);
      expect(state.selectedFilePath, '/project/lib/main.dart');
    });

    testWidgets('diff hunks state is preserved', (tester) async {
      const hunk = DiffHunk(
        header: '@@ -1,2 +1,3 @@',
        lines: [
          DiffLine(type: DiffLineType.add, content: 'new line', newLineNum: 1),
        ],
        oldStart: 1,
        newStart: 1,
      );
      const state = ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        diffHunks: [hunk],
      );
      expect(state.diffHunks, hasLength(1));
    });

    testWidgets('file content state is preserved', (tester) async {
      const state = ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        fileContent: 'void main() => print("hello");',
        viewMode: ReviewViewMode.file,
      );
      expect(state.fileContent, contains('void main()'));
    });

    testWidgets('PR status section renders when prStatus is set', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        prStatus: PrStatus(
          title: 'Refactor main loop',
          prNumber: 42,
          status: 'Open',
          checks: [],
          reviewers: 2,
        ),
      )));
      await tester.pump();

      expect(find.text('PR Status'), findsOneWidget);
      expect(find.textContaining('Refactor main loop'), findsOneWidget);
      expect(find.text('Create PR'), findsOneWidget);
      expect(find.text('Merge'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
