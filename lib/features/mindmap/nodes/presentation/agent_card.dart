import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/terminal/models/agent_phase.dart';

/// Presentation agent/terminal card — shared shell used by both macOS and web.
/// Web falls back to styled text lines; macOS can inject a live terminal body.
class AgentCard extends StatefulWidget {
  const AgentCard({
    super.key,
    required this.props,
    this.body,
    this.onTerminalInput,
    this.onSessionStart,
  });
  final AgentCardProps props;
  final Widget? body;
  final void Function(String data)? onTerminalInput;
  final VoidCallback? onSessionStart;

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    if (widget.props.isRunning) _animCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AgentCard old) {
    super.didUpdateWidget(old);
    _updateAnimation();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor => switch (widget.props.status) {
    'live' => const Color(0xFF34D399),
    'error' => const Color(0xFFF87171),
    _ => const Color(0xFF60A5FA),
  };

  Color get _phaseColor {
    final phase = widget.props.hookPhase;
    return switch (phase) {
      null => _statusColor,
      ThinkingPhase() => const Color(0xFFFBBF24), // amber
      ToolPhase() => const Color(0xFF818CF8), // purple
      DonePhase() => const Color(0xFF34D399), // green
      ErrorPhase() => const Color(0xFFF87171), // red
    };
  }

  Duration get _animDuration {
    return switch (widget.props.hookPhase) {
      ThinkingPhase() => const Duration(milliseconds: 700),
      ToolPhase() => const Duration(milliseconds: 500),
      DonePhase() => const Duration(milliseconds: 400),
      _ => const Duration(milliseconds: 1800),
    };
  }

  void _updateAnimation() {
    // Animate only when there is an active hook phase (agent doing work).
    // When session is just live/idle (waiting for input), keep it calm.
    final shouldAnimate = widget.props.hookPhase != null;
    if (_animCtrl.duration != _animDuration) {
      _animCtrl.duration = _animDuration;
    }
    if (shouldAnimate && !_animCtrl.isAnimating) {
      _animCtrl.repeat(reverse: true);
    } else if (!shouldAnimate && _animCtrl.isAnimating) {
      _animCtrl.stop();
      _animCtrl.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.props.isRunning;
    final color = _phaseColor;
    final phase = widget.props.hookPhase;
    // Active = agent is actually doing something (thinking/tool/done/error).
    final isActive = phase != null;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) {
        final glowAlpha = isActive
            ? ((_glowAnim.value * 100 + 40).round()).clamp(40, 140)
            : 60; // static dim border when idle
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C10),
            border: Border.all(color: color.withAlpha(glowAlpha), width: 1.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: color.withAlpha((_glowAnim.value * 60 + 10).round()),
                  blurRadius: phase is ThinkingPhase ? 24 : 16,
                  spreadRadius: phase is ThinkingPhase ? 2 : 1,
                ),
              const BoxShadow(
                color: Color(0x90000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _AgentCardHeader(
            props: widget.props,
            color: color,
            isRunning: isRunning,
          ),
          if (phase != null)
            _HookPhaseBar(phase: phase, color: color, animation: _glowAnim),
          Expanded(
            child:
                widget.body ??
                (widget.props.isIdle
                    ? _IdlePlaceholder(onStart: widget.onSessionStart)
                    : _TerminalPane(
                        lines: widget.props.lastLines,
                        onInput: widget.onTerminalInput,
                      )),
          ),
          // Stripes only when actively processing (not just idle-running).
          if (isActive)
            _ActivityStripes(animation: _glowAnim, color: color),
        ],
      ),
    );
  }
}

/// Thin bar shown between header and body when a hook phase is active.
class _HookPhaseBar extends StatelessWidget {
  const _HookPhaseBar({
    required this.phase,
    required this.color,
    required this.animation,
  });
  final AgentPhase phase;
  final Color color;
  final Animation<double> animation;

  String get _label => switch (phase) {
    ThinkingPhase() => '● Thinking…',
    ToolPhase(:final toolName) => '⚙ $toolName',
    DonePhase() => '✓ Done',
    ErrorPhase() => '✕ Error',
  };

  bool get _showDots => phase is ThinkingPhase || phase is ToolPhase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(((animation.value * 20) + 10).round()),
          border: Border(
            bottom: BorderSide(color: color.withAlpha(60), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              _label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            if (_showDots)
              _DotsIndicator(animation: animation, color: color),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.animation, required this.color});
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final v = animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(
                    ((v - i * 0.15).clamp(0.1, 1.0) * 200).round(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AgentCardHeader extends StatelessWidget {
  const _AgentCardHeader({
    required this.props,
    required this.color,
    required this.isRunning,
  });
  final AgentCardProps props;
  final Color color;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E2330), width: 1),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: isRunning
                      ? [BoxShadow(color: color.withAlpha(180), blurRadius: 8)]
                      : [],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      props.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (props.typeName.isNotEmpty)
                      Text(
                        props.typeName,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF6B7898),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.terminal, size: 13, color: Color(0xFF34D399)),
            ],
          ),
          if (props.repos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final r in props.repos)
                  RepoBranchPill(repo: r.repo, branch: r.branch),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Styled terminal output lines — read-only view of PTY output.
class _TerminalPane extends StatefulWidget {
  const _TerminalPane({required this.lines, this.onInput});
  final List<String> lines;
  final void Function(String data)? onInput;

  @override
  State<_TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<_TerminalPane> {
  late final FocusNode _focusNode;

  bool get _interactive => widget.onInput != null;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'agent-card-terminal')
      ..addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _send(String data) {
    if (data.isEmpty) return;
    widget.onInput?.call(data);
  }

