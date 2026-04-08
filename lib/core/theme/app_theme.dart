import 'package:flutter/material.dart';
import 'package:yoloit/core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData buildTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      splashColor: accentColor.withAlpha(30),
      highlightColor: accentColor.withAlpha(20),
      fontFamily: 'SF Pro Display',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }

  static ThemeData get neonPurple => buildTheme(AppColors.presetNeonPurple);
  static ThemeData get cyberGreen => buildTheme(AppColors.presetCyberGreen);
  static ThemeData get deepBlue => buildTheme(AppColors.presetDeepBlue);
  static ThemeData get solarOrange => buildTheme(AppColors.presetSolarOrange);
  static ThemeData get crimsonRed => buildTheme(AppColors.presetCrimsonRed);
}

enum AppThemePreset {
  neonPurple('Neon Purple', AppColors.presetNeonPurple),
  cyberGreen('Cyber Green', AppColors.presetCyberGreen),
  deepBlue('Deep Blue', AppColors.presetDeepBlue),
  solarOrange('Solar Orange', AppColors.presetSolarOrange),
  crimsonRed('Crimson Red', AppColors.presetCrimsonRed);

  const AppThemePreset(this.label, this.color);
  final String label;
  final Color color;

  ThemeData get theme => AppTheme.buildTheme(color);
}
