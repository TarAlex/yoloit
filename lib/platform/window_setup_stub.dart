// Web / non-desktop stub — window_manager is not available.
Future<void> initWindow() async {}

// Stub WindowListener for web
mixin WindowListener {}

class WindowManagerStub {
  static bool get isDesktop => false;
}
