import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/workspace_card.dart';

const _darkBg = Color(0xFF0D1117);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double height = 200,
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

void main() {
  group('Golden — WorkspaceCard', () {
    testWidgets('default blue color with multiple repos', (tester) async {
      await _pump(
        tester,
        const WorkspaceCard(
          props: WorkspaceCardProps(
            name: 'yoloit-core',
            color: Color(0xFF60A5FA),
            paths: ['/Users/dev/yoloit', '/Users/dev/client-app'],
          ),
        ),
        height: 160,
      );
      await _golden(tester, 'workspace_card_blue_multi_repo');
    });

    testWidgets('single repo with custom pink color', (tester) async {
      await _pump(
        tester,
        const WorkspaceCard(
          props: WorkspaceCardProps(
            name: 'client-app',
            color: Color(0xFFFF6B85),
            paths: ['/Users/dev/client-app'],
          ),
        ),
        height: 160,
      );
      await _golden(tester, 'workspace_card_pink_single_repo');
    });

    testWidgets('no repos (empty paths)', (tester) async {
      await _pump(
        tester,
        const WorkspaceCard(
          props: WorkspaceCardProps(
            name: 'empty-workspace',
            paths: [],
          ),
        ),
        height: 140,
      );
      await _golden(tester, 'workspace_card_no_repos');
    });

    testWidgets('long workspace name truncates correctly', (tester) async {
      await _pump(
        tester,
        const WorkspaceCard(
          props: WorkspaceCardProps(
            name: 'very-long-workspace-name-that-should-be-truncated',
            color: Color(0xFF34D399),
            paths: ['/some/path'],
          ),
        ),
        height: 160,
      );
      await _golden(tester, 'workspace_card_long_name');
    });
  });
}
