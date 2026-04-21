import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/agent_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/agent_card_props_builder.dart';
import 'package:yoloit/features/mindmap/nodes/terminal_embed.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';

/// Mindmap agent card — uses the shared AgentCard shell and injects live PTY.
class AgentNode extends StatelessWidget {
  const AgentNode({super.key, required this.data});
  final AgentNodeData data;

  @override
  Widget build(BuildContext context) {
    final props = buildAgentCardProps(data);
    return AgentCard(
      props: props,
      body: props.isIdle ? null : TerminalEmbed(session: data.session),
      onSessionStart: props.isIdle ? () => _startSavedSession(context) : null,
    );
  }

  Future<void> _startSavedSession(BuildContext context) {
    return context.read<TerminalCubit>().spawnSession(
      type: data.session.type,
      workspacePath: data.session.workspacePath,
      workspaceId: data.session.workspaceId,
      savedSessionId: data.session.id,
      isRestore: true,
      worktreeContexts: data.session.worktreeContexts,
    );
  }
}
