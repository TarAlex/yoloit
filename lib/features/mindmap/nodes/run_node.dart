import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/runs/models/run_session.dart';

class RunNode extends StatelessWidget {
  const RunNode({super.key, required this.data});
  final RunNodeData data;

  @override
  Widget build(BuildContext context) {
    final session = data.session;
    final isRunning = session.status == RunStatus.running;
    final statusColor = switch (session.status) {
      RunStatus.running => const Color(0xFF34D399),
      RunStatus.failed  => const Color(0xFFFF4F6A),
      RunStatus.stopped => const Color(0xFF6B7898),
      RunStatus.idle    => const Color(0xFF6B7898),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14),
        border: Border.all(
          color: isRunning ? const Color(0x5534D399) : const Color(0x553A4560),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header with action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isRunning ? const Color(0x0F34D399) : const Color(0x0F3A4560),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 12, color: Color(0xFF60A5FA)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.config.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8E8FF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ── Action buttons ─────────────────────────────────────
                if (isRunning)
                  _RunActionBtn(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop',
                    color: const Color(0xFFFF6B6B),
                    onTap: () => context.read<RunCubit>().stopRun(session.id),
                  )
                else
                  _RunActionBtn(
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Start',
                    color: const Color(0xFF34D399),
                    onTap: () => context.read<RunCubit>().startRun(session.config),
                  ),
                const SizedBox(width: 4),
                _RunActionBtn(
                  icon: Icons.refresh,
                  tooltip: 'Restart',
                  color: const Color(0xFF60A5FA),
                  onTap: () {
                    final cubit = context.read<RunCubit>();
                    if (isRunning) cubit.stopRun(session.id);
                    // Small delay isn't needed; RunCubit.startRun handles cleanup.
                    cubit.startRun(session.config);
                  },
                ),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          // Output lines
          Expanded(
            child: Container(
              color: const Color(0xFF070714),
              child: session.output.isEmpty
                  ? const Center(
                      child: Text(
                        'No output',
                        style: TextStyle(fontSize: 10, color: Color(0xFF44446A)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: session.output.length,
                      itemBuilder: (context, i) {
                        final line = session.output[i];
                        return Text(
                          line.text,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: line.isError
                                ? const Color(0xFFFF4F6A)
                                : const Color(0xFFCECEEE),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunActionBtn extends StatefulWidget {
  const _RunActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_RunActionBtn> createState() => _RunActionBtnState();
}

class _RunActionBtnState extends State<_RunActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withAlpha(40)
                  : const Color(0xFF12151C),
              border: Border.all(
                color: _hovered ? widget.color : const Color(0xFF2A3040),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: _hovered ? widget.color : const Color(0xFF8A93B0),
            ),
          ),
        ),
      ),
    );
  }
}
