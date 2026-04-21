import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/agent_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHarness(void Function(String data) onInput) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 280,
            child: AgentCard(
              props: const AgentCardProps(
                name: 'Copilot',
                status: 'live',
                isRunning: true,
                typeName: 'Copilot',
                lastLines: ['hello'],
                repos: [RepoBranchInfo(repo: 'yoloit', branch: 'main')],
              ),
              onTerminalInput: onInput,
            ),
          ),
        ),
      ),
    );
  }

  group('AgentCard terminal input', () {
    testWidgets('sends typed characters after focus', (tester) async {
      final sent = <String>[];

      await tester.pumpWidget(buildHarness(sent.add));
      await tester.tap(find.byType(AgentCard));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      expect(sent, ['a']);
    });

    testWidgets('maps terminal control keys to PTY sequences', (tester) async {
      final sent = <String>[];

      await tester.pumpWidget(buildHarness(sent.add));
      await tester.tap(find.byType(AgentCard));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(sent, ['\x1b\r', '\x1b[A', '\x03']);
    });
  });
}
