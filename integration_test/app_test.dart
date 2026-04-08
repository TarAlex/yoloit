import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yoloit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launch, panel toggles and settings', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // ── App launch ──────────────────────────────────────────────────────────
    expect(find.text('yoloit — AI Orchestrator'), findsOneWidget);
    expect(find.text('Workspaces / Repositories'), findsOneWidget);
    expect(find.textContaining('Agent Terminal'), findsWidgets);
    expect(find.text('Changes & Review'), findsOneWidget);

    // Title-bar toggle buttons present
    expect(find.byTooltip('Toggle Workspaces (⌘\\)'), findsOneWidget);
    expect(find.byTooltip('Toggle Review Panel (⌘⇧\\)'), findsOneWidget);
    expect(find.byTooltip('Settings (⌘,)'), findsOneWidget);

    // ── Left panel toggle ───────────────────────────────────────────────────
    await tester.tap(find.byTooltip('Toggle Workspaces (⌘\\)'));
    await tester.pumpAndSettle();
    expect(find.text('Workspaces / Repositories'), findsNothing);

    await tester.tap(find.byTooltip('Toggle Workspaces (⌘\\)'));
    await tester.pumpAndSettle();
    expect(find.text('Workspaces / Repositories'), findsOneWidget);

    // ── Right panel toggle ──────────────────────────────────────────────────
    await tester.tap(find.byTooltip('Toggle Review Panel (⌘⇧\\)'));
    await tester.pumpAndSettle();
    expect(find.text('Changes & Review'), findsNothing);

    await tester.tap(find.byTooltip('Toggle Review Panel (⌘⇧\\)'));
    await tester.pumpAndSettle();
    expect(find.text('Changes & Review'), findsOneWidget);

    // ── Settings dialog ─────────────────────────────────────────────────────
    await tester.tap(find.byTooltip('Settings (⌘,)'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets); // dialog title + workspace item
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // Dialog content gone; 'Appearance' and 'Keyboard Shortcuts' only exist in the dialog
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Keyboard Shortcuts'), findsNothing);
  });
}
