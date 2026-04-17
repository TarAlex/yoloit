import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/data/worktree_service.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/models/worktree_model.dart';
import 'package:yoloit/features/workspaces/ui/new_agent_session_dialog.dart';

class WorkspaceInlineTree extends StatefulWidget {
  const WorkspaceInlineTree({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<WorkspaceInlineTree> createState() => _WorkspaceInlineTreeState();
}

class _WorkspaceInlineTreeState extends State<WorkspaceInlineTree> {
  /// repoPath → list of worktrees (used for branch name lookups)
  Map<String, List<WorktreeEntry>> _worktrees = {};
  bool _loading = true;

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

  /// Resolves the branch name for [repoPath] given the session's [worktreePath].
  String _branchName(String repoPath, String worktreePath) {
    final wt = _worktrees[repoPath]
        ?.where((w) => w.path == worktreePath)
        .firstOrNull;
    if (wt?.branch != null) return wt!.branch!;
    // Fallback: extract from folder name (reponame__branchname convention)
    final folder = p.basename(worktreePath);
    final prefix = '${p.basename(repoPath)}__';
    return folder.startsWith(prefix) ? folder.substring(prefix.length) : folder;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return BlocBuilder<TerminalCubit, TerminalState>(
      builder: (context, termState) {
        final sessions = termState is TerminalLoaded
            ? termState.sessions
                .where((s) => s.workspaceId == widget.workspace.id)
                .toList()
            : <AgentSession>[];
        final activeId = termState is TerminalLoaded
            ? termState.activeSession?.id
            : null;

        return Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sessions.map((session) => _SessionCard(
                    session: session,
                    workspace: widget.workspace,
                    worktrees: _worktrees,
                    branchNameResolver: _branchName,
                    isActive: session.id == activeId,
                    onActivate: () => context
                        .read<TerminalCubit>()
                        .setActiveSessionById(session.id),
                    onClose: () =>
                        context.read<TerminalCubit>().closeSession(session.id),
                  )),
              _NewSessionButton(
                workspace: widget.workspace,
                worktrees: _worktrees,
                onSpawned: _loadWorktrees,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.session,
    required this.workspace,
    required this.worktrees,
    required this.branchNameResolver,
    required this.isActive,
    required this.onActivate,
    required this.onClose,
  });

  final AgentSession session;
  final Workspace workspace;
  final Map<String, List<WorktreeEntry>> worktrees;
  final String Function(String repoPath, String worktreePath) branchNameResolver;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClose;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _hovered = false;
  bool _expanded = true;

  Color _statusColor() {
    switch (widget.session.status) {
      case AgentStatus.live:
        return AppColors.neonGreen;
      case AgentStatus.idle:
        return AppColors.neonBlue;
      case AgentStatus.error:
        return AppColors.neonRed;
    }
  }

  String _label() {
    if (widget.session.customName?.isNotEmpty == true) {
      return widget.session.customName!;
    }
    // Show agent name + primary non-main branch if any
    final contexts = widget.session.worktreeContexts;
    if (contexts != null && contexts.isNotEmpty) {
      final repoPath = contexts.keys.first;
      final branch = widget.branchNameResolver(repoPath, contexts[repoPath]!);
      return '${widget.session.type.displayName} · $branch';
    }
    return widget.session.type.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isActive = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session header row
          GestureDetector(
            onTap: () {
              widget.onActivate();
              setState(() => _expanded = true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: isActive
                  ? colors.primary.withAlpha(25)
                  : _hovered
                      ? colors.surfaceHighlight
                      : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: [
                  // Expand/collapse chevron
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Status dot
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor(),
                    ),
                  ),
                  // Agent icon
                  Text(
                    widget.session.type.iconLabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  // Session label
                  Expanded(
                    child: Text(
                      _label(),
                      style: TextStyle(
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Close button on hover
                  if (_hovered)
                    GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Repo/branch rows (collapsible)
          if (_expanded) _buildRepoBranches(colors),
        ],
      ),
    );
  }

  Widget _buildRepoBranches(AppColorScheme colors) {
    final contexts = widget.session.worktreeContexts;
    final paths = widget.workspace.paths;
    final rows = <Widget>[];

    for (var i = 0; i < paths.length; i++) {
      final repoPath = paths[i];
      final isLast = i == paths.length - 1;
      final String branch;
      if (contexts != null && contexts.containsKey(repoPath)) {
        branch = widget.branchNameResolver(repoPath, contexts[repoPath]!);
      } else {
        // Fallback to main worktree branch
        final mainWt = widget.worktrees[repoPath]
            ?.where((w) => w.isMain)
            .firstOrNull;
        branch = mainWt?.branch ?? 'main';
      }
      rows.add(_SessionRepoBranchRow(
        repoPath: repoPath,
        branch: branch,
        isLast: isLast,
      ));
    }

    return Column(children: rows);
  }
}

// ── Repo+branch row inside a session card ─────────────────────────────────

class _SessionRepoBranchRow extends StatelessWidget {
  const _SessionRepoBranchRow({
    required this.repoPath,
    required this.branch,
    required this.isLast,
  });

  final String repoPath;
  final String branch;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final repoName = p.basename(repoPath);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 1, 8, 1),
      child: Row(
        children: [
          Text(
            isLast ? '└─ ' : '├─ ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          Icon(Icons.folder_open, size: 11, color: AppColors.neonBlue.withAlpha(160)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              repoName,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.neonBlue.withAlpha(60)),
            ),
            child: Text(
              branch,
              style: const TextStyle(
                color: AppColors.neonBlue,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New Session button ────────────────────────────────────────────────────

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
      onTap: () => showNewAgentSessionDialog(
        context,
        workspace: workspace,
        worktrees: worktrees,
        onSpawned: onSpawned,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 8, 4),
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
}
