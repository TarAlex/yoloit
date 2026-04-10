import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Intents
// ---------------------------------------------------------------------------

class PreviousAgentTabIntent extends Intent {
  const PreviousAgentTabIntent();
}

class NextAgentTabIntent extends Intent {
  const NextAgentTabIntent();
}

class CloseTerminalTabIntent extends Intent {
  const CloseTerminalTabIntent();
}

class ToggleWorkspacePanelIntent extends Intent {
  const ToggleWorkspacePanelIntent();
}

class ToggleTerminalPanelIntent extends Intent {
  const ToggleTerminalPanelIntent();
}

class ToggleReviewPanelIntent extends Intent {
  const ToggleReviewPanelIntent();
}

class FocusTerminalIntent extends Intent {
  const FocusTerminalIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenFileSearchIntent extends Intent {
  const OpenFileSearchIntent();
}

// ---------------------------------------------------------------------------
// Default shortcut map (macOS / Desktop)
// ---------------------------------------------------------------------------

const Map<ShortcutActivator, Intent> yoloitShortcuts = {
  // Cmd+[ — previous agent tab
  SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
      PreviousAgentTabIntent(),

  // Cmd+] — next agent tab
  SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
      NextAgentTabIntent(),

  // Cmd+W — close current terminal tab
  SingleActivator(LogicalKeyboardKey.keyW, meta: true):
      CloseTerminalTabIntent(),

  // Cmd+\ — toggle workspace (left) panel
  SingleActivator(LogicalKeyboardKey.backslash, meta: true):
      ToggleWorkspacePanelIntent(),

  // Cmd+T — toggle terminal/agents panel
  SingleActivator(LogicalKeyboardKey.keyT, meta: true):
      ToggleTerminalPanelIntent(),

  // Cmd+Shift+\ — toggle review (right) panel
  SingleActivator(LogicalKeyboardKey.backslash, meta: true, shift: true):
      ToggleReviewPanelIntent(),

  // Cmd+` — focus terminal center panel
  SingleActivator(LogicalKeyboardKey.backquote, meta: true):
      FocusTerminalIntent(),

  // Cmd+, — open settings
  SingleActivator(LogicalKeyboardKey.comma, meta: true): OpenSettingsIntent(),

  // Cmd+P — quick file search
  SingleActivator(LogicalKeyboardKey.keyO, meta: true): OpenFileSearchIntent(),

  // Cmd+F — quick file search (alias)
  SingleActivator(LogicalKeyboardKey.keyF, meta: true): OpenFileSearchIntent(),
};
