import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation editor card — shows file content as text with header.
class EditorCard extends StatelessWidget {
  const EditorCard({
    super.key,
    required this.props,
    this.onSwitchTab,
    this.onSave,
    this.onToggleImmersive,
  });
  final EditorCardProps props;
  final void Function(int tabIndex)? onSwitchTab;
  final VoidCallback? onSave;
  final VoidCallback? onToggleImmersive;

  @override
  Widget build(BuildContext context) {
    final lines = props.content.split('\n').take(200).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D12),
        border: Border.all(color: const Color(0x5960A5FA), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x90000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs row (if multiple tabs)
            if (props.tabs.length > 1)
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0D12),
                  border:
                      Border(bottom: BorderSide(color: Color(0xFF1E2330))),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    for (var i = 0; i < props.tabs.length; i++)
                      _TabChip(
                        name: p.basename(props.tabs[i].path),
                        isActive: props.tabs[i].isActive,
                        onTap: () => onSwitchTab?.call(i),
                      ),
                  ],
                ),
              ),
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
                  const Icon(Icons.code,
                      size: 12, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      p.basename(props.filePath),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    props.language,
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFF44446A)),
                  ),
                ],
              ),
            ),
            // File content
            Expanded(
              child: Container(
                color: const Color(0xFF0A0F14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: SelectionArea(
                  child: ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (_, i) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF3A4560),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lines[i],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFFADD8E6),
                              height: 1.5,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.name,
    required this.isActive,
    this.onTap,
  });
  final String name;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A2040) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color:
                  isActive ? const Color(0xFF60A5FA) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: isActive
                  ? const Color(0xFFE8E8FF)
                  : const Color(0xFF6B7898),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
