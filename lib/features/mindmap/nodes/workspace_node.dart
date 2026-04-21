import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/workspace_card.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/data/worktree_service.dart';
import 'package:yoloit/features/workspaces/models/worktree_model.dart';
import 'package:yoloit/features/workspaces/ui/new_agent_session_dialog.dart';

class WorkspaceNode extends StatelessWidget {
  const WorkspaceNode({super.key, required this.data});
  final WorkspaceNodeData data;

  @override
  Widget build(BuildContext context) {
    final ws = data.workspace;
    return WorkspaceCard(
      props: WorkspaceCardProps(
        name: ws.name,
        color: ws.color,
        paths: ws.paths,
      ),
      onAddFolder: () async {
        final dir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Add folder to "${ws.name}"',
        );
        if (dir == null || !context.mounted) return;
        await context.read<WorkspaceCubit>().addPathToWorkspace(ws.id, dir);
      },
      onCreateSession: () => _openSessionDialog(context),
    );
  }

  Future<void> _openSessionDialog(BuildContext context) async {
    final ws = data.workspace;
    // Load worktrees for every repo path — same flow as the terminal panel.
    final worktrees = <String, List<WorktreeEntry>>{};
    for (final repoPath in ws.paths) {
      worktrees[repoPath] =
          await WorktreeService.instance.listWorktrees(repoPath);
    }
    if (!context.mounted) return;
    showNewAgentSessionDialog(
      context,
      workspace: ws,
      worktrees: worktrees,
    );
  }
}
