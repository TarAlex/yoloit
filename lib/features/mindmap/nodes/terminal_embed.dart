
import 'package:flutter/material.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';

/// Mindmap terminal card — reuses the exact `TerminalWidget` from the bottom
/// panel so keyboard/focus/selection/paste/zoom are identical. No dialog,
/// no overlay, no competing Focus nodes — always interactive.
class TerminalEmbed extends StatelessWidget {
  const TerminalEmbed({super.key, required this.session});
  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return TerminalWidget(
      key: ValueKey('mindmap-term-${session.id}'),
      session: session,
      isActive: true,
    );
  }
}
