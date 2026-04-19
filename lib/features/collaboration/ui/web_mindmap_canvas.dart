import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';

/// Lightweight mindmap canvas for web/remote guests.
/// Renders every node as a rich Flutter widget card — no native widgets
/// (no terminal, file editor, etc.).  Supports pan/zoom and drag-to-move;
/// move deltas are sent back to the host via WebSocket.
class WebMindMapCanvas extends StatefulWidget {
  const WebMindMapCanvas({super.key});

  @override
  State<WebMindMapCanvas> createState() => _WebMindMapCanvasState();
}

class _WebMindMapCanvasState extends State<WebMindMapCanvas> {
  final _transform = TransformationController();
  String? _draggingId;
  Offset _dragStartCanvas = Offset.zero;
  Offset _nodeOrigin      = Offset.zero;
  bool _hasCentered       = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Auto-pan to center on content bounding box when first snapshot arrives.
  void _centerOnContent(MindMapState state) {
    if (_hasCentered || state.positions.isEmpty || !mounted) return;
    _hasCentered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final e in state.positions.entries) {
        final sz = state.sizes[e.key] ?? const Size(220, 120);
        minX = math.min(minX, e.value.dx);
        minY = math.min(minY, e.value.dy);
        maxX = math.max(maxX, e.value.dx + sz.width);
        maxY = math.max(maxY, e.value.dy + sz.height);
      }
      final centerX = (minX + maxX) / 2;
      final centerY = (minY + maxY) / 2;
      const padding = 80.0;
      final scaleX = (size.width  - padding * 2) / (maxX - minX);
      final scaleY = (size.height - padding * 2) / (maxY - minY);
      final scale  = math.min(scaleX, scaleY).clamp(0.05, 0.8);
      // screen_point = scale * canvas_point + (tx, ty)
      // centre on screen: scale * centerX + tx = size.width/2
      final tx = size.width  / 2 - scale * centerX;
      final ty = size.height / 2 - scale * centerY;
      final m = Matrix4.identity()..scale(scale, scale, 1.0);
      m.setTranslationRaw(tx, ty, 0.0);
      setState(() => _transform.value = m);
    });
  }

  /// Convert screen-space point to canvas-space.
  Offset _toCanvas(Offset screen) {
    final m = Matrix4.inverted(_transform.value);
    final v = m.transform3(Vector3(screen.dx, screen.dy, 0));
    return Offset(v.x, v.y);
  }

  String? _hitTest(Offset canvasPos, MindMapState state) {
    for (final e in state.positions.entries) {
      if (state.hidden.contains(e.key)) continue;
      final sz = state.sizes[e.key] ?? const Size(220, 120);
      if (Rect.fromLTWH(e.value.dx, e.value.dy, sz.width, sz.height)
          .contains(canvasPos)) {
        return e.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MindMapCubit, MindMapState>(
      listener: (_, state) => _centerOnContent(state),
      child: BlocBuilder<MindMapCubit, MindMapState>(
        builder: (ctx, state) {
          final draggingId = _draggingId;
          return Stack(children: [
          // ── Dot-grid background ──────────────────────────────────────
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _transform,
              builder: (_, __) => CustomPaint(
                painter: _GridPainter(
                  offset: Offset(
                    _transform.value.getTranslation().x,
                    _transform.value.getTranslation().y,
                  ),
                  scale: _transform.value.getMaxScaleOnAxis(),
                ),
              ),
            ),
          ),

          // ── Scroll-to-zoom listener ──────────────────────────────────
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: (ev) {
              if (ev is PointerScrollEvent) {
                final factor = ev.scrollDelta.dy < 0 ? 1.1 : 0.9;
                final focalCanvas = _toCanvas(ev.localPosition);
                final m = _transform.value.clone()
                  ..translate(Vector3(focalCanvas.dx, focalCanvas.dy, 0))
                  ..scale(factor)
                  ..translate(Vector3(-focalCanvas.dx, -focalCanvas.dy, 0));
                setState(() => _transform.value = m);
              }
            },
            // ── Drag handler for node moves ──────────────────────────
            child: GestureDetector(
              onPanStart: (d) {
                final cp = _toCanvas(d.localPosition);
                final hit = _hitTest(cp, state);
                if (hit != null) {
                  setState(() {
                    _draggingId      = hit;
                    _dragStartCanvas = cp;
                    _nodeOrigin      = state.positions[hit] ?? Offset.zero;
                  });
                }
              },
              onPanUpdate: (d) {
                if (_draggingId == null) return;
                final cp  = _toCanvas(d.localPosition);
                final pos = _nodeOrigin + (cp - _dragStartCanvas);
                ctx.read<MindMapCubit>().moveNode(_draggingId!, pos);
                ctx.read<CollaborationCubit>().sendGuestMove(_draggingId!, pos);
              },
              onPanEnd: (_) => setState(() => _draggingId = null),

              child: InteractiveViewer(
                transformationController: _transform,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.04,
                maxScale: 3.0,
                panEnabled: _draggingId == null,
                child: SizedBox(
                  width:  10000,
                  height: 10000,
                  child: Stack(
                    children: [
                      // ── Connectors (behind nodes) ────────────────────
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ConnectorsPainter(state),
                        ),
                      ),
                      // ── Node cards ───────────────────────────────────
                      for (final e in state.positions.entries)
                        if (!state.hidden.contains(e.key))
                          Positioned(
                            left:   e.value.dx,
                            top:    e.value.dy,
                            width:  (state.sizes[e.key] ?? const Size(220, 160)).width,
                            height: (state.sizes[e.key] ?? const Size(220, 160)).height,
                            child: IgnorePointer(
                              child: _GuestCard(
                                nodeId:     e.key,
                                content:    state.nodeContent[e.key] ?? const {},
                                size:       state.sizes[e.key] ?? const Size(220, 160),
                                isDragging: e.key == draggingId,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
      ),
    );
  }
}

// ── Connectors painter ─────────────────────────────────────────────────────

class _ConnectorsPainter extends CustomPainter {
  const _ConnectorsPainter(this.state);
  final MindMapState state;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2D40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final conn in state.connections) {
      if (state.hidden.contains(conn.fromId) ||
          state.hidden.contains(conn.toId)) continue;
      final fp  = state.positions[conn.fromId];
      final tp2 = state.positions[conn.toId];
      if (fp == null || tp2 == null) continue;
      final fsz = state.sizes[conn.fromId] ?? const Size(220, 160);
      final tsz = state.sizes[conn.toId]   ?? const Size(220, 160);

      final start = Offset(fp.dx  + fsz.width, fp.dy  + fsz.height / 2);
      final end   = Offset(tp2.dx,              tp2.dy + tsz.height / 2);
      final mid   = (end.dx - start.dx) / 2;

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx + mid, start.dy,
                    end.dx   - mid, end.dy,
                    end.dx,         end.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorsPainter old) => old.state != state;
}

// ── Guest card widget ──────────────────────────────────────────────────────

/// Stateless rich card rendered for every visible mindmap node.
class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.nodeId,
    required this.content,
    required this.size,
    required this.isDragging,
  });

  final String nodeId;
  final Map<String, dynamic> content;
  final Size size;
  final bool isDragging;

  // ── type helpers ──────────────────────────────────────────────────────

  static Color _colorFor(String id) {
    if (id.startsWith('ws:'))      return const Color(0xFF4B9EFF);
    if (id.startsWith('session:')) return const Color(0xFFB87FFF);
    if (id.startsWith('repo:'))    return const Color(0xFF00E5FF);
    if (id.startsWith('branch:'))  return const Color(0xFF34D399);
    if (id.startsWith('agent:'))   return const Color(0xFF00FF9F);
    if (id.startsWith('files:'))   return const Color(0xFF94A3B8);
    if (id.startsWith('diff:'))    return const Color(0xFFFF9500);
    if (id.startsWith('run:'))     return const Color(0xFFFF6B85);
    if (id.startsWith('tree:'))    return const Color(0xFFFFD700);
    if (id.startsWith('editor:'))  return const Color(0xFF7DD3FC);
    return const Color(0xFF64748B);
  }

  static String _typeTagFor(String id) {
    if (id.startsWith('ws:'))      return 'WORKSPACE';
    if (id.startsWith('session:')) return 'SESSION';
    if (id.startsWith('repo:'))    return 'REPO';
    if (id.startsWith('branch:'))  return 'BRANCH';
    if (id.startsWith('agent:'))   return 'AGENT';
    if (id.startsWith('files:'))   return 'FILES';
    if (id.startsWith('diff:'))    return 'DIFF';
    if (id.startsWith('run:'))     return 'RUN';
    if (id.startsWith('tree:'))    return 'TREE';
    if (id.startsWith('editor:'))  return 'EDITOR';
    return 'NODE';
  }

  static String _typeFromId(String id) {
    final i = id.indexOf(':');
    return i < 0 ? 'node' : id.substring(0, i);
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color      = _colorFor(nodeId);
    final typeTag    = _typeTagFor(nodeId);
    final type       = (content['type'] as String?) ?? _typeFromId(nodeId);
    final name       = (content['name'] as String?) ??
                       (content['filePath'] as String?) ??
                       nodeId.substring(math.min(nodeId.indexOf(':') + 1, nodeId.length));
    final borderAlpha = isDragging ? 220 : 160;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withAlpha(borderAlpha),
          width: isDragging ? 2.0 : 1.5,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: color.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            _CardHeader(color: color, typeTag: typeTag, name: name, type: type, content: content),
            // ── Content ─────────────────────────────────────────────
            Expanded(child: _CardBody(type: type, content: content, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Card header ────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.color,
    required this.typeTag,
    required this.name,
    required this.type,
    required this.content,
  });

  final Color color;
  final String typeTag;
  final String name;
  final String type;
  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final isRunning = content['isRunning'] as bool? ?? false;
    final status    = (content['status'] as String? ?? '').toLowerCase();
    final showDot   = type == 'agent' || type == 'session' || type == 'run';

    Widget? dot;
    if (showDot) {
      final dotColor = isRunning
          ? const Color(0xFF22C55E)
          : (status == 'error' || status == 'stopped' || status == 'failed')
              ? const Color(0xFFEF4444)
              : const Color(0xFF64748B);
      dot = Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      );
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: color.withAlpha(28)),
      child: Row(
        children: [
          // Type tag chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeTag,
              style: TextStyle(
                color: color.withAlpha(200),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (dot != null) dot,
          // Name
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8E8FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card body dispatcher ───────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  const _CardBody({required this.type, required this.content, required this.color});

  final String type;
  final Map<String, dynamic> content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      'agent' || 'session' || 'run' => _TerminalBody(content: content),
      'workspace'                   => _KvBody(rows: _workspaceRows(content)),
      'repo'                        => _KvBody(rows: _repoRows(content)),
      'branch'                      => _KvBody(rows: _branchRows(content)),
      'editor'                      => _EditorBody(content: content),
      'files'                       => _FilesBody(content: content),
      'tree' || 'diff'              => _KvBody(rows: _treeDiffRows(content)),
      _                             => _KvBody(rows: _genericRows(content)),
    };
  }

  static List<(String, String)> _workspaceRows(Map<String, dynamic> c) => [
    ('PATH', (c['path'] as String?) ?? '—'),
  ];

  static List<(String, String)> _repoRows(Map<String, dynamic> c) => [
    ('BRANCH', (c['branch'] as String?) ?? '—'),
    ('PATH',   (c['path'] as String?) ?? '—'),
  ];

  static List<(String, String)> _branchRows(Map<String, dynamic> c) {
    final hash = (c['commitHash'] as String?) ?? '';
    return [
      ('COMMIT', hash.length > 8 ? hash.substring(0, 8) : hash),
      ('REPO',   (c['repoName'] as String?) ?? '—'),
    ];
  }

  static List<(String, String)> _treeDiffRows(Map<String, dynamic> c) => [
    ('REPO', (c['repoName'] as String?) ?? '—'),
    ('PATH', (c['repoPath'] as String?) ?? '—'),
  ];

  static List<(String, String)> _genericRows(Map<String, dynamic> c) {
    return c.entries
        .where((e) => e.key != 'type' && e.value is String)
        .map((e) => (e.key.toUpperCase(), e.value as String))
        .toList();
  }
}

// ── Terminal / run output body ─────────────────────────────────────────────

class _TerminalBody extends StatelessWidget {
  const _TerminalBody({required this.content});
  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final rawLines = content['lastLines'];
    final lines = rawLines is List
        ? rawLines.map((l) => l.toString()).toList()
        : <String>[];

    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No output',
          style: TextStyle(color: Color(0xFF475569), fontSize: 11),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0A0F14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lines.length,
        itemBuilder: (_, i) => Text(
          lines[i],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            color: Color(0xFF9ECFFF),
            height: 1.4,
          ),
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
      ),
    );
  }
}

// ── Key-value info body ────────────────────────────────────────────────────

class _KvBody extends StatelessWidget {
  const _KvBody({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows) ...[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Editor / code body ─────────────────────────────────────────────────────

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.content});
  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final rawContent = (content['content'] as String?) ?? '';
    final lines = rawContent.split('\n').take(50).toList();
    final language = (content['language'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (language.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Text(
              language.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        Expanded(
          child: Container(
            color: const Color(0xFF0A0F14),
            margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lines.length,
              itemBuilder: (_, i) => Text(
                lines[i],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFFADD8E6),
                  height: 1.4,
                ),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Files list body ────────────────────────────────────────────────────────

class _FilesBody extends StatelessWidget {
  const _FilesBody({required this.content});
  final Map<String, dynamic> content;

  static Color _statusColor(String s) => switch (s.toLowerCase()) {
    'added' || 'a'    => const Color(0xFF22C55E),
    'modified' || 'm' => const Color(0xFFFBBF24),
    'deleted' || 'd'  => const Color(0xFFEF4444),
    'renamed' || 'r'  => const Color(0xFF60A5FA),
    _                 => const Color(0xFF64748B),
  };

  static String _statusLabel(String s) => switch (s.toLowerCase()) {
    'added' || 'a'    => 'A',
    'modified' || 'm' => 'M',
    'deleted' || 'd'  => 'D',
    'renamed' || 'r'  => 'R',
    _                 => '?',
  };

  @override
  Widget build(BuildContext context) {
    final rawFiles = content['files'];
    final files = rawFiles is List
        ? rawFiles.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    if (files.isEmpty) {
      return const Center(
        child: Text(
          'No files',
          style: TextStyle(color: Color(0xFF475569), fontSize: 11),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: files.length,
      itemBuilder: (_, i) {
        final file   = files[i];
        final path   = (file['path'] as String?) ?? '';
        final status = (file['status'] as String?) ?? '';
        final col    = _statusColor(status);
        final label  = _statusLabel(status);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: col.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: col,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  path,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Dot-grid painter ───────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.offset, required this.scale});
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E293B);
    const base  = 30.0;
    final step  = base * scale;
    if (step < 4) return; // too small to draw

    final ox = offset.dx % step;
    final oy = offset.dy % step;
    var x = ox < 0 ? ox + step : ox;
    while (x <= size.width) {
      var y = oy < 0 ? oy + step : oy;
      while (y <= size.height) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
        y += step;
      }
      x += step;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.offset != offset || old.scale != scale;
}
