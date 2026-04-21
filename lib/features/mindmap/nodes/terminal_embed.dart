
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/widgets/canvas_interaction_lock.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';

/// Mindmap terminal card — reuses the exact `TerminalWidget` from the bottom
/// panel so keyboard/focus/selection/paste/zoom are identical. No dialog,
/// no overlay, no competing Focus nodes — always interactive.
///
/// Wraps the terminal in a [Listener] that absorbs pointer-scroll signals
/// so the parent `InteractiveViewer` (mindmap canvas) doesn't steal them
/// for zoom/pan.
class TerminalEmbed extends StatelessWidget {
  const TerminalEmbed({super.key, required this.session});
  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return ScrollableCardRegion(
      child: Listener(
        // Absorb scroll events so they go to TerminalView's scrollback,
        // not to the InteractiveViewer's zoom/pan handler.
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Handled by TerminalView internally — stop propagation.
          }
        },
        child: TerminalWidget(
          key: ValueKey('mindmap-term-${session.id}'),
          session: session,
          isActive: true,
          // Don't auto-focus — multiple mindmap terminals would fight.
          autoRequestFocus: false,
        ),
      ),
    );
  }
}
