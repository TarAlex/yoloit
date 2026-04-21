import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Presentation run card — identical visuals to macOS RunNode.
class RunCard extends StatelessWidget {
  const RunCard({
    super.key,
    required this.props,
    this.onStart,
    this.onStop,
    this.onRestart,
    this.onCopy,
  });
  final RunCardProps props;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onRestart;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isRunning = props.isRunning;
    final statusColor = switch (props.status) {
      'running' => const Color(0xFF34D399),
      'failed' => const Color(0xFFFF4F6A),
      _ => const Color(0xFF6B7898),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14),
        border: Border.all(
          color: isRunning
              ? const Color(0x5534D399)
              : const Color(0x553A4560),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isRunning
                  ? const Color(0x0F34D399)
                  : const Color(0x0F3A4560),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline,
                    size: 12, color: Color(0xFF60A5FA)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    props.name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8E8FF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _RunActionBtn(
                  icon: Icons.copy_all_rounded,
                  tooltip: 'Copy all logs',
                  color: const Color(0xFFA78BFA),
                  onTap: onCopy ?? () {
                    final text = props.lines.map((l) => l.text).join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logs copied to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 220,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                if (isRunning)
                  _RunActionBtn(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop',
                    color: const Color(0xFFFF6B6B),
                    onTap: onStop,
                  )
                else
                  _RunActionBtn(
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Start',
                    color: const Color(0xFF34D399),
                    onTap: onStart,
                  ),
                const SizedBox(width: 4),
                _RunActionBtn(
                  icon: Icons.refresh,
                  tooltip: 'Restart',
                  color: const Color(0xFF60A5FA),
                  onTap: onRestart,
                ),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          Expanded(
            child: SelectionArea(
              child: Container(
                color: const Color(0xFF070714),
                child: props.lines.isEmpty
                    ? const Center(
                        child: Text('No output',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF44446A))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: props.lines.length,
                        itemBuilder: (context, i) {
                          final line = props.lines[i];
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
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

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
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 22,
            height: 22,
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
            child: Icon(widget.icon,
                size: 13,
                color: _hovered ? widget.color : const Color(0xFF8A93B0)),
          ),
        ),
      ),
    );
  }
}
