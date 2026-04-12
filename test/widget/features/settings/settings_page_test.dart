import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/settings/ui/settings_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeManager.instance.load();
  });

  group('SettingsPage', () {
    testWidgets('shows Settings title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(body: SettingsPage()),
        ),
      );
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Appearance section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(
            body: SizedBox(width: 700, height: 600, child: SettingsPage()),
          ),
        ),
      );
      await tester.pump();
      // "Appearance" appears in sidebar AND in section header
      expect(find.text('Appearance'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Keyboard Shortcuts section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(
            body: SizedBox(width: 700, height: 600, child: SettingsPage()),
          ),
        ),
      );
      await tester.pump();
      // Navigate to Shortcuts tab (index 3)
      await tester.tap(find.text('Shortcuts'));
      await tester.pump();
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });

    testWidgets('shows all shortcut entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(
            body: SizedBox(width: 700, height: 600, child: SettingsPage()),
          ),
        ),
      );
      await tester.pump();
      // Navigate to Shortcuts tab
      await tester.tap(find.text('Shortcuts'));
      await tester.pump();
      expect(find.textContaining('⌘'), findsWidgets);
      expect(find.textContaining('agent tab'), findsWidgets);
    });

    testWidgets('shows About section with app name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(
            body: SizedBox(width: 700, height: 600, child: SettingsPage()),
          ),
        ),
      );
      await tester.pump();
      // Navigate to About tab (last category)
      await tester.tap(find.text('About'));
      await tester.pump();
      expect(find.textContaining('yoloit'), findsWidgets);
    });

    testWidgets('shows Setup Guide section', (tester) async {
      SharedPreferences.setMockInitialValues({'setup_completed': false});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemePreset.neonPurple.theme,
            home: const Scaffold(
              body: SizedBox(width: 700, height: 600, child: SettingsPage()),
            ),
          ),
        );
        await tester.pump();
        // Navigate to Setup Guide tab
        await tester.tap(find.text('Setup Guide'));
        await tester.pump();
        // Wait for Process.run checks to complete
        await Future<void>.delayed(const Duration(seconds: 3));
        await tester.pump();
      });
      // Either loading or results are shown — both are valid
      final hasLoader = tester.any(find.byType(CircularProgressIndicator));
      final hasContent = tester.any(find.text('Dependencies'));
      expect(hasLoader || hasContent, isTrue);
    });

    testWidgets('close button pops dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => SettingsPage.show(ctx),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsNothing);
    });

    testWidgets('theme swatches visible for all 5 presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemePreset.neonPurple.theme,
          home: const Scaffold(
            body: SizedBox(
              width: 600,
              height: 560,
              child: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      // Theme selector renders 5 colored circles
      final circles = tester.widgetList<Container>(find.byType(Container));
      final coloredCircles = circles
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle &&
              (c.decoration as BoxDecoration).color != null &&
              (c.decoration as BoxDecoration).color != AppColors.background &&
              (c.decoration as BoxDecoration).color != AppColors.surface)
          .toList();
      expect(coloredCircles.length, greaterThanOrEqualTo(5));
    });
  });
}
