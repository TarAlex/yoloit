import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yoloit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal panel shows agent launch buttons', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('Agent Terminal'), findsAtLeastNWidgets(1));
    // Without an active workspace, the prompt to select one is shown
    expect(find.text('Select a workspace from the left panel first'), findsOneWidget);
  });
}
