import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const background = Color(0xFF090918);
  static const surface = Color(0xFF0F0F2A);
  static const surfaceElevated = Color(0xFF161632);
  static const surfaceHighlight = Color(0xFF1C1C42);
  static const border = Color(0xFF1E1E4A);
  static const divider = Color(0xFF1A1A38);

  // Primary / accent — mutable so theme switcher can update them at runtime.
  static Color _primary = const Color(0xFF9D4EDD);
  static Color _primaryLight = const Color(0xFFB87FFF);
  static Color _primaryDark = const Color(0xFF6B2FA0);
  static Color _primaryGlow = const Color(0x339D4EDD);

  static Color get primary => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get primaryDark => _primaryDark;
  static Color get primaryGlow => _primaryGlow;

  static void setAccent(Color color) {
    _primary = color;
    _primaryLight = Color.lerp(color, Colors.white, 0.35)!;
    _primaryDark = Color.lerp(color, Colors.black, 0.35)!;
    _primaryGlow = color.withAlpha(51); // ~0.2 opacity
  }

  // Neon accents
  static const neonGreen = Color(0xFF00FF9F);
  static const neonGreenDim = Color(0xFF00CC7A);
  static const neonGreenGlow = Color(0x2200FF9F);
  static const neonRed = Color(0xFFFF4F6A);
  static const neonRedDim = Color(0xFFCC3D54);
  static const neonBlue = Color(0xFF00B4FF);
  static const neonOrange = Color(0xFFFF9500);

  // Text
  static const textPrimary = Color(0xFFE8E8FF);
  static const textSecondary = Color(0xFF8888BB);
  static const textMuted = Color(0xFF44446A);
  static const textHighlight = Color(0xFFFFFFFF);

  // Terminal
  static const terminalBackground = Color(0xFF070714);
  static const terminalText = Color(0xFFCECEEE);
  static const terminalPrompt = Color(0xFF9D4EDD);

  // Diff
  static const diffAddBg = Color(0xFF0D2A1A);
  static const diffAddText = Color(0xFF00FF9F);
  static const diffRemoveBg = Color(0xFF2A0D12);
  static const diffRemoveText = Color(0xFFFF4F6A);
  static const diffContextBg = Color(0xFF0F0F2A);

  // Status
  static const statusActive = Color(0xFF00DD88);
  static const statusIdle = Color(0xFF888888);
  static const statusError = Color(0xFFFF4F6A);
  static const statusWarning = Color(0xFFFF9500);

  // Tabs
  static const tabActiveBg = Color(0xFF1A1A40);
  static const tabInactiveBg = Color(0xFF0F0F28);
  static const tabBorder = Color(0xFF9D4EDD);

  // Theme presets (for color switcher)
  static const presetNeonPurple = Color(0xFF9D4EDD);
  static const presetCyberGreen = Color(0xFF00FF9F);
  static const presetDeepBlue = Color(0xFF0066FF);
  static const presetSolarOrange = Color(0xFFFF9500);
  static const presetCrimsonRed = Color(0xFFDD2244);
}
