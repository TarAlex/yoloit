import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

void showSessionOverview(
  BuildContext context, {
  required AgentSession session,
  required Workspace workspace,
  required List<AgentSession> sessions,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withAlpha(200),
      pageBuilder: (_, __, ___) => SessionOverviewPanel(
        session: session,
        workspace: workspace,
        sessions: sessions,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    ),
  );
}

// ── Panel ─────────────────────────────────────────────────────────────────────

enum _ViewMode { orbit, list, graph }

class SessionOverviewPanel extends StatefulWidget {
  const SessionOverviewPanel({
    super.key,
    required this.session,
    required this.workspace,
    required this.sessions,
  });

  final AgentSession session;
  final Workspace workspace;
  final List<AgentSession> sessions;

  @override
  State<SessionOverviewPanel> createState() => _SessionOverviewPanelState();
}

class _SessionOverviewPanelState extends State<SessionOverviewPanel>
    with TickerProviderStateMixin {
  _ViewMode _mode = _ViewMode.orbit;
  late final AnimationController _rotationCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  String? _selectedId;

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            session: widget.session,
            workspace: widget.workspace,
            sessions: widget.sessions,
            mode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildContent()),
                if (_selectedId != null)
                  _DetailPanel(
                    selectedId: _selectedId!,
                    sessions: widget.sessions,
                    workspace: widget.workspace,
                    onClose: () => setState(() => _selectedId = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case _ViewMode.orbit:
        return _OrbitView(
          session: widget.session,
          sessions: widget.sessions,
          workspace: widget.workspace,
          rotationAnim: _rotationCtrl,
          selectedId: _selectedId,
          onSelect: (id) => setState(() => _selectedId = id == _selectedId ? null : id),
        );
      case _ViewMode.list:
        return _AgentListView(
          sessions: widget.sessions,
          workspace: widget.workspace,
          selectedId: _selectedId,
          onSelect: (id) => setState(() => _selectedId = id == _selectedId ? null : id),
        );
      case _ViewMode.graph:
        return _GraphView(
          sessions: widget.sessions,
          workspace: widget.workspace,
          selectedId: _selectedId,
          onSelect: (id) => setState(() => _selectedId = id == _selectedId ? null : id),
        );
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.workspace,
    required this.sessions,
    required this.mode,
    required this.onModeChanged,
    required this.onClose,
  });

  final AgentSession session;
  final Workspace workspace;
  final List<AgentSession> sessions;
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onModeChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(18)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.textMuted),
            onPressed: onClose,
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: session.status == AgentStatus.live
                  ? AppColors.neonGreen
                  : AppColors.neonBlue,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonGreen.withAlpha(120),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${sessions.length} agents · ${workspace.paths.length} repos',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          _ViewSwitcher(mode: mode, onChanged: onModeChanged),
        ],
      ),
    );
  }
}

// ── View Switcher ─────────────────────────────────────────────────────────────

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.mode, required this.onChanged});

  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchBtn(label: 'Orbit', icon: Icons.radar, active: mode == _ViewMode.orbit, onTap: () => onChanged(_ViewMode.orbit)),
          _SwitchBtn(label: 'List', icon: Icons.format_list_bulleted, active: mode == _ViewMode.list, onTap: () => onChanged(_ViewMode.list)),
          _SwitchBtn(label: 'Graph', icon: Icons.account_tree_outlined, active: mode == _ViewMode.graph, onTap: () => onChanged(_ViewMode.graph)),
        ],
      ),
    );
  }
}

class _SwitchBtn extends StatelessWidget {
  const _SwitchBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.neonBlue.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: AppColors.neonBlue.withAlpha(80)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? AppColors.neonBlue : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.neonBlue : AppColors.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Orbit View ────────────────────────────────────────────────────────────────

class _OrbitView extends StatelessWidget {
  const _OrbitView({
    required this.session,
    required this.sessions,
    required this.workspace,
    required this.rotationAnim,
    required this.selectedId,
    required this.onSelect,
  });

