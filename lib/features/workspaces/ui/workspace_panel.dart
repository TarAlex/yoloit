import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/data/workspace_secrets_service.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/ui/worktree_section.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';

class WorkspacePanel extends StatefulWidget {
  const WorkspacePanel({super.key});

  @override
  State<WorkspacePanel> createState() => _WorkspacePanelState();
}

class _WorkspacePanelState extends State<WorkspacePanel> {
  bool _showThemePicker = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildWorkspacesList(),
                  _buildWorktreeSection(),
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

  Widget _buildLogo(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withAlpha(60)),
            ),
            padding: const EdgeInsets.all(4),
            child: SvgPicture.asset('assets/images/yoloit_mark.svg'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'yoloit',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'AI ORCHESTRATOR',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorktreeSection() {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, state) {
        if (state is! WorkspaceLoaded || state.activeWorkspaceId == null) {
          return const SizedBox.shrink();
        }
        final active = state.workspaces.firstWhere(
          (w) => w.id == state.activeWorkspaceId,
          orElse: () => state.workspaces.first,
        );
        return WorktreeSection(
          workspacePath: active.path,
          workspaceName: active.name,
        );
      },
    );
  }

  Widget _buildWorkspacesList() {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, state) {
        final colors = context.appColors;
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
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.border, style: BorderStyle.solid),
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
                  onColorChange: (color) =>
                      context.read<WorkspaceCubit>().setWorkspaceColor(ws.id, color),
                  onSecretsOpen: () => _showSecretsDialog(context, ws),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSetupSection() => const SizedBox.shrink();

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
    context.read<TerminalCubit>().spawnSession(
          type: type,
          workspacePath: ws.path,
          workspaceId: ws.id,
        );
  }

  void _showSecretsDialog(BuildContext context, Workspace ws) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SecretsDialog(workspaceId: ws.id, workspaceName: ws.name),
    );
  }
}

class _WorkspaceTile extends StatefulWidget {
  const _WorkspaceTile({
    required this.workspace,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
    required this.onSpawnAgent,
    required this.onColorChange,
    required this.onSecretsOpen,
  });

  final Workspace workspace;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final void Function(AgentType) onSpawnAgent;
  final void Function(Color) onColorChange;
  final VoidCallback onSecretsOpen;

  @override
  State<_WorkspaceTile> createState() => _WorkspaceTileState();
}

class _WorkspaceTileState extends State<_WorkspaceTile> {
  bool _hovering = false;
  bool _showAgentMenu = false;
  bool _showColorPicker = false;

  static const _palette = [
    Color(0xFFC026D3), // purple (default)
    Color(0xFF2563EB), // blue
    Color(0xFF16A34A), // green
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
    Color(0xFF6D28D9), // violet
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ws = widget.workspace;
    final accentColor = ws.color ?? colors.primary;
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
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? accentColor.withAlpha(30)
                  : _hovering
                      ? colors.surfaceHighlight
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: widget.isActive
                  ? Border.all(color: accentColor.withAlpha(80))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Color dot — click to open color picker
                    GestureDetector(
                      onTap: () => setState(() => _showColorPicker = !_showColorPicker),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withAlpha(60),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
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
                        icon: Icons.key_outlined,
                        onTap: widget.onSecretsOpen,
                        tooltip: 'Workspace secrets',
                      ),
                      _SmallIconButton(
                        icon: Icons.close,
                        onTap: widget.onRemove,
                        tooltip: 'Remove',
                      ),
                    ],
                    if (_hovering && widget.isActive)
                      _SmallIconButton(
                        icon: Icons.key_outlined,
                        onTap: widget.onSecretsOpen,
                        tooltip: 'Workspace secrets',
                      ),
                  ],
                ),
                // Color picker row
                if (_showColorPicker) ...[
                  SizedBox(height: 8),
                  Row(
                    children: _palette.map((c) {
                      final selected = (ws.color ?? colors.primary) == c;
                      return GestureDetector(
                        onTap: () {
                          widget.onColorChange(c);
                          setState(() => _showColorPicker = false);
                        },
                        child: Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                          margin: EdgeInsets.only(right: 4),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colors.primary.withAlpha(80)),
                          ),
                          child: Text(
                            type.displayName,
                            style: TextStyle(
                              color: colors.primaryLight,
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
    final colors = context.appColors;
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
            duration: Duration(milliseconds: 100),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _hovering ? colors.surfaceHighlight : Colors.transparent,
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

class _SecretsDialog extends StatefulWidget {
  const _SecretsDialog({required this.workspaceId, required this.workspaceName});

  final String workspaceId;
  final String workspaceName;

  @override
  State<_SecretsDialog> createState() => _SecretsDialogState();
}

class _SecretsDialogState extends State<_SecretsDialog> {
  Map<String, String> _secrets = {};
  bool _loading = true;
  // Track revealed state per row index
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await WorkspaceSecretsService.instance.load(widget.workspaceId);
    if (mounted) setState(() { _secrets = Map.from(loaded); _loading = false; });
  }

  void _addEntry() {
    setState(() => _secrets[''] = '');
  }

  Future<void> _save() async {
    await WorkspaceSecretsService.instance.save(widget.workspaceId, _secrets);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final entries = _secrets.entries.toList();
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔐 Workspace Secrets',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Injected as env vars when launching agents in ${widget.workspaceName}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No secrets yet. Add a KEY=VALUE pair.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final key = entries[i].key;
                      final value = entries[i].value;
                      final revealed = _revealed.contains(i);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _SecretTextField(
                                initialValue: key,
                                hint: 'KEY',
                                onChanged: (newKey) {
                                  final val = _secrets.remove(key) ?? value;
                                  setState(() => _secrets[newKey] = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _SecretTextField(
                                initialValue: value,
                                hint: 'VALUE',
                                obscure: !revealed,
                                onChanged: (v) => setState(() => _secrets[key] = v),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              splashRadius: 14,
                              tooltip: revealed ? 'Hide' : 'Reveal',
                              onPressed: () => setState(() {
                                if (revealed) { _revealed.remove(i); } else { _revealed.add(i); }
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.neonRed),
                              splashRadius: 14,
                              tooltip: 'Delete',
                              onPressed: () => setState(() => _secrets.remove(key)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _addEntry,
                  icon: Icon(Icons.add, size: 14),
                  label: Text('Add secret', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: colors.primary),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretTextField extends StatelessWidget {
  const _SecretTextField({
    required this.initialValue,
    required this.hint,
    required this.onChanged,
    this.obscure = false,
  });

  final String initialValue;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextFormField(
      initialValue: initialValue,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
