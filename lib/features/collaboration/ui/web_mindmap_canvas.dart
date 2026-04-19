import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';

/// Lightweight mindmap canvas for web/remote guests.
/// Renders every node as a coloured card using [CustomPainter] — no native
/// widgets (no terminal, file editor, etc.).  Supports pan/zoom and
/// drag-to-move; move deltas are sent back to the host via WebSocket.
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

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
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
    return BlocBuilder<MindMapCubit, MindMapState>(
      builder: (ctx, state) {
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
                    _draggingId     = hit;
                    _dragStartCanvas = cp;
                    _nodeOrigin     = state.positions[hit] ?? Offset.zero;
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
                  child: CustomPaint(
                    painter: _NodesPainter(state, _draggingId),
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Nodes painter ──────────────────────────────────────────────────────────

class _NodesPainter extends CustomPainter {
  _NodesPainter(this.state, this.draggingId);
  final MindMapState state;
  final String? draggingId;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connectors first (behind nodes)
    _drawConnectors(canvas);

    // Iterate positions (works even when state.nodes is empty, e.g. on guest)
    for (final entry in state.positions.entries) {
      final id = entry.key;
      if (state.hidden.contains(id)) continue;
      final pos = entry.value;
      final sz  = state.sizes[id] ?? const Size(220, 120);
      _drawNode(canvas, id, pos, sz);
    }
  }

  void _drawNode(Canvas canvas, String id, Offset pos, Size sz) {
    final color  = _colorFor(id);
    final isDragging = id == draggingId;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx, pos.dy, sz.width, sz.height),
      const Radius.circular(10),
    );

    // Shadow when dragging
    if (isDragging) {
      canvas.drawRRect(
        rect.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black45
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // Card background
    canvas.drawRRect(rect,
        Paint()..color = const Color(0xFF0D1117).withAlpha(245));

    // Header accent band
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(pos.dx, pos.dy, sz.width, 30),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      Paint()..color = color.withAlpha(28),
    );

    // Coloured border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withAlpha(isDragging ? 220 : 160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDragging ? 2.0 : 1.5,
    );

    // Type tag
    _text(canvas, _typeFor(id),
        Offset(pos.dx + 12, pos.dy + 7),
        sz.width - 16,
        color: color.withAlpha(190),
        fontSize: 9,
        weight: FontWeight.w700,
        letterSpacing: 1.2);

    // Main label
    _text(canvas, _labelFor(id),
        Offset(pos.dx + 12, pos.dy + 35),
        sz.width - 16,
        color: const Color(0xFFE8E8FF),
        fontSize: 13,
        weight: FontWeight.w600);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth, {
    required Color color,
    required double fontSize,
    required FontWeight weight,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  void _drawConnectors(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF1E2D40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final conn in state.connections) {
      if (state.hidden.contains(conn.fromId) ||
          state.hidden.contains(conn.toId)) continue;
      final fp = state.positions[conn.fromId];
      final tp2 = state.positions[conn.toId];
      if (fp == null || tp2 == null) continue;
      final fsz = state.sizes[conn.fromId] ?? const Size(220, 120);
      final tsz = state.sizes[conn.toId]   ?? const Size(220, 120);

      final start = Offset(fp.dx + fsz.width, fp.dy + fsz.height / 2);
      final end   = Offset(tp2.dx, tp2.dy + tsz.height / 2);
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

  // ── helpers ────────────────────────────────────────────────────────────

  Color _colorFor(String id) {
    if (id.startsWith('ws:'))      return const Color(0xFF4B9EFF);
    if (id.startsWith('session:')) return const Color(0xFFB87FFF);
    if (id.startsWith('repo:'))    return const Color(0xFF00E5FF);
    if (id.startsWith('branch:'))  return const Color(0xFF34D399);
    if (id.startsWith('agent:'))   return const Color(0xFF00FF9F);
    if (id.startsWith('files:'))   return const Color(0xFF94A3B8);
    if (id.startsWith('diff:'))    return const Color(0xFFFF9500);
    if (id.startsWith('run:'))     return const Color(0xFFFF6B85);
    return const Color(0xFF64748B);
  }

  String _labelFor(String id) {
    final i = id.indexOf(':');
    if (i < 0) return id;
    final s = id.substring(i + 1);
    return s.length > 26 ? '${s.substring(0, 24)}…' : s;
  }

  String _typeFor(String id) {
    if (id.startsWith('ws:'))      return 'WORKSPACE';
    if (id.startsWith('session:')) return 'SESSION';
    if (id.startsWith('repo:'))    return 'REPO';
    if (id.startsWith('branch:'))  return 'BRANCH';
    if (id.startsWith('agent:'))   return 'AGENT';
    if (id.startsWith('files:'))   return 'FILES';
    if (id.startsWith('diff:'))    return 'DIFF';
    if (id.startsWith('run:'))     return 'RUN';
    return 'NODE';
  }

  @override
  bool shouldRepaint(_NodesPainter old) =>
      old.state != state || old.draggingId != draggingId;
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
