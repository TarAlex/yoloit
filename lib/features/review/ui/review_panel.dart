import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';

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
    return Container(
      color: AppColors.surface,
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

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _ReviewHeader(state: state),
          Expanded(
            flex: 2,
            child: _FileTreeSection(state: state),
          ),
          const Divider(height: 1),
          if (state.selectedFilePath != null)
            Expanded(
              flex: 3,
              child: _ContentSection(state: state),
            )
          else
            Expanded(
              flex: 3,
              child: _ChangedFilesSection(state: state),
            ),
          if (state.prStatus != null) _PrStatusSection(pr: state.prStatus!),
        ],
      ),
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
                  ? AppColors.primary.withAlpha(30)
                  : _hovering
                      ? AppColors.surfaceHighlight
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
                  Icon(
                    node.isDirectory
                        ? (node.isExpanded ? Icons.folder_open : Icons.folder)
                        : _fileIcon(node.name),
                    size: 12,
                    color: node.isDirectory
                        ? AppColors.neonBlue.withAlpha(180)
                        : node.isModified
                            ? AppColors.neonOrange
                            : AppColors.textSecondary,
                  ),
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

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' => Icons.code,
      'yaml' || 'yml' || 'json' => Icons.data_object,
      'md' || 'markdown' => Icons.description_outlined,
      'png' || 'jpg' || 'svg' || 'gif' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // View mode toggle
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (state.selectedFilePath != null)
                Expanded(
                  child: Text(
                    state.selectedFilePath!.split('/').last,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              _ViewModeToggle(
                currentMode: state.viewMode,
                onChanged: (mode) => context.read<ReviewCubit>().setViewMode(mode),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final path = state.selectedFilePath;
                  if (path != null) {
                    context.read<ReviewCubit>().stageFile(path.split('/').last);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.primary.withAlpha(80)),
                  ),
                  child: Text(
                    'Stage Changes',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.viewMode == ReviewViewMode.diff
              ? _DiffViewer(state: state)
              : _FileViewer(state: state),
        ),
      ],
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.currentMode, required this.onChanged});
  final ReviewViewMode currentMode;
  final ValueChanged<ReviewViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: 'Diff',
            isActive: currentMode == ReviewViewMode.diff,
            onTap: () => onChanged(ReviewViewMode.diff),
          ),
          Container(width: 1, height: 16, color: AppColors.border),
          _ToggleButton(
            label: 'File',
            isActive: currentMode == ReviewViewMode.file,
            onTap: () => onChanged(ReviewViewMode.file),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primaryLight : AppColors.textMuted,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _DiffViewer extends StatelessWidget {
  const _DiffViewer({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingDiff) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.diffHunks.isEmpty) {
      return const Center(
        child: Text(
          'No changes',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: state.diffHunks.length,
      itemBuilder: (context, i) {
        final hunk = state.diffHunks[i];
        return _DiffHunkWidget(hunk: hunk);
      },
    );
  }
}

class _DiffHunkWidget extends StatelessWidget {
  const _DiffHunkWidget({required this.hunk});
  final DiffHunk hunk;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
            child: Text(
              hunk.header,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          ...hunk.lines.where((l) => l.type != DiffLineType.header).map(
                (line) => _DiffLineWidget(line: line),
              ),
        ],
      ),
    );
  }
}

class _DiffLineWidget extends StatelessWidget {
  const _DiffLineWidget({required this.line});
  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    String prefix;

