import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

void main() {
  group('resolveTerminalSessionId', () {
    test('prefers the mapped agent session from the graph', () {
      final session = AgentSession(
        id: 'session-123',
        type: AgentType.copilot,
        workspacePath: '/project',
        workspaceId: 'ws-1',
      );

      final nodes = <MindMapNodeData>[
        AgentNodeData(
          id: 'agent:custom-node-id',
          session: session,
          workspaceId: 'ws-1',
        ),
      ];

      expect(
        resolveTerminalSessionId('agent:custom-node-id', nodes),
        'session-123',
      );
    });

    test('falls back to stripping the agent prefix', () {
      expect(
        resolveTerminalSessionId('agent:session-999', const []),
        'session-999',
      );
    });

    test('passes through non-agent identifiers unchanged', () {
      expect(resolveTerminalSessionId('session-raw', const []), 'session-raw');
    });
  });
}