  final AgentSession session;
  final List<AgentSession> sessions;
  final Workspace workspace;
  final Animation<double> rotationAnim;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: rotationAnim,
      builder: (context, _) {
        return GestureDetector(
          onTapUp: (details) => _handleTap(context, details),
          child: CustomPaint(
            painter: _OrbitPainter(
              sessions: sessions,
              workspace: workspace,
              rotation: rotationAnim.value * 2 * math.pi,
              selectedId: selectedId,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final size = (context.findRenderObject() as RenderBox).size;
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    final outerR = minDim * 0.38;
    final innerR = minDim * 0.22;
    final rotation = rotationAnim.value * 2 * math.pi;

    // Check agents (outer ring)
    for (var i = 0; i < sessions.length; i++) {
      final angle = rotation + (2 * math.pi * i / sessions.length);
      final pos = center + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR);
      if ((details.localPosition - pos).distance < 24) {
        onSelect(sessions[i].id);
        return;
      }
    }

    // Check repos (inner ring)
    final repos = workspace.paths;
    for (var i = 0; i < repos.length; i++) {
      final angle = -rotation * 0.4 + (2 * math.pi * i / repos.length);
      final pos = center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR);
      if ((details.localPosition - pos).distance < 20) {
        onSelect('repo_$i');
        return;
      }
    }
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.sessions,
    required this.workspace,
    required this.rotation,
    required this.selectedId,
  });

  final List<AgentSession> sessions;
  final Workspace workspace;
  final double rotation;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    final outerR = minDim * 0.38;
    final innerR = minDim * 0.22;
    final centerR = minDim * 0.10;

    _drawRings(canvas, center, outerR, innerR);
    _drawCenter(canvas, center, centerR);
    _drawRepos(canvas, center, innerR);
    _drawAgents(canvas, center, outerR);
  }

