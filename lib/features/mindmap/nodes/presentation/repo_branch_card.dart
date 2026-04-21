import 'package:flutter/material.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation repo card — identical visuals to macOS RepoNode.
class RepoCard extends StatelessWidget {
  const RepoCard({super.key, required this.props});
  final RepoCardProps props;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF181C26),
        border: Border.all(color: const Color(0x5922D3EE), width: 1.5),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0x0F22D3EE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_rounded,
                    size: 12, color: Color(0xFF22D3EE)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    props.repoName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.call_split,
                    size: 11, color: Color(0xFF22D3EE)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    props.branch,
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Color(0xFF22D3EE)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Presentation branch card — identical visuals to macOS BranchNode.
class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.props});
  final BranchCardProps props;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181C26),
        border: Border.all(color: const Color(0x667C6BFF), width: 1.5),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0x147C6BFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.call_split,
                    size: 11, color: Color(0xFFA99BFF)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    props.branch,
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA99BFF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(props.repoName,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF6B7898))),
                if (props.commitHash.isNotEmpty)
                  Text(
                    props.commitHash.length > 7
                        ? props.commitHash.substring(0, 7)
                        : props.commitHash,
                    style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Color(0xFF44446A)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
