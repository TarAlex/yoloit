import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/terminal_embed.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';

/// Agent terminal card — shows live terminal output.
/// Has an animated glowing border when the agent is actively running.
class AgentNode extends StatefulWidget {
  const AgentNode({super.key, required this.data});
  final AgentNodeData data;

  @override
  State<AgentNode> createState() => _AgentNodeState();
}

class _AgentNodeState extends State<AgentNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    if (widget.data.isRunning) _animCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AgentNode old) {
    super.didUpdateWidget(old);
    if (widget.data.isRunning && !_animCtrl.isAnimating) {
      _animCtrl.repeat(reverse: true);
    } else if (!widget.data.isRunning && _animCtrl.isAnimating) {
      _animCtrl.stop();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    return switch (widget.data.status) {
      AgentStatus.live  => const Color(0xFF34D399),
      AgentStatus.error => const Color(0xFFF87171),
      AgentStatus.idle  => const Color(0xFF60A5FA),
    };
  }

  @override
  Widget build(BuildContext context) {
    final session   = widget.data.session;
    final isRunning = widget.data.isRunning;
    final color     = _statusColor;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) {
        final glowAlpha = isRunning
            ? ((_glowAnim.value * 100 + 40).round()).clamp(40, 140)
            : 60;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C10),
            border: Border.all(color: color.withAlpha(glowAlpha), width: 1.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isRunning)
                BoxShadow(
                  color: color.withAlpha((_glowAnim.value * 60 + 10).round()),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              const BoxShadow(color: Color(0x90000000), blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          _AgentHeader(data: widget.data, color: _statusColor, isRunning: isRunning),
          // ── Terminal output / idle placeholder ────────────────────────
          Expanded(
            child: session.status == AgentStatus.idle && session.sessionId == null
                ? _IdleSessionPlaceholder(session: session)
                : TerminalEmbed(session: widget.data.session),
          ),
          // ── Animated activity bar ─────────────────────────────────────
          if (isRunning) _ActivityStripes(animation: _glowAnim, color: _statusColor),
        ],
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.data,
    required this.color,
    required this.isRunning,
  });
  final AgentNodeData data;
  final Color color;
  final bool isRunning;

  AgentSession get session => data.session;

  @override
  Widget build(BuildContext context) {
    // Prefer worktreeContexts; fall back to workspace repo paths; last resort: workspacePath.
    final rawWt = session.worktreeContexts ?? const <String, String>{};
    final Map<String, String> wt;
    if (rawWt.isNotEmpty) {
      wt = rawWt;
    } else if (data.workspacePaths.isNotEmpty) {
      wt = {for (final rp in data.workspacePaths) rp: data.workspaceBranch ?? 'main'};
    } else {
      wt = {session.workspacePath: 'main'};
    }
    final entries = wt.entries.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1218),
        border: const Border(bottom: BorderSide(color: Color(0xFF1E2330), width: 1)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
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
                      session.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      session.type.displayName,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF6B7898)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.terminal, size: 13, color: Color(0xFF34D399)),
            ],
          ),
          // ── Repo / branch pills ────────────────────────────────────
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in entries)
                  _RepoBranchPill(
                    repo: p.basename(e.key),
                    branch: p.basename(e.value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RepoBranchPill extends StatelessWidget {
  const _RepoBranchPill({required this.repo, required this.branch});
  final String repo;
  final String branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2A),
        border: Border.all(color: const Color(0xFF2A3040), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_outlined, size: 9, color: Color(0xFFC084FC)),
          const SizedBox(width: 3),
          Text(
            repo,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCECEEE),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.alt_route, size: 9, color: Color(0xFF7C6BFF)),
          const SizedBox(width: 2),
          Text(
            branch,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF9AA3BF),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated horizontal stripe at the bottom of a running terminal node.
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
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
    );
  }
}

/// Placeholder shown for persisted-but-not-yet-spawned sessions.
/// Click "Start" to call TerminalCubit.spawnSession to actually launch the PTY.
class _IdleSessionPlaceholder extends StatelessWidget {
  const _IdleSessionPlaceholder({required this.session});
  final AgentSession session;

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
              Icon(Icons.power_settings_new, size: 14, color: Colors.white.withAlpha(140)),
              const SizedBox(width: 6),
              Text(
                'Сохранённая сессия',
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
            'PTY не запущен. Нажмите, чтобы открыть терминал.',
            style: TextStyle(
              color: Colors.white.withAlpha(110),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 26,
            child: ElevatedButton.icon(
              onPressed: () async {
                final cubit = context.read<TerminalCubit>();
                await cubit.spawnSession(
                  type: session.type,
                  workspacePath: session.workspacePath,
                  workspaceId: session.workspaceId,
                  savedSessionId: session.id,
                  isRestore: true,
                );
              },
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Запустить', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399).withAlpha(40),
                foregroundColor: const Color(0xFF34D399),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: const Color(0xFF34D399).withAlpha(80)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