  void _drawRings(Canvas canvas, Offset center, double outerR, double innerR) {
    final ringPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, outerR, ringPaint);
    canvas.drawCircle(center, innerR, dashPaint);
    canvas.drawCircle(center, outerR * 1.25, dashPaint..color = Colors.white.withAlpha(6));
  }

  void _drawCenter(Canvas canvas, Offset center, double r) {
    // Glow
    final glowPaint = Paint()
      ..color = AppColors.neonBlue.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, r * 1.4, glowPaint);

    // Filled circle
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFF1A1A4A),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = AppColors.neonBlue.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawLabel(canvas, center + Offset(0, r + 14), 'session', 9, AppColors.textMuted);
  }

  void _drawRepos(Canvas canvas, Offset center, double innerR) {
    final repos = workspace.paths;
    for (var i = 0; i < repos.length; i++) {
      final angle = -rotation * 0.4 + (2 * math.pi * i / repos.length);
      final pos = center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR);
      final isSelected = selectedId == 'repo_$i';

      _drawLine(canvas, center, pos, AppColors.neonBlue.withAlpha(30));

      // Repo node
      canvas.drawCircle(
        pos,
        14,
        Paint()..color = const Color(0xFF101030),
      );
      canvas.drawCircle(
        pos,
        14,
        Paint()
          ..color = isSelected
              ? AppColors.neonBlue.withAlpha(200)
              : AppColors.neonBlue.withAlpha(80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2 : 1,
      );

      // "repo" label inside
      _drawLabel(canvas, pos, 'repo', 8, AppColors.neonBlue.withAlpha(200));
      _drawLabel(canvas, pos + const Offset(0, 22), p.basename(repos[i]), 9, AppColors.textMuted);
    }
  }

  void _drawAgents(Canvas canvas, Offset center, double outerR) {
    for (var i = 0; i < sessions.length; i++) {
      final angle = rotation + (2 * math.pi * i / sessions.length);
      final pos = center + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR);
      final s = sessions[i];
      final isSelected = selectedId == s.id;

      _drawLine(canvas, center, pos, AppColors.neonGreen.withAlpha(20));

      final color = s.status == AgentStatus.live
          ? AppColors.neonGreen
          : s.status == AgentStatus.error
              ? AppColors.neonRed
              : AppColors.neonBlue;

      // Glow for selected
      if (isSelected) {
        canvas.drawCircle(
          pos,
          22,
          Paint()
            ..color = color.withAlpha(60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }

      // Outer ring (orbit indicator)
      canvas.drawCircle(
        pos,
        18,
        Paint()
          ..color = color.withAlpha(isSelected ? 80 : 40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2 : 1,
      );

      // Inner dot
      canvas.drawCircle(
        pos,
        8,
        Paint()..color = color.withAlpha(isSelected ? 255 : 180),
      );

      _drawLabel(canvas, pos + const Offset(0, 26), s.displayName, 10, AppColors.textSecondary);
    }
  }

  void _drawLine(Canvas canvas, Offset from, Offset to, Color color) {
    canvas.drawLine(from, to, Paint()..color = color..strokeWidth = 1);
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.rotation != rotation || old.selectedId != selectedId;
}

// ── Agent List View ────────────────────────────────────────────────────────────

class _AgentListView extends StatelessWidget {
  const _AgentListView({
    required this.sessions,
    required this.workspace,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AgentSession> sessions;
  final Workspace workspace;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            'AGENTS (${sessions.length})',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final s = sessions[i];
              final isSelected = s.id == selectedId;
              final color = s.status == AgentStatus.live
                  ? AppColors.neonGreen
                  : s.status == AgentStatus.error
                      ? AppColors.neonRed
                      : AppColors.neonBlue;
              return GestureDetector(
                onTap: () => onSelect(s.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.neonBlue.withAlpha(20)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.neonBlue.withAlpha(100)
                          : Colors.white.withAlpha(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.type.iconLabel,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.displayName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              s.workspacePath.split('/').last,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withAlpha(60)),
                        ),
                        child: Text(
                          s.status.name,
                          style: TextStyle(color: color, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Graph View (placeholder with node layout) ─────────────────────────────────

class _GraphView extends StatelessWidget {
  const _GraphView({
    required this.sessions,
    required this.workspace,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AgentSession> sessions;
  final Workspace workspace;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphPainter(sessions: sessions, workspace: workspace, selectedId: selectedId),
      child: Stack(
        children: [
          // Repo nodes (top row)
          for (var i = 0; i < workspace.paths.length; i++)
            _buildRepoNode(context, i),
          // Agent nodes (bottom row)
          for (var i = 0; i < sessions.length; i++)
            _buildAgentNode(context, i),
        ],
      ),
    );
  }

  Widget _buildRepoNode(BuildContext context, int i) {
    final repoName = p.basename(workspace.paths[i]);
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final total = workspace.paths.length;
        final w = constraints.maxWidth;
        final x = (w / (total + 1)) * (i + 1);
        return Positioned(
          left: x - 40,
          top: 60,
          child: _GraphNode(
            label: repoName,
            icon: Icons.folder_open,
            color: AppColors.neonBlue,
            width: 80,
            onTap: () => onSelect('repo_$i'),
          ),
        );
      },
    );
  }

  Widget _buildAgentNode(BuildContext context, int i) {
    final s = sessions[i];
    final color = s.status == AgentStatus.live ? AppColors.neonGreen : AppColors.neonBlue;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final total = sessions.length;
        final w = constraints.maxWidth;
        final x = (w / (total + 1)) * (i + 1);
        return Positioned(
          left: x - 40,
          top: 240,
          child: _GraphNode(
            label: s.displayName,
            icon: Icons.smart_toy_outlined,
            color: color,
            width: 80,
            isSelected: s.id == selectedId,
            onTap: () => onSelect(s.id),
          ),
        );
      },
    );
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.label,
    required this.icon,
    required this.color,
    required this.width,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(40) : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : color.withAlpha(80),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withAlpha(60), blurRadius: 12)]
                    : null,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.sessions,
    required this.workspace,
    required this.selectedId,
  });

  final List<AgentSession> sessions;
  final Workspace workspace;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 1;

    final repos = workspace.paths;
    for (var r = 0; r < repos.length; r++) {
      final rx = (size.width / (repos.length + 1)) * (r + 1);
      for (var a = 0; a < sessions.length; a++) {
        final ax = (size.width / (sessions.length + 1)) * (a + 1);
        canvas.drawLine(
          Offset(rx, 84),
          Offset(ax, 240),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => false;
}

// ── Detail Panel (right side) ─────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.selectedId,
    required this.sessions,
    required this.workspace,
    required this.onClose,
  });

  final String selectedId;
  final List<AgentSession> sessions;
  final Workspace workspace;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isRepo = selectedId.startsWith('repo_');
    final session = isRepo
        ? null
        : sessions.where((s) => s.id == selectedId).firstOrNull;
    final repoPath = isRepo
        ? workspace.paths[int.parse(selectedId.replaceFirst('repo_', ''))]
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: Colors.white.withAlpha(18))),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('SELECTED', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.2)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session != null) _SessionDetail(session: session),
          if (repoPath != null) _RepoDetail(repoPath: repoPath),
        ],
      ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.session});
  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    final color = session.status == AgentStatus.live
        ? AppColors.neonGreen
        : AppColors.neonBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.displayName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Agent · ${session.type.name}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        Row(
          children: [
            _Tag(label: 'agent', color: AppColors.neonBlue),
            const SizedBox(width: 6),
            _Tag(label: session.status.name, color: color),
          ],
        ),
        const SizedBox(height: 16),
        const Text('WORKSPACE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          session.workspacePath.split('/').last,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _RepoDetail extends StatelessWidget {
  const _RepoDetail({required this.repoPath});
  final String repoPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.basename(repoPath), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Repository', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        _Tag(label: 'repo', color: AppColors.neonBlue),
        const SizedBox(height: 16),
        const Text('PATH', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          repoPath,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
