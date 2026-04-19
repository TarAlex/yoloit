import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';

/// Mindmap file-tree card — shows only the file browser (no diff, no runs).
class FileTreeNode extends StatelessWidget {
  const FileTreeNode({super.key, required this.data});
  final FileTreeNodeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D12),
        border: Border.all(color: const Color(0x7034D399), width: 1.5),
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
                  const Icon(Icons.account_tree_outlined, size: 12, color: Color(0xFF34D399)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      data.repoName != null ? 'Tree · ${data.repoName}' : 'File Tree',
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
            const Expanded(child: ReviewFileTreePanel()),
          ],
        ),
      ),
    );
  }
}
