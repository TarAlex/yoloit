import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';

class WorkspaceNode extends StatelessWidget {
  const WorkspaceNode({super.key, required this.data});
  final WorkspaceNodeData data;

  static const _borderColor = Color(0x8060A5FA);
  static const _bgGrad = [Color(0xFF181E2E), Color(0xFF141826)];

  @override
  Widget build(BuildContext context) {
    final ws = data.workspace;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: _bgGrad,
        ),
        border: Border.all(color: _borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1460A5FA), blurRadius: 24, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ws.color ?? const Color(0xFF60A5FA),
                  boxShadow: [BoxShadow(color: (ws.color ?? const Color(0xFF60A5FA)).withAlpha(160), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ws.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE8E8FF)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ws.paths.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${ws.paths.length} ${ws.paths.length == 1 ? "repo" : "repos"}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7898)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _WsActionBtn(
                icon: Icons.create_new_folder_outlined,
                label: 'Folder',
                onTap: () async {
                  final dir = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: 'Add folder to "${ws.name}"',
                  );
                  if (dir == null || !context.mounted) return;
                  await context.read<WorkspaceCubit>().addPathToWorkspace(ws.id, dir);
                },
              ),
              const SizedBox(width: 6),
              _WsActionBtn(
                icon: Icons.terminal,
                label: 'Session',
                onTap: () => _createSession(context, ws.paths.isNotEmpty ? ws.paths.first : null, ws.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSession(BuildContext context, String? path, String wsId) async {
    if (path == null) return;
    final type = await showDialog<AgentType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF12151C),
        title: const Text('New Session', style: TextStyle(color: Color(0xFFE8E8FF), fontSize: 14)),
        children: [
          for (final t in AgentType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Text(t.displayName, style: const TextStyle(color: Color(0xFFCECEEE))),
            ),
        ],
      ),
    );
    if (type == null || !context.mounted) return;
    await context.read<TerminalCubit>().spawnSession(
      type:          type,
      workspacePath: path,
      workspaceId:   wsId,
    );
  }
}

class _WsActionBtn extends StatefulWidget {
  const _WsActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_WsActionBtn> createState() => _WsActionBtnState();
}

class _WsActionBtnState extends State<_WsActionBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF2A3A66) : const Color(0xFF1A1E2A),
            border: Border.all(color: _hovered ? const Color(0xFF60A5FA) : const Color(0xFF2A3040)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 11, color: _hovered ? const Color(0xFF60A5FA) : const Color(0xFF8A93B0)),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? const Color(0xFFE8E8FF) : const Color(0xFF9AA3BF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
