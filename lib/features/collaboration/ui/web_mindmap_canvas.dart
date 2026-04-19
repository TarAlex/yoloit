import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_factory.dart';

/// Full-featured mindmap canvas for web/remote guests.
/// Mirrors the macOS MindMapView: toolbar, minimap, sidebar, drag handles,
/// resize handles on every card.
class WebMindMapCanvas extends StatefulWidget {
  const WebMindMapCanvas({super.key});

  @override
  State<WebMindMapCanvas> createState() => _WebMindMapCanvasState();
}

class _WebMindMapCanvasState extends State<WebMindMapCanvas> {
  final _transform = TransformationController(
    Matrix4.identity()..scale(0.1, 0.1, 1.0),
  );
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerOnContent(context.read<MindMapCubit>().state);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _centerOnContent(MindMapState state) {
    if (_hasCentered || state.positions.isEmpty || !mounted) return;
    _hasCentered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewSize = MediaQuery.of(context).size;
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final e in state.positions.entries) {
        if (state.hidden.contains(e.key)) continue;
        final sz = state.sizes[e.key] ?? const Size(220, 120);
        minX = math.min(minX, e.value.dx);
        minY = math.min(minY, e.value.dy);
        maxX = math.max(maxX, e.value.dx + sz.width);
        maxY = math.max(maxY, e.value.dy + sz.height);
      }
      if (minX == double.infinity) return;
      final centerX = (minX + maxX) / 2;
      final centerY = (minY + maxY) / 2;
      const padding = 80.0;
      final scaleX = (viewSize.width - padding * 2) / (maxX - minX);
      final scaleY = (viewSize.height - padding * 2) / (maxY - minY);
      final scale = math.min(scaleX, scaleY).clamp(0.05, 0.8);
      final tx = viewSize.width / 2 - scale * centerX;
      final ty = viewSize.height / 2 - scale * centerY;
      final m = Matrix4.identity()..scale(scale, scale, 1.0);
      m.setTranslationRaw(tx, ty, 0.0);
      setState(() => _transform.value = m);
    });
  }

  void _panToOffset(Offset canvasCenter) {
    if (!mounted) return;
    final viewSize = MediaQuery.of(context).size;
    final scale = _transform.value.getMaxScaleOnAxis();
    final tx = viewSize.width / 2 - scale * canvasCenter.dx;
    final ty = viewSize.height / 2 - scale * canvasCenter.dy;
    final m = Matrix4.identity()..scale(scale, scale, 1.0);
    m.setTranslationRaw(tx, ty, 0.0);
    setState(() => _transform.value = m);
  }

  void _zoom(double factor) {
    final viewSize = MediaQuery.of(context).size;
    final focalCanvas = _toCanvas(Offset(viewSize.width / 2, viewSize.height / 2));
    final m = _transform.value.clone()
      ..translate(Vector3(focalCanvas.dx, focalCanvas.dy, 0))
      ..scale(factor)
      ..translate(Vector3(-focalCanvas.dx, -focalCanvas.dy, 0));
    setState(() => _transform.value = m);
  }

  Offset _toCanvas(Offset screen) {
    final m = Matrix4.inverted(_transform.value);
    final v = m.transform3(Vector3(screen.dx, screen.dy, 0));
    return Offset(v.x, v.y);
  }

  CardEventCallbacks _makeCallbacks(BuildContext ctx) => CardEventCallbacks(
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
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<MindMapCubit, MindMapState>(
      listener: (_, state) => _centerOnContent(state),
      child: BlocBuilder<MindMapCubit, MindMapState>(
        builder: (ctx, state) {
          final callbacks = _makeCallbacks(ctx);
          return LayoutBuilder(
            builder: (ctx, constraints) {
              final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(children: [
                // ── Dot-grid background ──────────────────────────────────
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

                // ── Scroll-to-zoom ──────────────────────────────────────
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
                  child: InteractiveViewer(
                    transformationController: _transform,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    constrained: false,
                    minScale: 0.04,
                    maxScale: 3.0,
                    child: SizedBox(
                      width: 10000,
                      height: 10000,
                      child: Stack(
                        children: [
                          // Connectors
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ConnectorsPainter(state),
                            ),
                          ),
                          // Node cards with drag + resize handles
                          for (final e in state.positions.entries)
                            if (!state.hidden.contains(e.key))
                              _WebNode(
                                nodeId: e.key,
                                position: e.value,
                                size: state.sizes[e.key] ?? const Size(220, 160),
                                content: state.nodeContent[e.key] ?? const {},
                                callbacks: callbacks,
                                onClose: () =>
                                    ctx.read<MindMapCubit>().hideNode(e.key),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Toolbar (top-right) ───────────────────────────────────
                Positioned(
                  top: 8, right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _WebToolbar(
                        onZoomIn: () => _zoom(1.25),
                        onZoomOut: () => _zoom(0.8),
                        onFit: () {
                          _hasCentered = false;
                          _centerOnContent(state);
                        },
                        onResetLayout: () =>
                            ctx.read<MindMapCubit>().resetLayout(),
                        hiddenCount: state.hidden.length,
                        onShowAll: () =>
                            ctx.read<MindMapCubit>().showAllNodes(),
                      ),
                      const SizedBox(height: 8),
                      // Minimap
                      _WebMiniMap(
                        positions: state.positions,
                        sizes: state.sizes,
                        hidden: state.hidden,
                        nodeContent: state.nodeContent,
                        transformCtrl: _transform,
                        viewportSize: viewportSize,
                        onPanTo: _panToOffset,
                      ),
                    ],
                  ),
                ),

                // ── Sidebar (left) ──────────────────────────────────────
                Positioned(
                  top: 8, left: 8, bottom: 8,
                  child: _WebSidebar(
                    state: state,
                    onFocusNode: (nodeId) {
                      final pos = state.positions[nodeId];
                      if (pos == null) return;
                      if (state.hidden.contains(nodeId)) {
                        ctx.read<MindMapCubit>().showNode(nodeId);
                      }
                      _panToOffset(pos);
                    },
                    onToggleHide: (nodeId) {
                      if (state.hidden.contains(nodeId)) {
                        ctx.read<MindMapCubit>().showNode(nodeId);
                      } else {
                        ctx.read<MindMapCubit>().hideNode(nodeId);
                      }
                    },
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Web Node (drag handle + resize handles + card content) ────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _WebNode extends StatefulWidget {
  const _WebNode({
    required this.nodeId,
    required this.position,
    required this.size,
    required this.content,
    required this.callbacks,
    this.onClose,
  });
  final String nodeId;
  final Offset position;
  final Size size;
  final Map<String, dynamic> content;
  final CardEventCallbacks callbacks;
  final VoidCallback? onClose;

  @override
  State<_WebNode> createState() => _WebNodeState();
}

class _WebNodeState extends State<_WebNode> {
  bool _hovered = false;

  static const _handleH = 20.0;
  static const _minW = 140.0;
  static const _minH = 80.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MindMapCubit>();
    final collab = context.read<CollaborationCubit>();

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Main card ─────────────────────────────────────────────
            SizedBox(
              width: widget.size.width,
              height: widget.size.height,
              child: Column(
                children: [
                  // Drag handle strip
                  GestureDetector(
                    onPanUpdate: (d) {
                      cubit.moveNode(widget.nodeId, d.delta);
                      final pos = cubit.state.positions[widget.nodeId];
                      if (pos != null) collab.sendGuestMove(widget.nodeId, pos);
                    },
                    child: _DragHandle(hovered: _hovered),
                  ),
                  // Card content
                  Expanded(
                    child: buildCardFromContent(
                      widget.nodeId,
                      widget.content,
                      widget.callbacks,
                    ),
                  ),
                ],
              ),
            ),

            // ── Resize: right edge ──────────────────────────────────
            Positioned(
              right: -6, top: _handleH, bottom: 12,
              width: 12,
              child: _ResizeEdge(
                axis: Axis.vertical,
                visible: _hovered,
                onDrag: (d) {
                  cubit.resizeNode(widget.nodeId, Offset(d.delta.dx, 0), const Size(_minW, _minH));
                  final sz = cubit.state.sizes[widget.nodeId];
                  if (sz != null) collab.sendGuestResize(widget.nodeId, sz);
                },
              ),
            ),
            // Left edge
            Positioned(
              left: -6, top: _handleH, bottom: 12,
              width: 12,
              child: _ResizeEdge(
                axis: Axis.vertical,
                visible: _hovered,
                onDrag: (d) {
                  cubit.resizeFromLeft(widget.nodeId, d.delta.dx, const Size(_minW, _minH));
                  final sz = cubit.state.sizes[widget.nodeId];
                  if (sz != null) collab.sendGuestResize(widget.nodeId, sz);
                },
              ),
            ),
            // Bottom edge
            Positioned(
              bottom: -6, left: 12, right: 12,
              height: 12,
              child: _ResizeEdge(
                axis: Axis.horizontal,
                visible: _hovered,
                onDrag: (d) {
                  cubit.resizeNode(widget.nodeId, Offset(0, d.delta.dy), const Size(_minW, _minH));
                  final sz = cubit.state.sizes[widget.nodeId];
                  if (sz != null) collab.sendGuestResize(widget.nodeId, sz);
                },
              ),
            ),
            // Bottom-right corner
            Positioned(
              right: 0, bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  cubit.resizeNode(widget.nodeId, d.delta, const Size(_minW, _minH));
                  final sz = cubit.state.sizes[widget.nodeId];
                  if (sz != null) collab.sendGuestResize(widget.nodeId, sz);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CustomPaint(painter: _LCornerPainter(hovered: _hovered)),
                  ),
                ),
              ),
            ),
            // Bottom-left corner
            Positioned(
              left: 0, bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  cubit.resizeFromLeft(widget.nodeId, d.delta.dx, const Size(_minW, _minH));
                  cubit.resizeNode(widget.nodeId, Offset(0, d.delta.dy), const Size(_minW, _minH));
                  final sz = cubit.state.sizes[widget.nodeId];
                  if (sz != null) collab.sendGuestResize(widget.nodeId, sz);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpRightDownLeft,
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CustomPaint(painter: _LCornerPainter(hovered: _hovered, flipX: true)),
                  ),
                ),
              ),
            ),

            // ── Close button ────────────────────────────────────────
            if (_hovered && widget.onClose != null)
              Positioned(
                top: 1, right: 2,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xAAFF4F6A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Drag Handle ────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.hovered});
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        height: 20,
        decoration: BoxDecoration(
          color: hovered ? const Color(0x30FFFFFF) : const Color(0x14FFFFFF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              6,
              (_) => Container(
                width: 3, height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: hovered
                      ? const Color(0x80FFFFFF)
                      : const Color(0x40FFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resize Edge ────────────────────────────────────────────────────────────

class _ResizeEdge extends StatelessWidget {
  const _ResizeEdge({required this.axis, required this.visible, required this.onDrag});
  final Axis axis;
  final bool visible;
  final void Function(DragUpdateDetails) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onDrag,
      child: MouseRegion(
        cursor: axis == Axis.vertical
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.resizeUpDown,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: Container(
              width: axis == Axis.vertical ? 3 : double.infinity,
              height: axis == Axis.vertical ? double.infinity : 3,
              decoration: BoxDecoration(
                color: const Color(0x6060A5FA),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── L-Corner painter ───────────────────────────────────────────────────────

class _LCornerPainter extends CustomPainter {
  const _LCornerPainter({required this.hovered, this.flipX = false});
  final bool hovered;
  final bool flipX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = hovered ? const Color(0xCC60A5FA) : const Color(0x4060A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const len = 10.0;
    const m = 3.0;
    if (flipX) {
      canvas.drawLine(Offset(m, size.height - m), Offset(m + len, size.height - m), paint);
      canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - len), paint);
    } else {
      canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - len, size.height - m), paint);
      canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - len), paint);
    }
  }

  @override
  bool shouldRepaint(_LCornerPainter old) => old.hovered != hovered;
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Toolbar ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _WebToolbar extends StatelessWidget {
  const _WebToolbar({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onResetLayout,
    required this.hiddenCount,
    required this.onShowAll,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onResetLayout;
  final int hiddenCount;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xEE0F1218),
        border: Border.all(color: const Color(0xFF1E2330)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolBtn(icon: Icons.remove, tooltip: 'Zoom out', onTap: onZoomOut),
          _ToolBtn(icon: Icons.filter_center_focus, tooltip: 'Fit all', onTap: onFit),
          _ToolBtn(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          const SizedBox(width: 4),
          _ToolBtn(icon: Icons.refresh, tooltip: 'Reset layout', onTap: onResetLayout),
          if (hiddenCount > 0)
            _ToolBtn(
              icon: Icons.visibility,
              tooltip: 'Show all ($hiddenCount hidden)',
              onTap: onShowAll,
            ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Minimap ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _WebMiniMap extends StatelessWidget {
  const _WebMiniMap({
    required this.positions,
    required this.sizes,
    required this.hidden,
    required this.nodeContent,
    required this.transformCtrl,
    required this.viewportSize,
    required this.onPanTo,
  });

  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Set<String> hidden;
  final Map<String, Map<String, dynamic>> nodeContent;
  final TransformationController transformCtrl;
  final Size viewportSize;
  final void Function(Offset canvasCenter) onPanTo;

  static const double _mapW = 210.0;
  static const double _mapH = 130.0;
  static const double _padding = 240.0;

  Rect _canvasBounds() {
    final visible = positions.entries.where((e) => !hidden.contains(e.key));
    if (visible.isEmpty) {
      return const Rect.fromLTWH(1800, 1800, 3500, 2000);
    }
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final e in visible) {
      final sz = sizes[e.key] ?? const Size(200, 150);
      minX = math.min(minX, e.value.dx);
      minY = math.min(minY, e.value.dy);
      maxX = math.max(maxX, e.value.dx + sz.width);
      maxY = math.max(maxY, e.value.dy + sz.height);
    }
    return Rect.fromLTRB(
      minX - _padding, minY - _padding,
      maxX + _padding, maxY + _padding,
    );
  }

  void _handleGesture(Offset local, Rect bounds) {
    final cx = bounds.left + local.dx / _mapW * bounds.width;
    final cy = bounds.top + local.dy / _mapH * bounds.height;
    onPanTo(Offset(cx, cy));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transformCtrl,
      builder: (ctx, _) {
        final bounds = _canvasBounds();
        final vpTL = transformCtrl.toScene(Offset.zero);
        final vpBR = transformCtrl.toScene(Offset(viewportSize.width, viewportSize.height));
        final viewportRect = Rect.fromLTRB(vpTL.dx, vpTL.dy, vpBR.dx, vpBR.dy);

        return GestureDetector(
          onTapDown: (d) => _handleGesture(d.localPosition, bounds),
          onPanUpdate: (d) => _handleGesture(d.localPosition, bounds),
          child: Container(
            width: _mapW,
            height: _mapH,
            decoration: BoxDecoration(
              color: const Color(0xE50B0D12),
              border: Border.all(color: const Color(0x3060A5FA)),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _MiniMapPainter(
                  positions: positions,
                  sizes: sizes,
                  hidden: hidden,
                  nodeContent: nodeContent,
                  bounds: bounds,
                  viewportRect: viewportRect,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({
    required this.positions,
    required this.sizes,
    required this.hidden,
    required this.nodeContent,
    required this.bounds,
    required this.viewportRect,
  });
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Set<String> hidden;
  final Map<String, Map<String, dynamic>> nodeContent;
  final Rect bounds;
  final Rect viewportRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (bounds.isEmpty) return;
    final scaleX = size.width / bounds.width;
    final scaleY = size.height / bounds.height;

    for (final e in positions.entries) {
      if (hidden.contains(e.key)) continue;
      final pos = e.value;
      final nodeSz = sizes[e.key] ?? const Size(200, 150);
      final mx = (pos.dx - bounds.left) * scaleX;
      final my = (pos.dy - bounds.top) * scaleY;
      final mw = math.max(3.0, nodeSz.width * scaleX);
      final mh = math.max(2.0, nodeSz.height * scaleY);
      final type = (nodeContent[e.key]?['type'] as String?) ?? _typeFromId(e.key);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(mx, my, mw, mh), const Radius.circular(1.5)),
        Paint()..color = _colorForType(type),
      );
    }

    // Viewport rectangle
    final vx = (viewportRect.left - bounds.left) * scaleX;
    final vy = (viewportRect.top - bounds.top) * scaleY;
    final vw = math.max(8.0, viewportRect.width * scaleX);
    final vh = math.max(8.0, viewportRect.height * scaleY);
    final vpRRect = RRect.fromRectAndRadius(Rect.fromLTWH(vx, vy, vw, vh), const Radius.circular(3));
    canvas.drawRRect(vpRRect, Paint()..color = const Color(0x2060A5FA));
    canvas.drawRRect(vpRRect, Paint()
      ..color = const Color(0xCC60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  static String _typeFromId(String id) {
    final i = id.indexOf(':');
    return i < 0 ? 'node' : id.substring(0, i);
  }

  static Color _colorForType(String type) => switch (type) {
    'workspace' => const Color(0xCC7C3AED),
    'agent'     => const Color(0xCC34D399),
    'branch'    => const Color(0xCC60A5FA),
    'tree'      => const Color(0xCC10B981),
    'diff'      => const Color(0xCC7C6BFF),
    'files'     => const Color(0xCCF59E0B),
    'run'       => const Color(0xCCF87171),
    'editor'    => const Color(0xCCE879F9),
    'session'   => const Color(0xCC93C5FD),
    'repo'      => const Color(0xCC94A3B8),
    _           => const Color(0xCC64748B),
  };

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.viewportRect != viewportRect ||
      old.positions != positions ||
      old.bounds != bounds;
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Sidebar ───────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _WebSidebar extends StatefulWidget {
  const _WebSidebar({
    required this.state,
    required this.onFocusNode,
    required this.onToggleHide,
  });
  final MindMapState state;
  final void Function(String nodeId) onFocusNode;
  final void Function(String nodeId) onToggleHide;

  @override
  State<_WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<_WebSidebar> {
  bool _collapsed = false;
  double _width = 220;
  static const _minWidth = 160.0;
  static const _maxWidth = 480.0;
  final _expandedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final mm = widget.state;

    if (_collapsed) {
      return GestureDetector(
        onTap: () => setState(() => _collapsed = false),
        child: Container(
          width: 28,
          decoration: BoxDecoration(
            color: const Color(0xEE0F1218),
            border: Border.all(color: const Color(0xFF1E2330)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF6B7898)),
          ),
        ),
      );
    }

    // Build workspace → children tree from connections
    final childMap = <String, List<String>>{};
    for (final c in mm.connections) {
      (childMap[c.fromId] ??= []).add(c.toId);
    }

    // Workspace nodes are identified by type in nodeContent
    final workspaceIds = mm.nodeContent.entries
        .where((e) => e.value['type'] == 'workspace')
        .map((e) => e.key)
        .toList();

    // Auto-expand workspaces on first appearance
    for (final wsId in workspaceIds) {
      _expandedIds.add(wsId);
    }

    // Find orphan nodes (not reachable from any workspace)
    final reachable = <String>{};
    for (final wsId in workspaceIds) {
      _collectIds(wsId, childMap, reachable);
    }
    final orphanIds = mm.positions.keys
        .where((id) => !workspaceIds.contains(id) && !reachable.contains(id))
        .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _width,
          decoration: BoxDecoration(
            color: const Color(0xEE0F1218),
            border: Border.all(color: const Color(0xFF1E2330)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, size: 14, color: Color(0xFF7C6BFF)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Show / Hide',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Color(0xFFE8E8FF), letterSpacing: 0.3)),
                    ),
                    if (mm.hidden.isNotEmpty)
                      InkWell(
                        onTap: () => context.read<MindMapCubit>().showAllNodes(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text('Show all',
                            style: TextStyle(fontSize: 9, color: Color(0xFF7C6BFF))),
                        ),
                      ),
                    InkWell(
                      onTap: () => setState(() => _collapsed = true),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.chevron_left, size: 14, color: Color(0xFF6B7898)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E2330)),
              // Tree list
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  children: [
                    for (final wsId in workspaceIds) ...[
                      _SidebarRow(
                        nodeId: wsId,
                        label: (mm.nodeContent[wsId]?['name'] as String?) ?? wsId,
                        type: 'workspace',
                        depth: 0,
                        hidden: mm.hidden.contains(wsId),
                        expanded: _expandedIds.contains(wsId),
                        hasChildren: childMap.containsKey(wsId),
                        onToggleExpand: () => setState(() {
                          _expandedIds.contains(wsId)
                              ? _expandedIds.remove(wsId)
                              : _expandedIds.add(wsId);
                        }),
                        onToggleHide: () => widget.onToggleHide(wsId),
                        onFocus: () => widget.onFocusNode(wsId),
                      ),
                      if (_expandedIds.contains(wsId))
                        ..._buildSubtree(wsId, childMap, mm, depth: 1, visited: {wsId}),
                    ],
                    if (orphanIds.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 8, 8, 2),
                        child: Text('OTHER',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: Color(0xFF4A5680), letterSpacing: 1)),
                      ),
                      for (final id in orphanIds)
                        _SidebarRow(
                          nodeId: id,
                          label: _nodeLabel(id, mm),
                          type: (mm.nodeContent[id]?['type'] as String?) ?? 'node',
                          depth: 1,
                          hidden: mm.hidden.contains(id),
                          expanded: false,
                          hasChildren: false,
                          onToggleHide: () => widget.onToggleHide(id),
                          onFocus: () => widget.onFocusNode(id),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // Resize handle (right edge)
        Positioned(
          right: -4, top: 0, bottom: 0,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              _width = (_width + d.delta.dx).clamp(_minWidth, _maxWidth);
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: const SizedBox(width: 8),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSubtree(
    String parentId,
    Map<String, List<String>> childMap,
    MindMapState mm, {
    required int depth,
    required Set<String> visited,
  }) {
    final children = childMap[parentId] ?? [];
    final widgets = <Widget>[];
    for (final childId in children) {
      if (visited.contains(childId)) continue;
      visited.add(childId);
      final hasKids = childMap.containsKey(childId);
      widgets.add(_SidebarRow(
        nodeId: childId,
        label: _nodeLabel(childId, mm),
        type: (mm.nodeContent[childId]?['type'] as String?) ?? 'node',
        depth: depth,
        hidden: mm.hidden.contains(childId),
        expanded: _expandedIds.contains(childId),
        hasChildren: hasKids,
        onToggleExpand: hasKids
            ? () => setState(() {
                _expandedIds.contains(childId)
                    ? _expandedIds.remove(childId)
                    : _expandedIds.add(childId);
              })
            : null,
        onToggleHide: () => widget.onToggleHide(childId),
        onFocus: () => widget.onFocusNode(childId),
      ));
      if (_expandedIds.contains(childId)) {
        widgets.addAll(_buildSubtree(childId, childMap, mm,
            depth: depth + 1, visited: visited));
      }
    }
    return widgets;
  }

  String _nodeLabel(String id, MindMapState mm) {
    final content = mm.nodeContent[id] ?? {};
    final name = content['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    // Fallback: extract type prefix from id
    final i = id.indexOf(':');
    return i > 0 ? id.substring(0, i) : id;
  }

  void _collectIds(String id, Map<String, List<String>> childMap, Set<String> result) {
    final children = childMap[id];
    if (children == null) return;
    for (final String child in children) {
      if (result.add(child)) {
        _collectIds(child, childMap, result);
      }
    }
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.nodeId,
    required this.label,
    required this.type,
    required this.depth,
    required this.hidden,
    required this.expanded,
    required this.hasChildren,
    this.onToggleExpand,
    required this.onToggleHide,
    required this.onFocus,
  });
  final String nodeId;
  final String label;
  final String type;
  final int depth;
  final bool hidden;
  final bool expanded;
  final bool hasChildren;
  final VoidCallback? onToggleExpand;
  final VoidCallback onToggleHide;
  final VoidCallback onFocus;

  static const _typeIcons = <String, IconData>{
    'workspace': Icons.folder_special,
    'agent':     Icons.smart_toy,
    'session':   Icons.terminal,
    'repo':      Icons.source,
    'branch':    Icons.fork_right,
    'run':       Icons.play_circle,
    'files':     Icons.insert_drive_file,
    'tree':      Icons.account_tree,
    'diff':      Icons.difference,
    'editor':    Icons.code,
  };

  static const _typeColors = <String, Color>{
    'workspace': Color(0xFF7C3AED),
    'agent':     Color(0xFF34D399),
    'session':   Color(0xFF93C5FD),
    'repo':      Color(0xFF94A3B8),
    'branch':    Color(0xFF60A5FA),
    'run':       Color(0xFFF87171),
    'files':     Color(0xFFF59E0B),
    'tree':      Color(0xFF10B981),
    'diff':      Color(0xFF7C6BFF),
    'editor':    Color(0xFFE879F9),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[type] ?? Icons.circle;
    final color = _typeColors[type] ?? const Color(0xFF64748B);

    return InkWell(
      onTap: onFocus,
      child: Padding(
        padding: EdgeInsets.only(left: 8.0 + depth * 14.0, right: 4, top: 2, bottom: 2),
        child: Row(
          children: [
            // Expand/collapse arrow
            if (hasChildren)
              GestureDetector(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: const Color(0xFF6B7898),
                  ),
                ),
              )
            else
              const SizedBox(width: 16),
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: hidden ? const Color(0xFF3D4A6B) : const Color(0xFFCBD5E1),
                  decoration: hidden ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // Eye toggle
            GestureDetector(
              onTap: onToggleHide,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hidden ? Icons.visibility_off : Icons.visibility,
                  size: 12,
                  color: hidden ? const Color(0xFF3D4A6B) : const Color(0xFF6B7898),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Connectors painter ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

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
      final fp = state.positions[conn.fromId];
      final tp2 = state.positions[conn.toId];
      if (fp == null || tp2 == null) continue;
      final fsz = state.sizes[conn.fromId] ?? const Size(220, 160);
      final tsz = state.sizes[conn.toId] ?? const Size(220, 160);

      final start = Offset(fp.dx + fsz.width, fp.dy + fsz.height / 2);
      final end = Offset(tp2.dx, tp2.dy + tsz.height / 2);
      final mid = (end.dx - start.dx) / 2;

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx + mid, start.dy,
                    end.dx - mid, end.dy,
                    end.dx, end.dy),
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
    const base = 30.0;
    final step = base * scale;
    if (step < 4) return;

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