  Future<void> _pasteClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.isEmpty) return;
    _send(text);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_interactive) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final isMeta = keyboard.isMetaPressed;
    final isCtrl = keyboard.isControlPressed;
    final isAlt = keyboard.isAltPressed;
    final isShift = keyboard.isShiftPressed;

    if ((isMeta || isCtrl) && !isAlt && key == LogicalKeyboardKey.keyV) {
      unawaited(_pasteClipboard());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter) {
      _send(isShift && !isMeta && !isCtrl && !isAlt ? '\x1b\r' : '\r');
      return KeyEventResult.handled;
    }

    if (isMeta && key == LogicalKeyboardKey.backspace) {
      _send('\x15');
      return KeyEventResult.handled;
    }

    if ((isAlt || isCtrl) && key == LogicalKeyboardKey.backspace) {
      _send('\x17');
      return KeyEventResult.handled;
    }

    if (isMeta && key == LogicalKeyboardKey.arrowLeft) {
      _send('\x01');
      return KeyEventResult.handled;
    }

    if (isMeta && key == LogicalKeyboardKey.arrowRight) {
      _send('\x05');
      return KeyEventResult.handled;
    }

    if (isAlt && key == LogicalKeyboardKey.arrowLeft) {
      _send('\x1bb');
      return KeyEventResult.handled;
    }

    if (isAlt && key == LogicalKeyboardKey.arrowRight) {
      _send('\x1bf');
      return KeyEventResult.handled;
    }

    if (isMeta && key == LogicalKeyboardKey.keyK) {
      _send('\x0c');
      return KeyEventResult.handled;
    }

    final special = _specialSequenceFor(key);
    if (special != null) {
      _send(special);
      return KeyEventResult.handled;
    }

    if (isCtrl && !isMeta) {
      final control = _controlSequenceFor(key);
      if (control != null) {
        _send(control);
        return KeyEventResult.handled;
      }
    }

    final character = event.character;
    if (character != null &&
        character.isNotEmpty &&
        !isMeta &&
        !isCtrl &&
        character != '\u0000') {
      _send(isAlt ? '\x1b$character' : character);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  static String? _specialSequenceFor(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.backspace => '\x7f',
      LogicalKeyboardKey.tab => '\t',
      LogicalKeyboardKey.escape => '\x1b',
      LogicalKeyboardKey.arrowUp => '\x1b[A',
      LogicalKeyboardKey.arrowDown => '\x1b[B',
      LogicalKeyboardKey.arrowRight => '\x1b[C',
      LogicalKeyboardKey.arrowLeft => '\x1b[D',
      LogicalKeyboardKey.home => '\x1b[H',
      LogicalKeyboardKey.end => '\x1b[F',
      LogicalKeyboardKey.delete => '\x1b[3~',
      LogicalKeyboardKey.pageUp => '\x1b[5~',
      LogicalKeyboardKey.pageDown => '\x1b[6~',
      _ => null,
    };
  }

  static String? _controlSequenceFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return '\x00';

    final label = key.keyLabel;
    if (label.length == 1) {
      final code = label.toUpperCase().codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        return String.fromCharCode(code - 64);
      }
    }

    return switch (key) {
      LogicalKeyboardKey.bracketLeft => '\x1b',
      LogicalKeyboardKey.backslash => '\x1c',
      LogicalKeyboardKey.bracketRight => '\x1d',
      LogicalKeyboardKey.minus => '\x1f',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final lines = _TerminalLines(lines: widget.lines);
    if (!_interactive) return lines;

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focusNode.requestFocus,
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKeyEvent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              lines,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _focusNode.hasFocus ? 1 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withAlpha(150),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalLines extends StatelessWidget {
  const _TerminalLines({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No output',
          style: TextStyle(color: Color(0xFF475569), fontSize: 11),
        ),
      );
    }
    return Container(
      color: const Color(0xFF0A0F1A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        itemCount: lines.length,
        itemBuilder: (_, i) => Text(
          lines[i],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            color: Color(0xFF9ECFFF),
            height: 1.4,
          ),
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
      ),
    );
  }
}

class _IdlePlaceholder extends StatelessWidget {
  const _IdlePlaceholder({this.onStart});
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF0A0F1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.power_settings_new,
                size: 14,
                color: Colors.white.withAlpha(140),
              ),
              const SizedBox(width: 6),
              Text(
                'Saved session',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PTY not running. Click to start terminal.',
            style: TextStyle(color: Colors.white.withAlpha(110), fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (onStart != null)
            SizedBox(
              height: 26,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Start', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34D399).withAlpha(40),
                  foregroundColor: const Color(0xFF34D399),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: const Color(0xFF34D399).withAlpha(80),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

/// Animated horizontal stripe at the bottom of a running terminal card.
class _ActivityStripes extends StatelessWidget {
  const _ActivityStripes({required this.animation, required this.color});
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Container(
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withAlpha(0),
              color.withAlpha(180),
              color.withAlpha(0),
            ],
            stops: [
              (animation.value - 0.5).clamp(0.0, 1.0),
              animation.value,
              (animation.value + 0.5).clamp(0.0, 1.0),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// Repo + branch pill used in agent card headers.
class RepoBranchPill extends StatelessWidget {
  const RepoBranchPill({super.key, required this.repo, required this.branch});
  final String repo;
  final String branch;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2A),
          border: Border.all(color: const Color(0xFF2A3040), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
          const Icon(Icons.folder_outlined, size: 9, color: Color(0xFFC084FC)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              repo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFFCECEEE),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.alt_route, size: 9, color: Color(0xFF7C6BFF)),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              branch,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF9AA3BF),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
