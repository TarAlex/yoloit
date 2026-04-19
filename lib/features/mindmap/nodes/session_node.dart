import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';

class SessionNode extends StatelessWidget {
  const SessionNode({super.key, required this.data});
  final SessionNodeData data;

  @override
  Widget build(BuildContext context) {
    final session  = data.session;
    final isLive   = session.status == AgentStatus.live;
    final dotColor = isLive ? const Color(0xFF34D399) : const Color(0xFF6B7898);

    // Flutter requires uniform borders when using borderRadius.
    // Use a Row to achieve the thick left-accent with uniform outer border.
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x66C084FC), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar.
              Container(width: 3, color: const Color(0xFFC084FC)),
              // Content.
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [Color(0xFF1A1827), Color(0xFF161322)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                              boxShadow: isLive
                                  ? [BoxShadow(color: dotColor.withAlpha(160), blurRadius: 6)]
                                  : [],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE8E8FF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive)
                            const Text(
                              '▶',
                              style: TextStyle(fontSize: 9, color: Color(0xFF34D399)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.type.displayName,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7898)),
                      ),
                      if (session.worktreeContexts != null &&
                          session.worktreeContexts!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${session.worktreeContexts!.length} '
                          '${session.worktreeContexts!.length == 1 ? "repo" : "repos"}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF44446A)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
