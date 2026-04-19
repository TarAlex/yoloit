import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation files card — identical visuals to macOS FilesNode.
class FilesCard extends StatelessWidget {
  const FilesCard({super.key, required this.props, this.onFileSelect});
  final FilesCardProps props;
  final void Function(String path)? onFileSelect;

  @override
  Widget build(BuildContext context) {
    final files = props.files.take(8).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12151C),
        border: Border.all(color: const Color(0x596B7898), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x70000000), blurRadius: 14, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF181C26),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(9)),
              border:
                  Border(bottom: BorderSide(color: Color(0xFF1E2330))),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 12, color: Color(0xFF6B7898)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('FILES CHANGED',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.08,
                          color: Color(0xFF6B7898))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: const Color(0xFF252B3A),
                      borderRadius: BorderRadius.circular(3)),
                  child: Text('${props.files.length}',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF6B7898))),
                ),
              ],
            ),
          ),
          ...files.map((f) => _FileRow(
                file: f,
                onTap: onFileSelect != null
                    ? () => onFileSelect!(f.path)
                    : null,
              )),
          if (props.files.length > 8)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('+${props.files.length - 8} more',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF44446A))),
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, this.onTap});
  final FileEntry file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (statLabel, statBg, statFg) = switch (file.status.toLowerCase()) {
      'added' || 'a' => (
          'A',
          const Color(0x2634D399),
          const Color(0xFF34D399)
        ),
      'deleted' || 'd' => (
          'D',
          const Color(0x26F87171),
          const Color(0xFFF87171)
        ),
      'renamed' || 'r' => (
          'R',
          const Color(0x2660A5FA),
          const Color(0xFF60A5FA)
        ),
      'untracked' || '?' => (
          '?',
          const Color(0x266B7898),
          const Color(0xFF6B7898)
        ),
      _ => ('M', const Color(0x26FBBF24), const Color(0xFFFBBF24)),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: statBg, borderRadius: BorderRadius.circular(2)),
              child: Text(statLabel,
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: statFg,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.basename(file.path),
                style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Color(0xFFE8E8FF)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (file.addedLines > 0 || file.removedLines > 0)
              Text(
                '+${file.addedLines}/-${file.removedLines}',
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF44446A),
                    fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }
}
