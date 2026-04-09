import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/hotkeys/hotkey_definition.dart';

void main() {
  group('HotkeyDefinition.formatActivator', () {
    test('formats Cmd+F', () {
      const a = SingleActivator(LogicalKeyboardKey.keyF, meta: true);
      expect(HotkeyDefinition.formatActivator(a), '⌘F');
    });

    test('formats Cmd+Shift+backslash', () {
      const a = SingleActivator(LogicalKeyboardKey.backslash, meta: true, shift: true);
      // Apple HIG modifier order: ⌃⌥⇧⌘ — so shift (⇧) precedes command (⌘)
      expect(HotkeyDefinition.formatActivator(a), '⇧⌘\\');
    });

    test('formats Ctrl+Alt+S', () {
      const a = SingleActivator(LogicalKeyboardKey.keyS, control: true, alt: true);
      expect(HotkeyDefinition.formatActivator(a), '⌃⌥S');
    });

    test('formats Cmd+[ bracket', () {
      const a = SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true);
      expect(HotkeyDefinition.formatActivator(a), '⌘[');
    });

    test('formats Cmd+backtick', () {
      const a = SingleActivator(LogicalKeyboardKey.backquote, meta: true);
      expect(HotkeyDefinition.formatActivator(a), '⌘`');
    });
  });

  group('HotkeyDefinition.isOverridden', () {
    test('not overridden when current == default', () {
      final def = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      expect(def.isOverridden, isFalse);
    });

    test('overridden when current != default', () {
      final def = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      def.currentActivator = const SingleActivator(LogicalKeyboardKey.keyG, meta: true);
      expect(def.isOverridden, isTrue);
    });

    test('overridden when modifier differs', () {
      final def = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      def.currentActivator = const SingleActivator(
        LogicalKeyboardKey.keyF,
        meta: true,
        shift: true,
      );
      expect(def.isOverridden, isTrue);
    });
  });

  group('HotkeyDefinition serialization', () {
    test('toJson / fromJson round-trip', () {
      final def = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      def.currentActivator = const SingleActivator(
        LogicalKeyboardKey.keyG,
        meta: true,
        shift: true,
      );

      final json = def.toJson();
      expect(json['keyId'], LogicalKeyboardKey.keyG.keyId);
      expect(json['meta'], true);
      expect(json['shift'], true);
      expect(json['alt'], false);
      expect(json['control'], false);

      // Restore in a fresh definition
      final def2 = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      def2.fromJson(json);
      expect(def2.currentActivator.trigger.keyId, LogicalKeyboardKey.keyG.keyId);
      expect(def2.currentActivator.meta, true);
      expect(def2.currentActivator.shift, true);
    });

    test('fromJson with unknown keyId is a no-op', () {
      final def = HotkeyDefinition(
        id: 'test',
        description: 'Test',
        category: 'Test',
        defaultActivator: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        intent: const _TestIntent(),
      );
      def.fromJson({'keyId': null});
      // Should remain unchanged
      expect(def.currentActivator.trigger.keyId, LogicalKeyboardKey.keyF.keyId);
    });
  });

  group('kHotkeyDefinitions', () {
    test('contains at least 8 entries', () {
      expect(kHotkeyDefinitions.length, greaterThanOrEqualTo(8));
    });

    test('all ids are unique', () {
      final ids = kHotkeyDefinitions.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all entries have non-empty description and category', () {
      for (final d in kHotkeyDefinitions) {
        expect(d.description, isNotEmpty, reason: 'id=${d.id}');
        expect(d.category, isNotEmpty, reason: 'id=${d.id}');
      }
    });
  });
}

class _TestIntent extends Intent {
  const _TestIntent();
}
