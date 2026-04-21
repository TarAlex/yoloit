import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/file_tree_card.dart';

const _darkBg = Color(0xFF0D1117);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 300,
  double height = 320,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: _darkBg),
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('goldens/$name.png'),
  );
}

const _sampleEntries = [
  TreeEntry(
    name: 'lib',
    path: '/project/lib',
    isDir: true,
    depth: 0,
    isExpanded: true,
  ),
  TreeEntry(
    name: 'main.dart',
    path: '/project/lib/main.dart',
    isDir: false,
    depth: 1,
  ),
  TreeEntry(
    name: 'features',
    path: '/project/lib/features',
    isDir: true,
    depth: 1,
    isExpanded: false,
  ),
  TreeEntry(
    name: 'pubspec.yaml',
    path: '/project/pubspec.yaml',
    isDir: false,
    depth: 0,
  ),
  TreeEntry(
    name: 'README.md',
    path: '/project/README.md',
    isDir: false,
    depth: 0,
  ),
];

void main() {
  group('Golden — FileTreeCard', () {
    testWidgets('populated tree with repo name', (tester) async {
      await _pump(
        tester,
        const FileTreeCard(
          props: FileTreeCardProps(
            repoName: 'yoloit',
            repoPath: '/Users/dev/yoloit',
            entries: _sampleEntries,
          ),
        ),
      );
      await _golden(tester, 'file_tree_card_populated');
    });

    testWidgets('empty state shows placeholder text', (tester) async {
      await _pump(
        tester,
        const FileTreeCard(
          props: FileTreeCardProps(
            repoName: 'my-repo',
            repoPath: '/Users/dev/my-repo',
            entries: [],
          ),
        ),
        height: 180,
      );
      await _golden(tester, 'file_tree_card_empty');
    });

    testWidgets('no repo name shows generic title', (tester) async {
      await _pump(
        tester,
        const FileTreeCard(
          props: FileTreeCardProps(
            entries: _sampleEntries,
          ),
        ),
      );
      await _golden(tester, 'file_tree_card_no_repo_name');
    });

    testWidgets('deep nested entries', (tester) async {
      const deepEntries = [
        TreeEntry(name: 'src', path: '/p/src', isDir: true, depth: 0, isExpanded: true),
        TreeEntry(name: 'core', path: '/p/src/core', isDir: true, depth: 1, isExpanded: true),
        TreeEntry(name: 'utils', path: '/p/src/core/utils', isDir: true, depth: 2, isExpanded: true),
        TreeEntry(name: 'helper.dart', path: '/p/src/core/utils/helper.dart', isDir: false, depth: 3),
        TreeEntry(name: 'constants.dart', path: '/p/src/core/constants.dart', isDir: false, depth: 2),
        TreeEntry(name: 'app.dart', path: '/p/src/app.dart', isDir: false, depth: 1),
      ];
      await _pump(
        tester,
        const FileTreeCard(
          props: FileTreeCardProps(
            repoName: 'deep-project',
            repoPath: '/p',
            entries: deepEntries,
          ),
        ),
        height: 260,
      );
      await _golden(tester, 'file_tree_card_deep_nested');
    });
  });
}
