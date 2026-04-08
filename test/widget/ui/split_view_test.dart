import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/ui/widgets/split_view.dart';

void main() {
  group('HSplitViewController', () {
    test('starts with both panels visible', () {
      final controller = HSplitViewController();
      expect(controller.leftVisible, isTrue);
      expect(controller.rightVisible, isTrue);
      controller.dispose();
    });

    test('toggleLeft flips leftVisible', () {
      final controller = HSplitViewController();
      controller.toggleLeft();
      expect(controller.leftVisible, isFalse);
      controller.toggleLeft();
      expect(controller.leftVisible, isTrue);
      controller.dispose();
    });

    test('toggleRight flips rightVisible', () {
      final controller = HSplitViewController();
      controller.toggleRight();
      expect(controller.rightVisible, isFalse);
      controller.toggleRight();
      expect(controller.rightVisible, isTrue);
      controller.dispose();
    });

    test('notifies listeners on toggle', () {
      final controller = HSplitViewController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.toggleLeft();
      controller.toggleRight();
      expect(notifyCount, 2);
      controller.dispose();
    });
  });

  group('HSplitView widget', () {
    testWidgets('renders all three panels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HSplitView(
              left: Text('LEFT'),
              center: Text('CENTER'),
              right: Text('RIGHT'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LEFT'), findsOneWidget);
      expect(find.text('CENTER'), findsOneWidget);
      expect(find.text('RIGHT'), findsOneWidget);
    });

    testWidgets('hides left panel when controller toggles left', (tester) async {
      final controller = HSplitViewController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HSplitView(
              left: const Text('LEFT'),
              center: const Text('CENTER'),
              right: const Text('RIGHT'),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LEFT'), findsOneWidget);

      controller.toggleLeft();
      await tester.pump();
      // LEFT panel is hidden (width = 0), its widget is not in the tree
      expect(find.text('LEFT'), findsNothing);
      expect(find.text('CENTER'), findsOneWidget);
    });

    testWidgets('restores left panel after double toggle', (tester) async {
      final controller = HSplitViewController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HSplitView(
              left: const Text('LEFT'),
              center: const Text('CENTER'),
              right: const Text('RIGHT'),
              controller: controller,
            ),
          ),
        ),
      );
      controller.toggleLeft();
      await tester.pump();
      controller.toggleLeft();
      await tester.pump();
      expect(find.text('LEFT'), findsOneWidget);
    });

    testWidgets('hides right panel when controller toggles right',
        (tester) async {
      final controller = HSplitViewController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HSplitView(
              left: const Text('LEFT'),
              center: const Text('CENTER'),
              right: const Text('RIGHT'),
              controller: controller,
            ),
          ),
        ),
      );
      controller.toggleRight();
      await tester.pump();
      expect(find.text('RIGHT'), findsNothing);
      expect(find.text('CENTER'), findsOneWidget);
    });
  });
}
