import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/utils/file_type_utils.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';
import 'package:yoloit/features/runs/ui/run_panel.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';

class ReviewPanel extends StatelessWidget {
  const ReviewPanel({super.key});

  @override
  Widget build(BuildContext context) {

    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, state) {
        if (state is ReviewLoaded) {
          return _ReviewContent(state: state);
        }
        return _EmptyReview();
      },
    );
  }
}

class _EmptyReview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 32, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Changes & Review',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Open a workspace to see file changes',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewContent extends StatefulWidget {
  const _ReviewContent({required this.state});
  final ReviewLoaded state;

  @override
  State<_ReviewContent> createState() => _ReviewContentState();
}

class _ReviewContentState extends State<_ReviewContent> {
  bool _runCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          _ReviewHeader(state: widget.state),
          Expanded(
            child: _FileTreeSection(state: widget.state),
          ),
          if (widget.state.prStatus != null) _PrStatusSection(pr: widget.state.prStatus!),
          // ── Run panel (collapsible) ───────────────────────────────────────
          _CollapsibleRunPanel(
            collapsed: _runCollapsed,
            onToggle: () => setState(() => _runCollapsed = !_runCollapsed),
          ),
        ],
      ),
    );
  }
}

/// Collapsible Run panel shown at the bottom of the Review panel.
class _CollapsibleRunPanel extends StatelessWidget {
  const _CollapsibleRunPanel({required this.collapsed, required this.onToggle});
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header strip (always visible)
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'Run',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: collapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_less, size: 14, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        // Body (collapses)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 220, child: RunPanel()),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Changes & Review',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.read<ReviewCubit>().refresh(),
            child: const Icon(Icons.refresh, size: 14, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _FileTreeSection extends StatelessWidget {
  const _FileTreeSection({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: const Row(
            children: [
              Text(
                'File Tree',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Spacer(),
              Icon(Icons.unfold_more, size: 12, color: AppColors.textMuted),
            ],
          ),
        ),
        Expanded(
          child: state.fileTree.isEmpty
              ? const Center(
                  child: Text(
                    'No files',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: state.fileTree.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, i) {
                    return _FileTreeNodeWidget(
                      node: state.fileTree[i],
                      depth: 0,
                      selectedPath: state.selectedFilePath,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FileTreeNodeWidget extends StatefulWidget {
  const _FileTreeNodeWidget({
    required this.node,
    required this.depth,
    this.selectedPath,
  });

  final FileTreeNode node;
  final int depth;
  final String? selectedPath;

  @override
  State<_FileTreeNodeWidget> createState() => _FileTreeNodeWidgetState();
}

class _FileTreeNodeWidgetState extends State<_FileTreeNodeWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final node = widget.node;
    final isSelected = node.path == widget.selectedPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (node.isDirectory) {
                context.read<ReviewCubit>().toggleNode(node.path);
              } else {
                context.read<ReviewCubit>().selectFile(node.path);
                // Open file in editor panel
                try {
                  context.read<FileEditorCubit>().openFile(node.path);
                } catch (_) {
                  // FileEditorCubit not in scope — ignore
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: EdgeInsets.only(
                left: 12.0 + widget.depth * 12.0,
                right: 8,
                top: 3,
                bottom: 3,
              ),
              color: isSelected
                  ? colors.primary.withAlpha(30)
                  : _hovering
                      ? colors.surfaceHighlight
                      : Colors.transparent,
              child: Row(
                children: [
                  if (node.isDirectory)
                    Icon(
                      node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 12,
                      color: AppColors.textMuted,
                    )
                  else
                    const SizedBox(width: 12),
                  const SizedBox(width: 4),
                  Builder(builder: (_) {
                    if (node.isDirectory) {
                      return Icon(
                        node.isExpanded ? Icons.folder_open : Icons.folder,
                        size: 12,
                        color: AppColors.neonBlue.withAlpha(180),
                      );
                    }
                    final ft = FileTypeUtils.forPath(node.path.isNotEmpty ? node.path : node.name);
                    return Icon(
                      ft.icon,
                      size: 12,
                      color: node.isModified ? AppColors.neonOrange : ft.color,
                    );
                  }),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        color: node.isModified
                            ? AppColors.neonOrange
                            : isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (node.isModified)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.neonOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (node.isDirectory && node.isExpanded)
          ...node.children.map((child) => _FileTreeNodeWidget(
                node: child,
                depth: widget.depth + 1,
                selectedPath: widget.selectedPath,
              )),
      ],
    );
  }
}

class _ChangedFileTile extends StatefulWidget {
  const _ChangedFileTile({required this.file});
  final FileChange file;

  @override
  State<_ChangedFileTile> createState() => _ChangedFileTileState();
}

class _ChangedFileTileState extends State<_ChangedFileTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final file = widget.file;
    final statusColor = switch (file.status) {
      FileChangeStatus.added => AppColors.neonGreen,
      FileChangeStatus.deleted => AppColors.neonRed,
      FileChangeStatus.modified => AppColors.neonOrange,
      _ => AppColors.textSecondary,
    };
    final statusLabel = switch (file.status) {
      FileChangeStatus.added => 'A',
      FileChangeStatus.deleted => 'D',
      FileChangeStatus.modified => 'M',
      FileChangeStatus.renamed => 'R',
      FileChangeStatus.untracked => 'U',
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () {
          final wsState = context.read<WorkspaceCubit>().state;
          if (wsState is WorkspaceLoaded) {
            final workspace = wsState.activeWorkspace;
            if (workspace != null) {
              try {
                context.read<FileEditorCubit>().openDiff(
                  widget.file.path,
                  workspace.path,
                );
              } catch (_) {}
            }
          }
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 100),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: _hovering ? colors.surfaceHighlight : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Center(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.path,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (file.isStaged)
                const Icon(Icons.check_circle_outline, size: 10, color: AppColors.neonGreen),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrStatusSection extends StatelessWidget {
  const _PrStatusSection({required this.pr});
  final PrStatus pr;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'PR Status',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.more_horiz, size: 12, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PR #${pr.prNumber}: ${pr.title}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Status: ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                pr.status,
                style: const TextStyle(color: AppColors.neonOrange, fontSize: 10),
              ),
              Text(
                '  ·  Reviewers: ${pr.reviewers} Pending',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              _PrButton(
                label: 'Create PR',
                color: colors.primary,
                onTap: () {},
              ),
              const SizedBox(width: 4),
              _PrButton(
                label: 'Merge',
                color: AppColors.neonGreen,
                onTap: () {},
              ),
              const SizedBox(width: 4),
              _PrButton(
                label: 'Close',
                color: AppColors.neonRed,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrButton extends StatelessWidget {
  const _PrButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
