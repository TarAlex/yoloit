import 'package:flutter/material.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation diff card — renders changed files list + optional diff hunks.
class DiffCard extends StatelessWidget {
  const DiffCard({super.key, required this.props, this.onFileTap});
  final DiffCardProps props;
  final void Function(String filePath)? onFileTap;

  @override
  Widget build(BuildContext context) {
    final hasChanges = props.changedFiles.isNotEmpty || props.hunks.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D12),
        border: Border.all(color: const Color(0x707C6BFF), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x90000000), blurRadius: 20, offset: Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1218),
                border:
                    Border(bottom: BorderSide(color: Color(0xFF1E2330))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded,
                      size: 12, color: Color(0xFF7C6BFF)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      props.repoName != null
                          ? 'Diff · ${props.repoName}'
                          : 'Git Changes · Diff',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8E8FF)),
                    ),
                  ),
                  if (props.changedFiles.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x337C6BFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${props.changedFiles.length}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF9B8FFF),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: !hasChanges
                  ? const Center(
                      child: Text('No changes',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF475569))))
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        // Changed files list
                        if (props.changedFiles.isNotEmpty) ...[
                          for (final f in props.changedFiles)
                            _ChangedFileRow(
                              file: f,
                              isSelected: props.selectedFilePath == f.path,
                              onTap: onFileTap != null
                                  ? () => onFileTap!(f.path)
                                  : null,
                            ),
                          if (props.hunks.isNotEmpty)
                            const Divider(
                                color: Color(0xFF1E2330), height: 8),
                        ],
                        // Diff hunks for selected file
                        for (final h in props.hunks) _HunkWidget(hunk: h),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.file,
    this.onTap,
    this.isSelected = false,
  });
  final ChangedFileEntry file;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (file.status) {
      'added' => (const Color(0xFF34D399), 'A'),
      'deleted' => (const Color(0xFFF87171), 'D'),
      'renamed' => (const Color(0xFFFBBF24), 'R'),
      'untracked' => (const Color(0xFF94A3B8), 'U'),
      _ => (const Color(0xFFFBBF24), 'M'),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? const Color(0x1A7C6BFF)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          children: [
            Container(
              width: 14,
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                file.name.isNotEmpty ? file.name : file.path.split('/').last,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? const Color(0xFFE8E8FF)
                        : const Color(0xFFCECEEE),
                    fontFamily: 'monospace'),
              ),
            ),
            if (file.addedLines > 0)
              Text('+${file.addedLines}',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF34D399))),
            if (file.removedLines > 0) ...[
              const SizedBox(width: 3),
              Text('-${file.removedLines}',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFFF87171))),
            ],
          ],
        ),
      ),
    );
  }
}



class _HunkWidget extends StatelessWidget {
  const _HunkWidget({required this.hunk});
  final DiffHunk hunk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFF1A1E2A),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            hunk.header,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: Color(0xFF6B7898),
            ),
          ),
        ),
        for (final line in hunk.lines)
          Container(
            color: switch (line.type) {
              'add' => const Color(0x1434D399),
              'remove' => const Color(0x14F87171),
              _ => Colors.transparent,
            },
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text(
              line.text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: switch (line.type) {
                  'add' => const Color(0xFF34D399),
                  'remove' => const Color(0xFFF87171),
                  _ => const Color(0xFFCECEEE),
                },
                height: 1.4,
              ),
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
      ],
    );
  }
}
