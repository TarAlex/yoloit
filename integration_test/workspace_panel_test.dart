import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yoloit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workspace panel shows accessible interactive elements', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Panel header
    expect(find.text('Workspaces / Repositories'), findsOneWidget);

    // Add workspace button always present
    expect(find.byTooltip('Add workspace'), findsOneWidget);

    // Setup section items always visible
    expect(find.text('Environment Scripts'), findsOneWidget);
    expect(find.text('API Keys & Secrets'), findsOneWidget);
    expect(find.text('Docker Configs'), findsOneWidget);
    expect(find.text('Color Themes'), findsOneWidget);
  });
}
