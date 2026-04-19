import 'package:flutter/material.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation diff card — renders diff hunks from snapshot data.
class DiffCard extends StatelessWidget {
  const DiffCard({super.key, required this.props});
  final DiffCardProps props;

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
            Expanded(
              child: props.hunks.isEmpty
                  ? const Center(
                      child: Text('No changes',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF475569))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: props.hunks.length,
                      itemBuilder: (_, i) =>
                          _HunkWidget(hunk: props.hunks[i]),
                    ),
            ),
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
