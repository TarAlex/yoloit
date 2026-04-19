import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';

/// Mindmap diff card — shows only the git-changes / diff viewer.
class DiffNode extends StatelessWidget {
  const DiffNode({super.key, required this.data});
  final DiffNodeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D12),
        border: Border.all(color: const Color(0x707C6BFF), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x90000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1218),
                border: Border(bottom: BorderSide(color: Color(0xFF1E2330))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, size: 12, color: Color(0xFF7C6BFF)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      data.repoName != null ? 'Diff · ${data.repoName}' : 'Git Changes · Diff',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: ReviewDiffPanel()),
          ],
        ),
      ),
    );
  }
}
