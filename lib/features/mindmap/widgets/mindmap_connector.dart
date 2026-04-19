import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

/// Paints bezier connector curves between mind-map nodes.
class MindMapConnectorPainter extends CustomPainter {
  MindMapConnectorPainter({
    required this.connections,
    required this.positions,
    required this.sizes,
    required this.defaultSizes,
    required this.dashAnimation, // 0..1, drives flowing dash offset
  }) : super(repaint: dashAnimation);

  final List<MindMapConnection> connections;
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Map<String, Size> defaultSizes;
  final Animation<double> dashAnimation;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final conn in connections) {
      final fromPos  = positions[conn.fromId];
      final toPos    = positions[conn.toId];
      if (fromPos == null || toPos == null) continue;

      final fromSize = sizes[conn.fromId] ?? defaultSizes[conn.fromId] ?? const Size(200, 80);
      final toSize   = sizes[conn.toId]   ?? defaultSizes[conn.toId]   ?? const Size(200, 80);

      // Exit from right-center of source node, enter left-center of target node.
      final x1 = fromPos.dx + fromSize.width;
      final y1 = fromPos.dy + fromSize.height / 2;
      final x2 = toPos.dx;
      final y2 = toPos.dy + toSize.height / 2;

      final bend = math.max(40.0, (x2 - x1).abs() * 0.45);

      final path = Path()
        ..moveTo(x1, y1)
        ..cubicTo(x1 + bend, y1, x2 - bend, y2, x2, y2);

      final paint = _paintFor(conn);
      canvas.drawPath(path, paint);
    }
  }

  Paint _paintFor(MindMapConnection conn) {
    final paint = Paint()
      ..color = conn.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    switch (conn.style) {
      case ConnectorStyle.solid:
        break; // no dash

      case ConnectorStyle.dashed:
        // Static dash pattern — draw manually below.
        paint.strokeWidth = 1.5;
        // Flutter Paint doesn't support dash intervals natively;
        // we use PathMetrics in the real draw pass (handled via _drawDashed).
        break;

      case ConnectorStyle.animated:
        // Same as dashed but with animated offset.
        break;
    }

    return paint;
  }

  @override
  bool shouldRepaint(MindMapConnectorPainter old) =>
      old.positions != positions ||
      old.sizes != sizes ||
      old.connections != connections;
}

/// Widget wrapper that handles dash drawing with PathMetrics.
class MindMapConnectorLayer extends StatelessWidget {
  const MindMapConnectorLayer({
    super.key,
    required this.connections,
    required this.positions,
    required this.sizes,
    required this.defaultSizes,
    required this.dashAnimation,
  });

  final List<MindMapConnection> connections;
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Map<String, Size> defaultSizes;
  final Animation<double> dashAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dashAnimation,
      builder: (_, __) => CustomPaint(
        painter: _DashConnectorPainter(
          connections:  connections,
          positions:    positions,
          sizes:        sizes,
          defaultSizes: defaultSizes,
          animOffset:   dashAnimation.value,
        ),
      ),
    );
  }
}

class _DashConnectorPainter extends CustomPainter {
  const _DashConnectorPainter({
    required this.connections,
    required this.positions,
    required this.sizes,
    required this.defaultSizes,
    required this.animOffset,
  });

  final List<MindMapConnection> connections;
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Map<String, Size> defaultSizes;
  final double animOffset;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final conn in connections) {
      final fromPos = positions[conn.fromId];
      final toPos   = positions[conn.toId];
      if (fromPos == null || toPos == null) continue;

      final fromSize = sizes[conn.fromId] ?? defaultSizes[conn.fromId] ?? const Size(200, 80);
      final toSize   = sizes[conn.toId]   ?? defaultSizes[conn.toId]   ?? const Size(200, 80);

      final x1 = fromPos.dx + fromSize.width;
      final y1 = fromPos.dy + fromSize.height / 2;
      final x2 = toPos.dx;
      final y2 = toPos.dy + toSize.height / 2;
      final bend = math.max(40.0, (x2 - x1).abs() * 0.45);

      final path = Path()
        ..moveTo(x1, y1)
        ..cubicTo(x1 + bend, y1, x2 - bend, y2, x2, y2);

      final paint = Paint()
        ..color = conn.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      switch (conn.style) {
        case ConnectorStyle.solid:
          canvas.drawPath(path, paint);

        case ConnectorStyle.dashed:
          _drawDashed(canvas, path, paint, 5, 4, 0);

        case ConnectorStyle.animated:
          // Flowing: dash offset animates 0..18 (dash 5 + gap 4 = 9 * 2 = 18)
          final offset = animOffset * 18;
          _drawDashed(canvas, path, paint, 5, 4, offset);
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLen,
    double gapLen,
    double startOffset,
  ) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = startOffset % (dashLen + gapLen);
      // If we started mid-gap, skip to next dash start.
      if (distance > dashLen) distance = distance - (dashLen + gapLen);
      while (distance < metric.length) {
        final start = math.max(0.0, distance);
        final end   = math.min(distance + dashLen, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashConnectorPainter old) =>
      old.animOffset != animOffset ||
      old.positions != positions ||
      old.sizes != sizes ||
      old.connections != connections;
}
