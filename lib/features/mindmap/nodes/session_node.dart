import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/session_card.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';

class SessionNode extends StatelessWidget {
  const SessionNode({super.key, required this.data});
  final SessionNodeData data;

  @override
  Widget build(BuildContext context) {
    final session = data.session;
    return SessionCard(
      props: SessionCardProps(
        name: session.displayName,
        typeName: session.type.displayName,
        isLive: session.status == AgentStatus.live,
        repoCount: session.worktreeContexts?.length ?? 0,
      ),
    );
  }
}
