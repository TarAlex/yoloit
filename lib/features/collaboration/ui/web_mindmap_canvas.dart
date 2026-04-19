import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_factory.dart';

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
  // Start zoomed out at 10% so the whole 10000x10000 canvas fits in ~1000px —
  // nodes at x=2000-4000 are visible immediately even before centering runs.
  final _transform = TransformationController(
    Matrix4.identity()..scale(0.1, 0.1, 1.0),
  );
  String? _draggingId;
  Offset _dragStartCanvas = Offset.zero;
  Offset _nodeOrigin      = Offset.zero;
  bool _hasCentered       = false;

  @override
  void initState() {
    super.initState();
    // If snapshot already arrived before this widget mounted, center on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _centerOnContent(context.read<MindMapCubit>().state);
      }
    });
  }

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
                constrained: false,
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
                              child: buildCardFromContent(
                                e.key,
                                state.nodeContent[e.key] ?? const {},
                                CardEventCallbacks(
                                  onTerminalInput: (nodeId, data) =>
                                      ctx.read<CollaborationCubit>().sendTerminalInput(nodeId, data),
                                  onRunStart: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('run_start', {'id': nodeId}),
                                  onRunStop: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('run_stop', {'id': nodeId}),
                                  onRunRestart: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('run_restart', {'id': nodeId}),
                                  onAddFolder: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('ws_add_folder', {'id': nodeId}),
                                  onCreateSession: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('ws_create_session', {'id': nodeId}),
                                  onFileSelect: (nodeId, path) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('file_select', {'id': nodeId, 'path': path}),
                                  onTreeToggle: (nodeId, path) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('tree_toggle', {'id': nodeId, 'path': path}),
                                  onTreeSelect: (nodeId, path) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('tree_select', {'id': nodeId, 'path': path}),
                                  onEditorSwitchTab: (nodeId, idx) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('editor_switch_tab', {'id': nodeId, 'tabIndex': idx}),
                                  onSessionStart: (nodeId) =>
                                      ctx.read<CollaborationCubit>().sendGuestEvent('session_start', {'id': nodeId}),
                                ),
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
