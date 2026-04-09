import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yoloit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Integration tests verify accessible TEXT content and interactive elements.
  // Semantics tree assertions are in test/widget/ widget tests.
  testWidgets('interactive elements are reachable via tooltips and text', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Title bar — all three action buttons present
    expect(find.byTooltip('Toggle Workspaces (⌘\\)'), findsOneWidget);
    expect(find.byTooltip('Toggle Review Panel (⌘⇧\\)'), findsOneWidget);
    expect(find.byTooltip('Settings (⌘,)'), findsOneWidget);

    // Workspace panel interactive text elements
    expect(find.byTooltip('Add workspace'), findsOneWidget);

    // Color Themes and Settings always visible
    expect(find.text('Color Themes'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
  });
}
