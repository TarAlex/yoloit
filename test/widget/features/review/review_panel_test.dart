import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';

Widget _buildReviewTest(ReviewState state) {
  return BlocProvider<ReviewCubit>(
    create: (_) => ReviewCubit()..emit(state),
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
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [
          FileChange(path: 'lib/app.dart', status: FileChangeStatus.modified),
          FileChange(path: 'lib/new.dart', status: FileChangeStatus.added),
        ],
      )));
      await tester.pump();

      expect(find.textContaining('app.dart'), findsOneWidget);
      expect(find.textContaining('new.dart'), findsOneWidget);
    });

    testWidgets('diff view toggle shows Stage Changes button when file is selected', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/project/lib/main.dart',
        diffHunks: [],
      )));
      await tester.pump();

      expect(find.text('Stage Changes'), findsOneWidget);
    });

    testWidgets('view mode toggle Diff/File is visible when file selected', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/project/lib/main.dart',
      )));
      await tester.pump();

      expect(find.text('Diff'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
    });

    testWidgets('tapping File toggle changes view mode', (tester) async {
      ReviewState? emittedState;
      final cubit = ReviewCubit()
        ..emit(const ReviewLoaded(
          fileTree: [],
          changedFiles: [],
          selectedFilePath: '/p/file.dart',
          viewMode: ReviewViewMode.diff,
        ));

      await tester.pumpWidget(
        BlocProvider<ReviewCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppThemePreset.neonPurple.theme,
            home: BlocListener<ReviewCubit, ReviewState>(
              listener: (_, state) => emittedState = state,
              child: const Scaffold(body: ReviewPanel()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('File'));
      await tester.pump();

      expect(emittedState, isA<ReviewLoaded>());
      expect((emittedState as ReviewLoaded).viewMode, ReviewViewMode.file);
    });

    testWidgets('diff hunks are rendered', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/p/file.dart',
        viewMode: ReviewViewMode.diff,
        diffHunks: [
          DiffHunk(
            header: '@@ -1,2 +1,3 @@',
            lines: [
              DiffLine(type: DiffLineType.header, content: '@@ -1,2 +1,3 @@'),
              DiffLine(type: DiffLineType.add, content: 'new line', newLineNum: 1),
              DiffLine(type: DiffLineType.remove, content: 'old line', oldLineNum: 1),
            ],
            oldStart: 1,
            newStart: 1,
          ),
        ],
      )));
      await tester.pump();

      expect(find.text('new line'), findsOneWidget);
      expect(find.text('old line'), findsOneWidget);
    });

    testWidgets('file content is shown in file view mode', (tester) async {
      await tester.pumpWidget(_buildReviewTest(const ReviewLoaded(
        fileTree: [],
        changedFiles: [],
        selectedFilePath: '/p/hello.dart',
        viewMode: ReviewViewMode.file,
        fileContent: 'void main() => print("hello");',
      )));
      await tester.pump();

      expect(find.textContaining('void main()'), findsOneWidget);
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
