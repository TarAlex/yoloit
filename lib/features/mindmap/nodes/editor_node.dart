import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/features/editor/ui/file_editor_panel.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

/// Mindmap editor card — embeds the full [FileEditorPanel] so all panel
/// functionality (tabs, markdown/SVG/image preview, syntax highlighting,
/// save, close, font scaling, etc.) is available directly in the mindmap.
class EditorNode extends StatefulWidget {
  const EditorNode({super.key, required this.data});
  final EditorNodeData data;

  @override
  State<EditorNode> createState() => _EditorNodeState();
}

class _EditorNodeState extends State<EditorNode> {
  bool _immersive = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D12),
        border: Border.all(
          color: _immersive
              ? const Color(0xFF60A5FA)
              : const Color(0x5960A5FA),
          width: _immersive ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _immersive
                ? const Color(0xCC000000)
                : const Color(0x90000000),
            blurRadius: _immersive ? 32 : 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slim header — hidden in immersive mode.
            if (!_immersive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1218),
                  border: Border(bottom: BorderSide(color: Color(0xFF1E2330))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 12, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        p.basename(widget.data.filePath),
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
                      widget.data.language,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF44446A)),
                    ),
                  ],
                ),
              ),
            // Full editor panel — tabs, previews, save, everything.
            Expanded(
              child: FileEditorPanel(
                immersive: _immersive,
                onToggleImmersive: () => setState(() => _immersive = !_immersive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
