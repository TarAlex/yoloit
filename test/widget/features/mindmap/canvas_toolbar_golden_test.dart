// Golden tests for the canvas toolbar button visual appearance.
// _CanvasToolbar and _ToolBtn are private in mindmap_view.dart, so we
// reproduce their exact styling here to capture the golden baseline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _darkBg = Color(0xFF0D1117);

/// Reproduces the visual appearance of _ToolBtn from mindmap_view.dart.
class _ToolBtnHarness extends StatelessWidget {
  const _ToolBtnHarness({required this.icon, required this.tooltip});
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF12151C),
            border: Border.all(color: const Color(0xFF2A3040)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF6B7898)),
        ),
      ),
    );
  }
}

/// Reproduces the visual appearance of the full _CanvasToolbar row.
class _CanvasToolbarHarness extends StatelessWidget {
  const _CanvasToolbarHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        border: Border.all(color: const Color(0xFF1E2330)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _ToolBtnHarness(icon: Icons.remove, tooltip: 'Zoom out'),
          SizedBox(width: 1),
          _ToolBtnHarness(icon: Icons.filter_center_focus, tooltip: 'Fit all nodes'),
          SizedBox(width: 1),
          _ToolBtnHarness(icon: Icons.add, tooltip: 'Zoom in'),
          SizedBox(width: 8),
          _ToolBtnHarness(icon: Icons.refresh, tooltip: 'Reset layout'),
          SizedBox(width: 1),
          _ToolBtnHarness(icon: Icons.visibility, tooltip: 'Show all'),
        ],
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 400,
  double height = 100,
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
        body: Center(child: child),
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
  group('Golden — Canvas Toolbar Buttons', () {
    testWidgets('single zoom-out tool button', (tester) async {
      await _pump(
        tester,
        const _ToolBtnHarness(icon: Icons.remove, tooltip: 'Zoom out'),
        width: 80,
        height: 80,
      );
      await _golden(tester, 'toolbar_btn_zoom_out');
    });

    testWidgets('single fit-all tool button', (tester) async {
      await _pump(
        tester,
        const _ToolBtnHarness(icon: Icons.filter_center_focus, tooltip: 'Fit all nodes'),
        width: 80,
        height: 80,
      );
      await _golden(tester, 'toolbar_btn_fit_all');
    });

    testWidgets('single zoom-in tool button', (tester) async {
      await _pump(
        tester,
        const _ToolBtnHarness(icon: Icons.add, tooltip: 'Zoom in'),
        width: 80,
        height: 80,
      );
      await _golden(tester, 'toolbar_btn_zoom_in');
    });

    testWidgets('single reset-layout tool button', (tester) async {
      await _pump(
        tester,
        const _ToolBtnHarness(icon: Icons.refresh, tooltip: 'Reset layout'),
        width: 80,
        height: 80,
      );
      await _golden(tester, 'toolbar_btn_reset');
    });

    testWidgets('full toolbar row with all buttons', (tester) async {
      await _pump(
        tester,
        const _CanvasToolbarHarness(),
        width: 420,
        height: 80,
      );
      await _golden(tester, 'toolbar_full_row');
    });
  });
}