    switch (line.type) {
      case DiffLineType.add:
        bg = AppColors.diffAddBg;
        textColor = AppColors.diffAddText;
        prefix = '+';
      case DiffLineType.remove:
        bg = AppColors.diffRemoveBg;
        textColor = AppColors.diffRemoveText;
        prefix = '-';
      default:
        bg = Colors.transparent;
        textColor = AppColors.textSecondary;
        prefix = ' ';
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${line.oldLineNum ?? ""}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${line.newLineNum ?? ""}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            prefix,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line.content,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileViewer extends StatelessWidget {
  const _FileViewer({required this.state});
  final ReviewLoaded state;

  // Dark theme color map for syntax tokens
  static const _tokenColors = <String, Color>{
    'keyword': Color(0xFFC678DD),
    'built_in': Color(0xFFE5C07B),
    'type': Color(0xFFE5C07B),
    'literal': Color(0xFF56B6C2),
    'number': Color(0xFFD19A66),
    'regexp': Color(0xFF98C379),
    'string': Color(0xFF98C379),
    'subst': Color(0xFFABB2BF),
    'symbol': Color(0xFF56B6C2),
    'class': Color(0xFFE5C07B),
    'function': Color(0xFF61AFEF),
    'title': Color(0xFF61AFEF),
    'params': Color(0xFFABB2BF),
    'comment': Color(0xFF5C6370),
    'doctag': Color(0xFF5C6370),
    'meta': Color(0xFFABB2BF),
    'meta-keyword': Color(0xFFC678DD),
    'meta-string': Color(0xFF98C379),
    'section': Color(0xFF61AFEF),
    'tag': Color(0xFFE06C75),
    'name': Color(0xFFE06C75),
    'attr': Color(0xFFD19A66),
    'attribute': Color(0xFF98C379),
    'variable': Color(0xFFE06C75),
    'bullet': Color(0xFF56B6C2),
    'code': Color(0xFF98C379),
    'emphasis': Color(0xFFE06C75),
    'strong': Color(0xFFE5C07B),
    'formula': Color(0xFF56B6C2),
    'link': Color(0xFF61AFEF),
    'quote': Color(0xFF5C6370),
    'selector-tag': Color(0xFFE06C75),
    'selector-id': Color(0xFFE06C75),
    'selector-class': Color(0xFFD19A66),
    'template-variable': Color(0xFFE06C75),
    'template-tag': Color(0xFFC678DD),
    'addition': Color(0xFF98C379),
    'deletion': Color(0xFFE06C75),
  };

  static const _defaultColor = Color(0xFFABB2BF);
  static const _baseStyle = TextStyle(
    fontSize: 11,
    fontFamily: 'monospace',
    height: 1.5,
  );

  /// Detect language from file extension
  static String? _detectLanguage(String? path) {
    if (path == null) return null;
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'dart': 'dart', 'py': 'python', 'js': 'javascript',
      'ts': 'typescript', 'tsx': 'typescript', 'jsx': 'javascript',
      'swift': 'swift', 'kt': 'kotlin', 'java': 'java',
      'go': 'go', 'rs': 'rust', 'cpp': 'cpp', 'c': 'c', 'h': 'cpp',
      'cs': 'csharp', 'rb': 'ruby', 'php': 'php', 'sh': 'bash',
      'yaml': 'yaml', 'yml': 'yaml', 'json': 'json',
      'md': 'markdown', 'html': 'html', 'css': 'css', 'scss': 'scss',
      'xml': 'xml', 'sql': 'sql', 'dockerfile': 'dockerfile',
    };
    return map[ext];
  }

  List<TextSpan> _buildSpans(List<Node> nodes, Color parentColor) {
    return nodes.map((node) {
      final color = node.className != null
          ? (_tokenColors[node.className!] ?? parentColor)
          : parentColor;
      if (node.value != null) {
        return TextSpan(
          text: node.value,
          style: _baseStyle.copyWith(color: color),
        );
      }
      if (node.children != null) {
        return TextSpan(children: _buildSpans(node.children!, color));
      }
      return const TextSpan();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingFile) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final content = state.fileContent;
    if (content == null) {
      return const Center(
        child: Text(
          'Select a file to view',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    final lang = _detectLanguage(state.selectedFilePath);
    Widget body;
    if (lang != null) {
      try {
        final parsed = highlight.parse(content, language: lang);
        final spans = parsed.nodes != null
            ? _buildSpans(parsed.nodes!, _defaultColor)
            : [TextSpan(text: content, style: _baseStyle.copyWith(color: _defaultColor))];
        body = RichText(
          text: TextSpan(children: spans),
          textScaler: TextScaler.noScaling,
        );
      } catch (_) {
        body = Text(content, style: _baseStyle.copyWith(color: _defaultColor));
      }
    } else {
      body = Text(content, style: _baseStyle.copyWith(color: _defaultColor));
    }

    return Container(
      color: const Color(0xFF1E2127), // one-dark background
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: body,
      ),
    );
  }
}

class _ChangedFilesSection extends StatelessWidget {
  const _ChangedFilesSection({required this.state});
  final ReviewLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.changedFiles.isEmpty) {
      return const Center(
        child: Text(
          'No changed files',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              const Text(
                'Changed Files',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${state.changedFiles.length}',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: state.changedFiles.length,
            itemBuilder: (context, i) {
              final file = state.changedFiles[i];
              return _ChangedFileTile(file: file);
            },
          ),
        ),
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
          // Will need full path - for now use relative
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: _hovering ? AppColors.surfaceHighlight : Colors.transparent,
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
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
          const SizedBox(height: 6),
          Row(
            children: [
              _PrButton(
                label: 'Create PR',
                color: AppColors.primary,
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
