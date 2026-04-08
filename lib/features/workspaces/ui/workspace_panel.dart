import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

class WorkspacePanel extends StatefulWidget {
  const WorkspacePanel({super.key});

  @override
  State<WorkspacePanel> createState() => _WorkspacePanelState();
}

class _WorkspacePanelState extends State<WorkspacePanel> {
  bool _showThemePicker = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildWorkspacesList(),
                  _buildSetupSection(),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: const Icon(Icons.hub_outlined, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'yoloit',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'AI ORCHESTRATOR',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacesList() {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, state) {
        final workspaces = state is WorkspaceLoaded ? state.workspaces : <Workspace>[];
        final activeId = state is WorkspaceLoaded ? state.activeWorkspaceId : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Workspaces / Repositories',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  _SmallIconButton(
                    icon: Icons.add,
                    onTap: () => _addWorkspace(context),
                    tooltip: 'Add workspace',
                  ),
                ],
              ),
            ),
            if (workspaces.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  label: 'Open a folder',
                  button: true,
                  child: GestureDetector(
                    onTap: () => _addWorkspace(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.folder_open_outlined, size: 14,
                              color: AppColors.textMuted, semanticLabel: 'folder'),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Open a folder...',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              ...workspaces.map(
                (ws) => _WorkspaceTile(
                  workspace: ws,
                  isActive: ws.id == activeId,
                  onTap: () => _selectWorkspace(context, ws),
                  onRemove: () => context.read<WorkspaceCubit>().removeWorkspace(ws.id),
                  onSpawnAgent: (type) => _spawnAgent(context, ws, type),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSetupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
          child: Text(
            'Setup',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        _SetupItem(icon: Icons.terminal_outlined, label: 'Environment Scripts', onTap: () {}),
        _SetupItem(icon: Icons.key_outlined, label: 'API Keys & Secrets', onTap: () {}),
        _SetupItem(icon: Icons.dns_outlined, label: 'Docker Configs', onTap: () {}),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        const Divider(height: 1),
        if (_showThemePicker) _buildThemePicker(),
        _SetupItem(
          icon: Icons.color_lens_outlined,
          label: 'Color Themes',
          onTap: () => setState(() => _showThemePicker = !_showThemePicker),
          trailing: Icon(
            _showThemePicker ? Icons.expand_less : Icons.chevron_right,
            size: 14,
            color: AppColors.textMuted,
          ),
        ),
        _SetupItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildThemePicker() {
    const themes = AppThemePreset.values;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: themes.map((t) {
          return InkWell(
            onTap: () => ThemeManager.instance.setTheme(t),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _addWorkspace(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Workspace Folder',
    );
    if (result != null && context.mounted) {
      await context.read<WorkspaceCubit>().addWorkspace(result);
    }
  }

  void _selectWorkspace(BuildContext context, Workspace ws) {
    context.read<WorkspaceCubit>().setActive(ws.id);
    context.read<ReviewCubit>().loadWorkspace(ws.path);
  }

  void _spawnAgent(BuildContext context, Workspace ws, AgentType type) {
    context.read<WorkspaceCubit>().setActive(ws.id);
    context.read<TerminalCubit>().spawnSession(type: type, workspacePath: ws.path);
  }
}

class _WorkspaceTile extends StatefulWidget {
  const _WorkspaceTile({
    required this.workspace,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
    required this.onSpawnAgent,
  });

  final Workspace workspace;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final void Function(AgentType) onSpawnAgent;

  @override
  State<_WorkspaceTile> createState() => _WorkspaceTileState();
}

class _WorkspaceTileState extends State<_WorkspaceTile> {
  bool _hovering = false;
  bool _showAgentMenu = false;

  @override
  Widget build(BuildContext context) {
    final ws = widget.workspace;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _showAgentMenu = false;
      }),
      child: Semantics(
        label: '${ws.name} workspace${widget.isActive ? ', active' : ''}',
        button: true,
        selected: widget.isActive,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withAlpha(30)
                  : _hovering
                      ? AppColors.surfaceHighlight
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: widget.isActive
                  ? Border.all(color: AppColors.primary.withAlpha(60))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ws.name,
                        style: TextStyle(
                          color: widget.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.neonGreen.withAlpha(30),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_hovering && !widget.isActive) ...[
                      _SmallIconButton(
                        icon: Icons.terminal_outlined,
                        onTap: () => setState(() => _showAgentMenu = !_showAgentMenu),
                        tooltip: 'Start agent',
                      ),
                      _SmallIconButton(
                        icon: Icons.close,
                        onTap: widget.onRemove,
                        tooltip: 'Remove',
                      ),
                    ],
                  ],
                ),
                if (ws.gitBranch != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.alt_route, size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Git Branch: ${ws.gitBranch}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (ws.addedLines > 0 || ws.removedLines > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (ws.addedLines > 0)
                        Text(
                          '+${ws.addedLines}',
                          style: const TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (ws.addedLines > 0 && ws.removedLines > 0)
                        const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      if (ws.removedLines > 0)
                        Text(
                          '-${ws.removedLines}',
                          style: const TextStyle(
                            color: AppColors.neonRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Text(
                        ' lines',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
                if (_showAgentMenu) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: AgentType.values.map((type) {
                      return GestureDetector(
                        onTap: () => widget.onSpawnAgent(type),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withAlpha(80)),
                          ),
                          child: Text(
                            type.displayName,
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupItem extends StatefulWidget {
  const _SetupItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_SetupItem> createState() => _SetupItemState();
}

class _SetupItemState extends State<_SetupItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        label: widget.label,
        button: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _hovering ? AppColors.surfaceHighlight : Colors.transparent,
            child: Row(
              children: [
                Icon(widget.icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        label: tooltip,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 12, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
