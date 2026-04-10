import 'package:shared_preferences/shared_preferences.dart';

/// Persists UI session state across app restarts:
/// - Panel visibility / sizes
/// - Editor & terminal font sizes (zoom)
/// - Last active terminal session index
class SessionPrefs {
  SessionPrefs._();

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kReviewVisible      = 'session.reviewVisible';
  static const _kTerminalVisible    = 'session.terminalVisible';
  static const _kWorkspaceWidth     = 'session.workspaceWidth';
  static const _kEditorWidth        = 'session.editorWidth';
  static const _kReviewWidth        = 'session.reviewWidth';
  static const _kAgentsHeight       = 'session.agentsHeight';
  static const _kEditorHeight       = 'session.editorHeight';
  static const _kReviewHeight       = 'session.reviewHeight';
  static const _kEditorFontSize     = 'session.editorFontSize';
  static const _kTerminalFontSize   = 'session.terminalFontSize';
  static const _kActiveTerminalIdx  = 'session.activeTerminalIndex';

  // ── Load ─────────────────────────────────────────────────────────────────
  static Future<SessionSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    return SessionSnapshot(
      reviewVisible:     p.getBool(_kReviewVisible)     ?? true,
      terminalVisible:   p.getBool(_kTerminalVisible)   ?? true,
      workspaceWidth:    p.getDouble(_kWorkspaceWidth)  ?? 220.0,
      editorWidth:       p.getDouble(_kEditorWidth)     ?? 480.0,
      reviewWidth:       p.getDouble(_kReviewWidth)     ?? 260.0,
      agentsHeight:      p.getDouble(_kAgentsHeight),
      editorHeight:      p.getDouble(_kEditorHeight),
      reviewHeight:      p.getDouble(_kReviewHeight),
      editorFontSize:    p.getDouble(_kEditorFontSize)  ?? 13.0,
      terminalFontSize:  p.getDouble(_kTerminalFontSize) ?? 13.0,
      activeTerminalIdx: p.getInt(_kActiveTerminalIdx)  ?? 0,
    );
  }

  // ── Save helpers (individual fields for low-overhead writes) ─────────────
  static Future<void> saveReviewVisible(bool v)      async => (await _p()).setBool(_kReviewVisible, v);
  static Future<void> saveTerminalVisible(bool v)    async => (await _p()).setBool(_kTerminalVisible, v);
  static Future<void> saveWorkspaceWidth(double v)   async => (await _p()).setDouble(_kWorkspaceWidth, v);
  static Future<void> saveEditorWidth(double v)      async => (await _p()).setDouble(_kEditorWidth, v);
  static Future<void> saveReviewWidth(double v)      async => (await _p()).setDouble(_kReviewWidth, v);
  static Future<void> saveAgentsHeight(double? v)    async { final p = await _p(); v == null ? p.remove(_kAgentsHeight) : p.setDouble(_kAgentsHeight, v); }
  static Future<void> saveEditorHeight(double? v)    async { final p = await _p(); v == null ? p.remove(_kEditorHeight) : p.setDouble(_kEditorHeight, v); }
  static Future<void> saveReviewHeight(double? v)    async { final p = await _p(); v == null ? p.remove(_kReviewHeight) : p.setDouble(_kReviewHeight, v); }
  static Future<void> saveEditorFontSize(double v)   async => (await _p()).setDouble(_kEditorFontSize, v);
  static Future<void> saveTerminalFontSize(double v) async => (await _p()).setDouble(_kTerminalFontSize, v);
  static Future<void> saveActiveTerminalIdx(int v)   async => (await _p()).setInt(_kActiveTerminalIdx, v);

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
}

/// Immutable snapshot of persisted session state.
class SessionSnapshot {
  const SessionSnapshot({
    required this.reviewVisible,
    required this.terminalVisible,
    required this.workspaceWidth,
    required this.editorWidth,
    required this.reviewWidth,
    this.agentsHeight,
    this.editorHeight,
    this.reviewHeight,
    required this.editorFontSize,
    required this.terminalFontSize,
    required this.activeTerminalIdx,
  });

  final bool reviewVisible;
  final bool terminalVisible;
  final double workspaceWidth;
  final double editorWidth;
  final double reviewWidth;
  final double? agentsHeight;
  final double? editorHeight;
  final double? reviewHeight;
  final double editorFontSize;
  final double terminalFontSize;
  final int activeTerminalIdx;
}
