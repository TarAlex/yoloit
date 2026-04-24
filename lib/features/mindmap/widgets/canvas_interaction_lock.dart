import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Global signal that disables canvas pan while the pointer is inside a
/// scrollable card body (terminal, file tree, editor, diff). This way a
/// two-finger pan over the terminal scrolls the terminal's scrollback,
/// not the infinite canvas underneath.
class CanvasInteractionLock {
  CanvasInteractionLock._();
  static final instance = CanvasInteractionLock._();

  /// Number of active scrollable regions that currently own the pointer.
  /// A counter (not a bool) tolerates overlapping MouseRegions and fast
  /// enter/exit events during drags.
  final ValueNotifier<int> _count = ValueNotifier<int>(0);

  ValueListenable<int> get activeCount => _count;

  bool get isLocked => _count.value > 0;

  void enter() => _count.value = _count.value + 1;
  void exit() {
    if (_count.value > 0) _count.value = _count.value - 1;
  }
}

/// Wraps a scrollable widget so that while the pointer is over it, the
/// mindmap canvas pan is disabled. The wrapped widget can freely consume
/// wheel / two-finger scroll / drag gestures.
class ScrollableCardRegion extends StatefulWidget {
  const ScrollableCardRegion({super.key, required this.child});
  final Widget child;

  @override
  State<ScrollableCardRegion> createState() => _ScrollableCardRegionState();
}

class _ScrollableCardRegionState extends State<ScrollableCardRegion> {
  bool _entered = false;

  @override
  void dispose() {
    if (_entered) {
      CanvasInteractionLock.instance.exit();
      _entered = false;
    }
    super.dispose();
  }

  void _enter(PointerEnterEvent _) {
    if (_entered) return;
    _entered = true;
    CanvasInteractionLock.instance.enter();
  }

  void _exit(PointerExitEvent _) {
    if (!_entered) return;
    _entered = false;
    CanvasInteractionLock.instance.exit();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _enter,
      onExit: _exit,
      opaque: false,
      child: widget.child,
    );
  }
}

/// A leaf-ish marker inserted into the widget tree around each mindmap card.
///
/// The web canvas uses [WidgetsBinding.hitTestInView] at gesture start to
/// walk the hit path and look for a [RenderScrollableCardMarker]. If one is
/// present, the pointer is currently over a card and the canvas skips its
/// own pan/zoom handling so the card's inner scrollable can act.
///
/// This mechanism works for all pointer kinds (mouse, trackpad pan-zoom,
/// stylus) — unlike [MouseRegion], which only fires for mouse hover.
class ScrollableCardMarker extends SingleChildRenderObjectWidget {
  const ScrollableCardMarker({super.key, required Widget super.child});

  @override
  RenderScrollableCardMarker createRenderObject(BuildContext context) =>
      RenderScrollableCardMarker();
}

class RenderScrollableCardMarker extends RenderProxyBox {
  RenderScrollableCardMarker();
}


/// Prevents [showOnScreen] calls from inner widgets (e.g. autofocus on a
/// CodeField / TextField) from propagating to the [InteractiveViewer] canvas
/// and causing it to pan when an editor card switches tabs or opens.
///
/// Wrap each card's content area with this widget so that focus-driven
/// scroll requests are absorbed here and never reach the canvas transform.
class CanvasFocusScrollBlocker extends SingleChildRenderObjectWidget {
  const CanvasFocusScrollBlocker({super.key, required Widget super.child});

  @override
  RenderCanvasFocusScrollBlocker createRenderObject(BuildContext context) =>
      RenderCanvasFocusScrollBlocker();
}

class RenderCanvasFocusScrollBlocker extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // Intentionally swallow — do NOT propagate to parent (InteractiveViewer).
    // This stops autofocus / focus-change events from panning the canvas.
  }
}
