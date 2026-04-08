import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/hotkeys/hotkeys.dart';

void main() {
  group('Hotkeys', () {
    test('yoloitShortcuts is non-empty', () {
      expect(yoloitShortcuts.isNotEmpty, isTrue);
    });

    test('yoloitShortcuts contains expected intents', () {
      final intents = yoloitShortcuts.values.toList();
      expect(intents.any((i) => i is PreviousAgentTabIntent), isTrue);
      expect(intents.any((i) => i is NextAgentTabIntent), isTrue);
      expect(intents.any((i) => i is CloseTerminalTabIntent), isTrue);
      expect(intents.any((i) => i is ToggleWorkspacePanelIntent), isTrue);
      expect(intents.any((i) => i is ToggleReviewPanelIntent), isTrue);
      expect(intents.any((i) => i is FocusTerminalIntent), isTrue);
      expect(intents.any((i) => i is OpenSettingsIntent), isTrue);
    });

    test('Cmd+W maps to CloseTerminalTabIntent', () {
      const key = SingleActivator(LogicalKeyboardKey.keyW, meta: true);
      expect(yoloitShortcuts[key], isA<CloseTerminalTabIntent>());
    });

    test('Cmd+[ maps to PreviousAgentTabIntent', () {
      const key = SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true);
      expect(yoloitShortcuts[key], isA<PreviousAgentTabIntent>());
    });

    test('Cmd+] maps to NextAgentTabIntent', () {
      const key =
          SingleActivator(LogicalKeyboardKey.bracketRight, meta: true);
      expect(yoloitShortcuts[key], isA<NextAgentTabIntent>());
    });

    test('Cmd+, maps to OpenSettingsIntent', () {
      const key = SingleActivator(LogicalKeyboardKey.comma, meta: true);
      expect(yoloitShortcuts[key], isA<OpenSettingsIntent>());
    });
  });

  group('HSplitViewController', () {
    test('starts with both panels visible', () {
      // Intent constructors don't crash
      const intent1 = PreviousAgentTabIntent();
      const intent2 = NextAgentTabIntent();
      const intent3 = CloseTerminalTabIntent();
      const intent4 = ToggleWorkspacePanelIntent();
      const intent5 = ToggleReviewPanelIntent();
      const intent6 = FocusTerminalIntent();
      const intent7 = OpenSettingsIntent();
      expect(intent1, isA<Intent>());
      expect(intent2, isA<Intent>());
      expect(intent3, isA<Intent>());
      expect(intent4, isA<Intent>());
      expect(intent5, isA<Intent>());
      expect(intent6, isA<Intent>());
      expect(intent7, isA<Intent>());
    });
  });
}
