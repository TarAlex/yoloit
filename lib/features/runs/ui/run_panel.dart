import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/runs/bloc/run_state.dart';
import 'package:yoloit/features/runs/models/run_config.dart';
import 'package:yoloit/features/runs/models/run_session.dart';
import 'package:yoloit/features/runs/ui/run_config_dialog.dart';

class RunPanel extends StatelessWidget {
  const RunPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunCubit, RunState>(
      builder: (context, state) {
        return _RunPanelView(state: state);
      },
    );
  }
}

class _RunPanelView extends StatefulWidget {
  const _RunPanelView({required this.state});
  final RunState state;

  @override
  State<_RunPanelView> createState() => _RunPanelViewState();
}

class _RunPanelViewState extends State<_RunPanelView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_RunPanelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSession = oldWidget.state.activeSession;
    final newSession = widget.state.activeSession;
    if (newSession != null &&
        newSession.output.length != (oldSession?.output.length ?? 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = widget.state;

    return Container(
      color: AppColors.terminalBackground,
      child: Column(
        children: [
          _Header(state: state),
          Expanded(
            child: Row(
              children: [
                _ConfigList(state: state),
                Container(width: 1, color: colors.divider),
                Expanded(child: _Console(state: state, scrollController: _scrollController)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final RunState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<RunCubit>();
    final activeSession = state.activeSession;
    final isRunning = activeSession?.status == RunStatus.running;
    final isFlutter = activeSession?.config.isFlutterRun ?? false;

    return Container(
      height: 36,
      color: colors.surface,
      child: Row(
        children: [
          // Session tabs
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...state.sessions.map((s) => _SessionTab(
                      session: s,
                      isActive: s.id == state.activeSessionId,
                      onTap: () => cubit.setActiveSession(s.id),
                      onClose: () => cubit.removeSession(s.id),
                    )),
              ],
            ),
          ),
          // Action buttons
          if (activeSession != null) ...[
            if (isRunning && isFlutter) ...[
              _HeaderButton(
                tooltip: 'Hot Reload (r)',
                label: '🔥',
                onTap: () => cubit.sendHotReload(activeSession.id),
              ),
              _HeaderButton(
                tooltip: 'Hot Restart (R)',
                label: 'R',
                onTap: () => cubit.sendHotRestart(activeSession.id),
                textStyle: const TextStyle(
                  color: AppColors.neonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (isRunning)
              _HeaderButton(
                tooltip: 'Stop',
                icon: Icons.stop_rounded,
                iconColor: AppColors.neonRed,
                onTap: () => cubit.stopRun(activeSession.id),
              )
            else
              _HeaderButton(
                tooltip: 'Re-run',
                icon: Icons.play_arrow_rounded,
                iconColor: AppColors.neonGreen,
                onTap: () => cubit.startRun(activeSession.config),
              ),
            _HeaderButton(
              tooltip: 'Clear output',
              icon: Icons.clear_all_rounded,
              iconColor: AppColors.textMuted,
              onTap: () => cubit.clearOutput(activeSession.id),
            ),
          ],
          Container(width: 1, height: 20, color: colors.border),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final RunSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isRunning = session.status == RunStatus.running;
    final dotColor = session.config.color ??
        (isRunning ? AppColors.neonGreen : AppColors.textMuted);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.tabActiveBg : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? colors.tabBorder : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRunning)
              SizedBox(
                width: 8,
                height: 8,
                child: _PulsingDot(color: dotColor),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: session.status == RunStatus.failed
                      ? AppColors.neonRed
                      : dotColor,
                ),
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                session.config.name,
                style: TextStyle(
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose,
              child: const Icon(
                Icons.close,
                size: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    this.icon,
    this.iconColor,
    this.label,
    this.textStyle,
    required this.onTap,
  });

  final String tooltip;
  final IconData? icon;
  final Color? iconColor;
  final String? label;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 14, color: iconColor)
              : Text(
                  label ?? '',
                  style: textStyle ??
                      const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12),
                ),
        ),
      ),
    );
  }
}

// ── Config List ──────────────────────────────────────────────────────────────

class _ConfigList extends StatelessWidget {
  const _ConfigList({required this.state});
  final RunState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<RunCubit>();

    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: const Text(
              'CONFIGURATIONS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 4),
              children: [
                ...state.configs.map((c) => _ConfigItem(
                      config: c,
                      isRunning: state.sessions.any(
                        (s) =>
                            s.config.id == c.id &&
                            s.status == RunStatus.running,
                      ),
                      onRun: () => cubit.startRun(c),
                      onEdit: () async {
                        final updated =
                            await RunConfigDialog.show(context, initial: c);
                        if (updated != null) cubit.updateConfig(updated);
                      },
                      onDelete: () => cubit.removeConfig(c.id),
                    )),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: InkWell(
                    onTap: () async {
                      final config =
                          await RunConfigDialog.show(context);
                      if (config != null) cubit.addConfig(config);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 12, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Add Configuration',
                            style: TextStyle(
                                color: colors.primary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigItem extends StatefulWidget {
  const _ConfigItem({
    required this.config,
    required this.isRunning,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  final RunConfig config;
  final bool isRunning;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ConfigItem> createState() => _ConfigItemState();
}

class _ConfigItemState extends State<_ConfigItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dotColor =
        widget.config.color ?? AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: _hovering ? colors.surfaceHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.config.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hovering || widget.isRunning) ...[
              if (widget.isRunning)
                const _SmallIconButton(
                  icon: Icons.fiber_manual_record,
                  color: AppColors.neonGreen,
                  tooltip: 'Running',
                  onTap: null,
                ),
              _SmallIconButton(
                icon: Icons.play_arrow_rounded,
                color: AppColors.neonGreen,
                tooltip: 'Run',
                onTap: widget.onRun,
              ),
              _SmallIconButton(
                icon: Icons.more_vert,
                color: AppColors.textMuted,
                tooltip: 'Options',
                onTap: () => _showMenu(context),
              ),
            ] else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width,
        offset.dy,
        offset.dx + box.size.width + 160,
        offset.dy + 100,
      ),
      color: context.appColors.surfaceElevated,
      items: [
        const PopupMenuItem(
          value: 'edit',
          height: 32,
          child: Text('Edit',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'delete',
          height: 32,
          child: Text('Delete',
              style: TextStyle(color: AppColors.neonRed, fontSize: 12)),
        ),
      ],
    ).then((value) {
      if (value == 'edit') widget.onEdit();
      if (value == 'delete') widget.onDelete();
    });
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 22,
          height: 28,
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    );
  }
}

// ── Console Output ───────────────────────────────────────────────────────────

class _Console extends StatelessWidget {
  const _Console({required this.state, required this.scrollController});
  final RunState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final session = state.activeSession;

    if (session == null) {
      return _EmptyConsole(
        hasWorkspace: state.workspacePath != null,
        configs: state.configs,
      );
    }

    final output = session.output;

    return Container(
      color: AppColors.terminalBackground,
      child: Column(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.surface,
            child: Row(
              children: [
                Text(
                  '> ${session.config.command}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (session.startedAt != null)
                  Text(
                    _formatTime(session.startedAt!),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          Expanded(
            child: output.isEmpty
                ? const Center(
                    child: Text(
                      'No output yet…',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    itemCount: output.length,
                    itemBuilder: (context, i) {
                      final line = output[i];
                      return _OutputLine(line: line);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _OutputLine extends StatelessWidget {
  const _OutputLine({required this.line});
  final RunOutputLine line;

  @override
  Widget build(BuildContext context) {
    final text = line.text;
    final isError = line.isError;

    final Color color;
    if (text.startsWith('\n[Process exited')) {
      color = const Color(0xFF44446A);
    } else if (text.startsWith('Reloaded') || text.contains('🔥')) {
      color = AppColors.neonGreen;
    } else if (isError) {
      color = AppColors.neonRed;
    } else if (text.toLowerCase().contains('error')) {
      color = AppColors.neonOrange;
    } else {
      color = AppColors.terminalText;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: SelectableText(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}

class _EmptyConsole extends StatelessWidget {
  const _EmptyConsole({
    required this.hasWorkspace,
    required this.configs,
  });

  final bool hasWorkspace;
  final List<RunConfig> configs;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<RunCubit>();

    return Container(
      color: AppColors.terminalBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle_outline,
                  size: 32, color: colors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Run Configurations',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasWorkspace
                  ? 'Select a configuration from the left panel to run it'
                  : 'Open a workspace to get started',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
            if (hasWorkspace && configs.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: configs
                    .take(3)
                    .map(
                      (c) => _RunQuickButton(
                        config: c,
                        onTap: () => cubit.startRun(c),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunQuickButton extends StatelessWidget {
  const _RunQuickButton({required this.config, required this.onTap});
  final RunConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dotColor = config.color ?? colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 12, color: dotColor),
            const SizedBox(width: 4),
            Text(config.name,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing dot animation ────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withAlpha((_anim.value * 255).round()),
        ),
      ),
    );
  }
}
