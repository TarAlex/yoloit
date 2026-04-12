import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/data/worktree_service.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/models/worktree_model.dart';

class WorkspaceInlineTree extends StatefulWidget {
  const WorkspaceInlineTree({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<WorkspaceInlineTree> createState() => _WorkspaceInlineTreeState();
}

class _WorkspaceInlineTreeState extends State<WorkspaceInlineTree> {
  /// repoPath → list of worktrees
  Map<String, List<WorktreeEntry>> _worktrees = {};
  bool _loading = true;
  /// repoPath → true if branch-add field is shown
  final Map<String, bool> _showAddBranch = {};
  /// repoPath → controller for branch name input
  final Map<String, TextEditingController> _branchControllers = {};

  @override
  void initState() {
    super.initState();
    _loadWorktrees();
  }

  @override
  void didUpdateWidget(WorkspaceInlineTree old) {
    super.didUpdateWidget(old);
    if (old.workspace.paths != widget.workspace.paths) {
      _loadWorktrees();
    }
  }

  Future<void> _loadWorktrees() async {
    setState(() => _loading = true);
    final result = <String, List<WorktreeEntry>>{};
    for (final path in widget.workspace.paths) {
      result[path] = await WorktreeService.instance.listWorktrees(path);
    }
    if (mounted) {
      setState(() {
        _worktrees = result;
        _loading = false;
      });
    }
  }

  Future<void> _addWorktree(String repoPath, String branchName) async {
    final worktreePath = p.join(
      p.dirname(repoPath),
      '${p.basename(repoPath)}__${branchName.replaceAll('/', '-')}',
    );
    await WorktreeService.instance.addWorktree(
      repoPath,
      worktreePath,
      branchName,
      createNewBranch: true,
    );
    _branchControllers[repoPath]?.clear();
    setState(() => _showAddBranch[repoPath] = false);
    await _loadWorktrees();
  }

  @override
  void dispose() {
    for (final c in _branchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return BlocBuilder<TerminalCubit, TerminalState>(
      builder: (context, termState) {
        final sessions = termState is TerminalLoaded
            ? termState.allSessions
                .where((s) => s.workspaceId == widget.workspace.id)
                .toList()
            : <AgentSession>[];

        final paths = widget.workspace.paths;
        return Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...paths.asMap().entries.map((e) {
                final isLast = e.key == paths.length - 1;
                return _RepoTree(
                  repoPath: e.value,
                  worktrees: _worktrees[e.value] ?? [],
                  sessions: sessions,
                  isLast: isLast && sessions.isEmpty,
                  showAddBranch: _showAddBranch[e.value] ?? false,
                  branchController: _branchControllers.putIfAbsent(
                    e.value,
                    TextEditingController.new,
                  ),
                  onToggleAddBranch: () => setState(
                    () => _showAddBranch[e.value] =
                        !(_showAddBranch[e.value] ?? false),
                  ),
                  onAddBranch: (branch) => _addWorktree(e.value, branch),
                );
              }),
              _SessionsSection(
                workspace: widget.workspace,
                sessions: sessions,
                worktrees: _worktrees,
                onRefresh: _loadWorktrees,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RepoTree extends StatelessWidget {
  const _RepoTree({
    required this.repoPath,
    required this.worktrees,
    required this.sessions,
    required this.isLast,
    required this.showAddBranch,
    required this.branchController,
    required this.onToggleAddBranch,
    required this.onAddBranch,
  });

  final String repoPath;
  final List<WorktreeEntry> worktrees;
  final List<AgentSession> sessions;
  final bool isLast;
  final bool showAddBranch;
  final TextEditingController branchController;
  final VoidCallback onToggleAddBranch;
  final ValueChanged<String> onAddBranch;

  @override
  Widget build(BuildContext context) {
    final repoName = p.basename(repoPath);
    final children = <Widget>[];

    for (var i = 0; i < worktrees.length; i++) {
      final wt = worktrees[i];
      final isLastChild = i == worktrees.length - 1 && !showAddBranch;
      final hasSession = sessions.any((s) =>
          s.worktreeContexts != null &&
          s.worktreeContexts![repoPath] == wt.path);
      children.add(
        _BranchRow(
          entry: wt,
          isLast: isLastChild,
          hasSession: hasSession,
        ),
      );
    }

    if (showAddBranch) {
      children.add(_AddBranchField(
        controller: branchController,
        onSubmit: onAddBranch,
        onCancel: onToggleAddBranch,
      ));
    } else {
      children.add(_AddBranchButton(onTap: onToggleAddBranch));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              const Text('📁 ', style: TextStyle(fontSize: 11)),
              Expanded(
                child: Text(
                  repoName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.entry,
    required this.isLast,
    required this.hasSession,
  });

  final WorktreeEntry entry;
  final bool isLast;
  final bool hasSession;

  Color _dotColor() {
    if (entry.isMain) return AppColors.neonGreen;
    if (hasSession) return AppColors.neonBlue;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final branch = entry.branch ?? entry.commit ?? '(detached)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 1, 8, 1),
      child: Row(
        children: [
          Text(
            isLast ? '└─ ' : '├─ ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dotColor(),
            ),
          ),
          Expanded(
            child: Text(
              branch,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBranchButton extends StatelessWidget {
  const _AddBranchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 1, 8, 1),
        child: Row(
          children: [
            const Text('└─ ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const Flexible(
              child: Text(
                '＋ new branch...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBranchField extends StatelessWidget {
  const _AddBranchField({
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 2, 8, 2),
      child: Row(
        children: [
          const Text('└─ ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'branch name',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                filled: true,
                fillColor: colors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              onSubmitted: (v) {
                final branch = v.trim();
                if (branch.isNotEmpty) onSubmit(branch);
              },
              onEditingComplete: () {},
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, size: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SessionsSection extends StatelessWidget {
  const _SessionsSection({
    required this.workspace,
    required this.sessions,
    required this.worktrees,
    required this.onRefresh,
  });

  final Workspace workspace;
  final List<AgentSession> sessions;
  final Map<String, List<WorktreeEntry>> worktrees;
  final VoidCallback onRefresh;

  String _sessionLabel(AgentSession s) {
    if (s.customName?.isNotEmpty == true) return s.customName!;
    if (s.worktreeContexts != null && s.worktreeContexts!.isNotEmpty) {
      final branch = s.worktreeContexts!.values.first;
      final branchName = p.basename(branch);
      return '${s.type.displayName} · $branchName';
    }
    return s.type.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Text(
            'Agent Sessions',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...sessions.asMap().entries.map((e) {
          final isLast = e.key == sessions.length - 1;
          return _SessionRow(
            session: e.value,
            label: _sessionLabel(e.value),
            isLast: isLast,
          );
        }),
        _NewSessionButton(workspace: workspace, worktrees: worktrees, onSpawned: onRefresh),
      ],
    );
  }
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    required this.session,
    required this.label,
    required this.isLast,
  });

  final AgentSession session;
  final String label;
  final bool isLast;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _hovered = false;

  Color _statusColor() {
    switch (widget.session.status) {
      case AgentStatus.live:
        return AppColors.neonGreen;
      case AgentStatus.idle:
        return AppColors.textMuted;
      case AgentStatus.error:
        return AppColors.neonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? colors.surfaceHighlight : null,
        padding: const EdgeInsets.fromLTRB(28, 1, 8, 1),
        child: Row(
          children: [
            Text(
              widget.isLast ? '└─ ' : '├─ ',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor(),
              ),
            ),
            Text(
              widget.session.type.iconLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hovered)
              GestureDetector(
                onTap: () =>
                    context.read<TerminalCubit>().closeSession(widget.session.id),
                child: const Icon(Icons.close, size: 12, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewSessionButton extends StatelessWidget {
  const _NewSessionButton({
    required this.workspace,
    required this.worktrees,
    required this.onSpawned,
  });

  final Workspace workspace;
  final Map<String, List<WorktreeEntry>> worktrees;
  final VoidCallback onSpawned;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 2, 8, 4),
        child: Row(
          children: [
            const Text('└─ ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const Flexible(
              child: Text(
                '＋ New Agent Session',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TerminalCubit>(),
        child: _NewAgentSessionDialog(
          workspace: workspace,
          worktrees: worktrees,
          onSpawned: onSpawned,
        ),
      ),
    );
  }
}

class _NewAgentSessionDialog extends StatefulWidget {
  const _NewAgentSessionDialog({
    required this.workspace,
    required this.worktrees,
    required this.onSpawned,
  });

  final Workspace workspace;
  final Map<String, List<WorktreeEntry>> worktrees;
  final VoidCallback onSpawned;

  @override
  State<_NewAgentSessionDialog> createState() => _NewAgentSessionDialogState();
}

class _NewAgentSessionDialogState extends State<_NewAgentSessionDialog> {
  static const _kCreateNew = '__create_new__';
  static const _kBranchPrefix = '__branch__:';

  AgentType _agentType = AgentType.copilot;
  late Map<String, String> _selectedPaths;
  final _nameController = TextEditingController();

  /// repoPath → all local branches (from `git branch --list`)
  Map<String, List<String>> _allBranches = {};

  /// repoPath → whether the "new branch" text field is currently visible
  final Map<String, bool> _showingNewBranch = {};

  /// repoPath → controller for new-branch name input
  final Map<String, TextEditingController> _newBranchCtrls = {};

  /// repoPath → inline error message
  final Map<String, String?> _errors = {};

  /// repoPath → busy (creating worktree)
  final Map<String, bool> _busy = {};

  @override
  void initState() {
    super.initState();
    _selectedPaths = {
      for (final entry in widget.worktrees.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.first.path,
    };
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final results = <String, List<String>>{};
    for (final repoPath in widget.worktrees.keys) {
      results[repoPath] = await WorktreeService.instance.listBranches(repoPath);
    }
    if (mounted) setState(() => _allBranches = results);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _newBranchCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Branches that are already checked out as worktrees for [repoPath].
  Set<String> _checkedOutBranches(String repoPath) {
    return widget.worktrees[repoPath]
            ?.map((wt) => wt.branch)
            .whereType<String>()
            .toSet() ??
        {};
  }

  /// Creates a worktree for an existing [branch] in [repoPath], selects it.
  Future<void> _checkoutBranch(String repoPath, String branch) async {
    setState(() {
      _busy[repoPath] = true;
      _errors[repoPath] = null;
    });
    final worktreePath = p.join(
      p.dirname(repoPath),
      '${p.basename(repoPath)}__${branch.replaceAll('/', '-')}',
    );
    final err = await WorktreeService.instance.addWorktree(
      repoPath,
      worktreePath,
      branch,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy[repoPath] = false;
        _errors[repoPath] = err;
        // Revert to first available worktree
        final first = widget.worktrees[repoPath]?.first;
        if (first != null) _selectedPaths[repoPath] = first.path;
      });
    } else {
      setState(() {
        _busy[repoPath] = false;
        _selectedPaths[repoPath] = worktreePath;
      });
    }
  }

  /// Creates a NEW branch + worktree from HEAD.
  Future<void> _createBranch(String repoPath, String newBranch) async {
    if (newBranch.isEmpty) return;
    setState(() {
      _busy[repoPath] = true;
      _errors[repoPath] = null;
    });
    final worktreePath = p.join(
      p.dirname(repoPath),
      '${p.basename(repoPath)}__${newBranch.replaceAll('/', '-')}',
    );
    final err = await WorktreeService.instance.addWorktree(
      repoPath,
      worktreePath,
      newBranch,
      createNewBranch: true,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy[repoPath] = false;
        _errors[repoPath] = err;
      });
    } else {
      _newBranchCtrls[repoPath]?.clear();
      setState(() {
        _busy[repoPath] = false;
        _showingNewBranch[repoPath] = false;
        _selectedPaths[repoPath] = worktreePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Agent Session',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agent Type',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              DropdownButton<AgentType>(
                value: _agentType,
                dropdownColor: colors.surfaceHighlight,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                underline: Container(height: 1, color: colors.border),
                isExpanded: true,
                items: AgentType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text('${t.iconLabel}  ${t.displayName}'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _agentType = v);
                },
              ),
              ...widget.worktrees.entries.map((e) => _buildRepoSection(e.key, e.value, colors)),
              const SizedBox(height: 12),
              const Text(
                'Session Name (optional)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Leave empty to use agent name',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true,
                  fillColor: colors.surfaceHighlight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: AppColors.textHighlight,
                    ),
                    onPressed: _anyBusy ? null : _confirm,
                    child: const Text('Start', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _anyBusy => _busy.values.any((v) => v);

  Widget _buildRepoSection(
    String repoPath,
    List<WorktreeEntry> worktrees,
    AppColorScheme colors,
  ) {
    if (worktrees.isEmpty) return const SizedBox.shrink();

    final repoName = p.basename(repoPath);
    final checkedOut = _checkedOutBranches(repoPath);
    final allBranches = _allBranches[repoPath] ?? [];
    final otherBranches = allBranches.where((b) => !checkedOut.contains(b)).toList();
    final isBusy = _busy[repoPath] ?? false;
    final showNewField = _showingNewBranch[repoPath] ?? false;
    final error = _errors[repoPath];

    final newBranchCtrl = _newBranchCtrls.putIfAbsent(
      repoPath,
      () => TextEditingController(),
    );

    // Build dropdown items
    final items = <DropdownMenuItem<String>>[];

    // --- Active worktrees ---
    for (final wt in worktrees) {
      final label = wt.branch ?? wt.commit ?? '(detached)';
      items.add(DropdownMenuItem(
        value: wt.path,
        child: Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 11, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ));
    }

    // --- Other branches (not yet worktrees) ---
    if (otherBranches.isNotEmpty) {
      // Section header (disabled item used as label)
      items.add(DropdownMenuItem(
        enabled: false,
        value: null,
        child: Divider(color: colors.border, height: 1),
      ));
      for (final branch in otherBranches) {
        items.add(DropdownMenuItem(
          value: '$_kBranchPrefix$branch',
          child: Row(
            children: [
              Icon(Icons.call_split, size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(branch, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ));
      }
    }

    // --- Create new branch ---
    items.add(DropdownMenuItem(
      enabled: otherBranches.isNotEmpty || worktrees.isNotEmpty,
      value: null,
      child: Divider(color: colors.border, height: 1),
    ));
    items.add(DropdownMenuItem(
      value: _kCreateNew,
      child: Row(
        children: [
          Icon(Icons.add, size: 12, color: colors.primary),
          const SizedBox(width: 6),
          Text('New branch…', style: TextStyle(color: colors.primary, fontSize: 12)),
        ],
      ),
    ));

    final currentValue = _selectedPaths[repoPath];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          repoName,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        if (isBusy)
          SizedBox(
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Creating worktree…',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          DropdownButton<String>(
            value: currentValue,
            dropdownColor: colors.surfaceHighlight,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            underline: Container(height: 1, color: colors.border),
            isExpanded: true,
            items: items,
            onChanged: (v) {
              if (v == null) return;
              if (v == _kCreateNew) {
                setState(() {
                  _showingNewBranch[repoPath] = true;
                  _errors[repoPath] = null;
                });
              } else if (v.startsWith(_kBranchPrefix)) {
                final branch = v.substring(_kBranchPrefix.length);
                _checkoutBranch(repoPath, branch);
              } else {
                setState(() => _selectedPaths[repoPath] = v);
              }
            },
          ),
        // New-branch inline field
        if (showNewField && !isBusy) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newBranchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'branch-name',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: colors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                  onSubmitted: (v) => _createBranch(repoPath, v.trim()),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.check, size: 16, color: colors.primary),
                tooltip: 'Create branch',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _createBranch(repoPath, newBranchCtrl.text.trim()),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                tooltip: 'Cancel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => setState(() {
                  _showingNewBranch[repoPath] = false;
                  _errors[repoPath] = null;
                  newBranchCtrl.clear();
                }),
              ),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: Colors.red, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  void _confirm() {
    final cubit = context.read<TerminalCubit>();
    final name = _nameController.text.trim();
    final sessionId = '${_agentType.name}_${DateTime.now().millisecondsSinceEpoch}';
    cubit.spawnSession(
      type: _agentType,
      workspacePath: widget.workspace.workspaceDir,
      workspaceId: widget.workspace.id,
      savedSessionId: sessionId,
      worktreeContexts: Map.from(_selectedPaths),
    );
    if (name.isNotEmpty) {
      cubit.renameSession(sessionId, name);
    }
    Navigator.of(context).pop();
    widget.onSpawned();
  }
}
