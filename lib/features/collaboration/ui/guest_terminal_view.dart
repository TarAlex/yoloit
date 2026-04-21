import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import 'package:yoloit/features/collaboration/services/guest_terminal_registry.dart';
import 'package:yoloit/features/mindmap/widgets/canvas_interaction_lock.dart';

/// Live xterm view for web/remote guest clients.
///
/// Looks up a persistent [Terminal] instance from [GuestTerminalRegistry]
/// keyed by [nodeId]. Raw PTY bytes arriving over the WebSocket are written
/// into that terminal so rendering is identical to the native client —
/// proper ANSI colors, box-drawing, cursor, scrollback, bold/italic text.
///
/// User keystrokes produced by xterm are forwarded via [onInput] which the
/// enclosing card routes to the host over the `terminal.input` sync message.
class GuestTerminalView extends StatefulWidget {
  const GuestTerminalView({
    super.key,
    required this.nodeId,
    this.onInput,
  });

  final String nodeId;
  final void Function(String data)? onInput;

  @override
  State<GuestTerminalView> createState() => _GuestTerminalViewState();
}

class _GuestTerminalViewState extends State<GuestTerminalView> {
  late final Terminal _terminal;
  late final TerminalController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _terminal = GuestTerminalRegistry.instance.terminalFor(widget.nodeId);
    _controller = TerminalController();
    _focus = FocusNode(debugLabel: 'guest-terminal-${widget.nodeId}');

    // Forward keystrokes to the host.
    GuestTerminalRegistry.instance.setInputHandler(widget.nodeId, (data) {
      widget.onInput?.call(data);
    });
  }

  @override
  void dispose() {
    GuestTerminalRegistry.instance.removeInputHandler(widget.nodeId);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Grab focus on click so keyboard input goes to the terminal, not the
    // enclosing canvas. Wrapping in ScrollableCardRegion disables canvas
    // pan while the pointer is over the terminal, letting xterm consume
    // two-finger scroll / wheel events for scrollback.
    return ScrollableCardRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: ColoredBox(
          color: const Color(0xFF0A0A0F),
          child: TerminalView(
            _terminal,
            controller: _controller,
            focusNode: _focus,
            autofocus: false,
            autoResize: true,
            simulateScroll: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            // Bundled monospace font — guarantees identical metrics and full
            // Unicode coverage (cyrillic, CJK, box-drawing) on web and native.
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'JetBrainsMono',
              height: 1.2,
            ),
            theme: _guestTheme,
          ),
        ),
      ),
    );
  }
}

/// Dark theme that approximates the native macOS Terminal experience.
const TerminalTheme _guestTheme = TerminalTheme(
  cursor: Color(0xFFE0E0E0),
  selection: Color(0x554B9EFF),
  foreground: Color(0xFFE6E6E6),
  background: Color(0xFF0A0A0F),
  black: Color(0xFF000000),
  red: Color(0xFFCC6666),
  green: Color(0xFFB5BD68),
  yellow: Color(0xFFF0C674),
  blue: Color(0xFF81A2BE),
  magenta: Color(0xFFB294BB),
  cyan: Color(0xFF8ABEB7),
  white: Color(0xFFC5C8C6),
  brightBlack: Color(0xFF666666),
  brightRed: Color(0xFFD54E53),
  brightGreen: Color(0xFFB9CA4A),
  brightYellow: Color(0xFFE7C547),
  brightBlue: Color(0xFF7AA6DA),
  brightMagenta: Color(0xFFC397D8),
  brightCyan: Color(0xFF70C0B1),
  brightWhite: Color(0xFFEAEAEA),
  searchHitBackground: Color(0xFFAAAAAA),
  searchHitBackgroundCurrent: Color(0xFFFFFF00),
  searchHitForeground: Color(0xFF000000),
);
