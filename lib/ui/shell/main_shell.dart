import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yoloit/core/hotkeys/hotkey_registry.dart';
import 'package:yoloit/core/hotkeys/hotkeys.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/editor/ui/file_editor_panel.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/runs/ui/run_panel.dart';
import 'package:yoloit/features/search/ui/file_search_overlay.dart';
import 'package:yoloit/features/settings/ui/settings_page.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/ui/workspace_panel.dart';
import 'package:yoloit/ui/widgets/split_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WindowListener {
  final _splitController = HSplitViewController();
  final _terminalFocusNode = FocusNode();
  bool _reviewVisible = true;
  bool _terminalVisible = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initCubits();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _splitController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _initCubits() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkspaceCubit>().load();
      context.read<TerminalCubit>().initialize();
    });
  }

  void _openFileSearch() {
    showFileSearch(
      context,
      onFileOpened: () {
        if (!_reviewVisible) setState(() => _reviewVisible = true);
      },
    );
  }

  void _previousTab() {
    final cubit = context.read<TerminalCubit>();
    final state = cubit.state;
    if (state is TerminalLoaded && state.sessions.isNotEmpty) {
      final prev = (state.activeIndex - 1 + state.sessions.length) % state.sessions.length;
      cubit.switchTab(prev);
    }
  }

  void _nextTab() {
    final cubit = context.read<TerminalCubit>();
    final state = cubit.state;
    if (state is TerminalLoaded && state.sessions.isNotEmpty) {
      final next = (state.activeIndex + 1) % state.sessions.length;
      cubit.switchTab(next);
    }
  }

  void _closeTab() {
    final cubit = context.read<TerminalCubit>();
    final state = cubit.state;
    if (state is TerminalLoaded && state.sessions.isNotEmpty) {
      final session = state.sessions[state.activeIndex];
      cubit.closeSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListenableBuilder(
      listenable: HotkeyRegistry.instance,
      builder: (context, _) => Shortcuts(
      shortcuts: HotkeyRegistry.instance.shortcuts,
      child: Actions(
        actions: {
          PreviousAgentTabIntent: CallbackAction<PreviousAgentTabIntent>(
            onInvoke: (_) => _previousTab(),
          ),
          NextAgentTabIntent: CallbackAction<NextAgentTabIntent>(
            onInvoke: (_) => _nextTab(),
          ),
          CloseTerminalTabIntent: CallbackAction<CloseTerminalTabIntent>(
            onInvoke: (_) => _closeTab(),
          ),
          ToggleWorkspacePanelIntent: CallbackAction<ToggleWorkspacePanelIntent>(
            onInvoke: (_) => _splitController.toggleLeft(),
          ),
          ToggleTerminalPanelIntent: CallbackAction<ToggleTerminalPanelIntent>(
            onInvoke: (_) {
              setState(() => _terminalVisible = !_terminalVisible);
              return null;
            },
          ),
          ToggleReviewPanelIntent: CallbackAction<ToggleReviewPanelIntent>(
            onInvoke: (_) {
              setState(() => _reviewVisible = !_reviewVisible);
              return null;
            },
          ),
          FocusTerminalIntent: CallbackAction<FocusTerminalIntent>(
            onInvoke: (_) => _terminalFocusNode.requestFocus(),
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) => SettingsPage.show(context),
          ),
          OpenFileSearchIntent: CallbackAction<OpenFileSearchIntent>(
            onInvoke: (_) => _openFileSearch(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colors.background,
            body: Column(
              children: [
                _TitleBar(
                  splitController: _splitController,
                  onSettings: () => SettingsPage.show(context),
                  reviewVisible: _reviewVisible,
                  terminalVisible: _terminalVisible,
                  onToggleReview: () => setState(() => _reviewVisible = !_reviewVisible),
                  onToggleTerminal: () => setState(() => _terminalVisible = !_terminalVisible),
                  onSearch: _openFileSearch,
                ),
                Expanded(
                  child: _FourPaneLayout(
                    splitController: _splitController,
                    terminalFocusNode: _terminalFocusNode,
                    reviewVisible: _reviewVisible,
                    terminalVisible: _terminalVisible,
                    onToggleReview: () => setState(() => _reviewVisible = !_reviewVisible),
                    onToggleTerminal: () => setState(() => _terminalVisible = !_terminalVisible),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ), // Shortcuts
    ); // ListenableBuilder
  }
}

/// 4-pane layout: [Workspace] [Terminal] [FileEditor?] [ReviewPanel?]
/// FileEditor appears when a file is open.
class _FourPaneLayout extends StatefulWidget {
  const _FourPaneLayout({
    required this.splitController,
    required this.terminalFocusNode,
    required this.reviewVisible,
    required this.terminalVisible,
    required this.onToggleReview,
    required this.onToggleTerminal,
  });

  final HSplitViewController splitController;
  final FocusNode terminalFocusNode;
  final bool reviewVisible;
  final bool terminalVisible;
  final VoidCallback onToggleReview;
  final VoidCallback onToggleTerminal;

  @override
  State<_FourPaneLayout> createState() => _FourPaneLayoutState();
}

class _FourPaneLayoutState extends State<_FourPaneLayout> {
  double _workspaceWidth = 260;
  double _editorWidth = 480;
  double _reviewWidth = 360;

  // Vertical heights (null = fill all available space)
  double? _agentsHeight;
  double? _editorHeight;
  double? _reviewHeight;

  static const _minWidth = 160.0;
  static const _minHeight = 120.0;


  @override
  void initState() {
    super.initState();
    widget.splitController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.splitController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileEditorCubit, FileEditorState>(
      builder: (context, editorState) {
        final showWorkspace = widget.splitController.leftVisible;
        final showTerminal = widget.terminalVisible;
        final showEditor = editorState.isVisible;
        final showReview = widget.reviewVisible;

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final totalHeight = constraints.maxHeight;

            return Row(
              children: [
                // ── Workspace panel ──────────────────────────────────────────
                if (showWorkspace) ...[
                  SizedBox(width: _workspaceWidth, child: const WorkspacePanel()),
                  _Divider(
                    onDrag: (dx) => setState(() {
                      _workspaceWidth = (_workspaceWidth + dx).clamp(_minWidth, totalWidth / 3);
                    }),
                  ),
                ],

                // ── Terminal/Agents (toggleable, fills remaining when visible) ─
                if (showTerminal)
                  _sizedOrExpanded(
                    width: null,
                    height: _agentsHeight,
                    child: Focus(
                      focusNode: widget.terminalFocusNode,
                      child: _PaneWrapper(
                        collapseTooltip: 'Collapse Agents',
                        onCollapse: widget.onToggleTerminal,
                        onVerticalDrag: (dy) => setState(() {
                          _agentsHeight = ((_agentsHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40);
                        }),
                        child: const _BottomPanel(),
                      ),
                    ),
                  ),

                // ── File Editor (when a file is open) ─────────────────────────
                if (showEditor) ...[
                  if (showTerminal)
                    _Divider(
                      onDrag: (dx) => setState(() {
                        _editorWidth = (_editorWidth - dx).clamp(_minWidth, totalWidth / 2);
                      }),
                    ),
                  if (showTerminal)
                    SizedBox(
                      width: _editorWidth,
                      child: _PaneWrapper(
                        collapseTooltip: 'Close Editor',
                        onCollapse: () => context.read<FileEditorCubit>().hidePanel(),
                        onVerticalDrag: (dy) => setState(() {
                          _editorHeight = ((_editorHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40);
                        }),
                        child: const FileEditorPanel(),
                      ),
                    )
                  else
                    Expanded(
                      child: _PaneWrapper(
                        collapseTooltip: 'Close Editor',
                        onCollapse: () => context.read<FileEditorCubit>().hidePanel(),
                        onVerticalDrag: (dy) => setState(() {
                          _editorHeight = ((_editorHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40);
                        }),
                        child: const FileEditorPanel(),
                      ),
                    ),
                ],

                // ── Review / File Tree ─────────────────────────────────────────
                if (showReview) ...[
                  _Divider(
                    onDrag: (dx) => setState(() {
                      _reviewWidth = (_reviewWidth - dx).clamp(_minWidth, totalWidth / 2);
                    }),
                  ),
                  SizedBox(
                    width: _reviewWidth,
                    child: _PaneWrapper(
                      collapseTooltip: 'Collapse Tree',
                      onCollapse: widget.onToggleReview,
                      onVerticalDrag: (dy) => setState(() {
                        _reviewHeight = ((_reviewHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40);
                      }),
                      child: const ReviewPanel(),
                    ),
                  ),
                ],

                // ── Fallback when only workspace (or nothing) is showing ───────
                if (!showTerminal && !showEditor && !showReview)
                  const Expanded(child: SizedBox.shrink()),
              ],
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Widget _sizedOrExpanded({required double? width, required double? height, required Widget child}) {
    if (width != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    return height != null ? SizedBox(height: height, child: Expanded(child: child)) : Expanded(child: child);
  }
}

enum _BottomTab { agents, runs }

/// Bottom panel that hosts the Agents terminal and Run panel with a tab bar.
class _BottomPanel extends StatefulWidget {
  const _BottomPanel();

  @override
  State<_BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<_BottomPanel> {
  _BottomTab _tab = _BottomTab.agents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWorkspace());
  }

  void _syncWorkspace() {
    final wsState = context.read<WorkspaceCubit>().state;
    if (wsState is WorkspaceLoaded && wsState.activeWorkspace != null) {
      context
          .read<RunCubit>()
          .loadForWorkspace(wsState.activeWorkspace!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocListener<WorkspaceCubit, WorkspaceState>(
      listener: (context, wsState) {
        if (wsState is WorkspaceLoaded && wsState.activeWorkspace != null) {
          context
              .read<RunCubit>()
              .loadForWorkspace(wsState.activeWorkspace!.path);
        }
      },
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 28,
            color: colors.surface,
            child: Row(
              children: [
                _BottomTabButton(
                  label: 'Agents',
                  icon: Icons.terminal,
                  isActive: _tab == _BottomTab.agents,
                  onTap: () => setState(() => _tab = _BottomTab.agents),
                ),
                _BottomTabButton(
                  label: 'Run',
                  icon: Icons.play_circle_outline,
                  isActive: _tab == _BottomTab.runs,
                  onTap: () => setState(() => _tab = _BottomTab.runs),
                ),
              ],
            ),
          ),
          Container(height: 1, color: colors.divider),
          Expanded(
            child: IndexedStack(
              index: _tab == _BottomTab.agents ? 0 : 1,
              children: const [
                TerminalPanel(),
                RunPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? colors.tabBorder : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isActive ? colors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color:
                    isActive ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin draggable divider between panes.
class _Divider extends StatefulWidget {
  const _Divider({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_Divider> createState() => _DividerState();
}

class _DividerState extends State<_Divider> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 4,
          color: _hovering ? colors.primary.withAlpha(120) : colors.divider,
        ),
      ),
    );
  }
}

/// Thin horizontal draggable divider at the bottom of a pane for vertical resize.
class _HorizontalDivider extends StatefulWidget {
  const _HorizontalDivider({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_HorizontalDivider> createState() => _HorizontalDividerState();
}

class _HorizontalDividerState extends State<_HorizontalDivider> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 4,
          color: _hovering ? colors.primary.withAlpha(120) : colors.divider,
        ),
      ),
    );
  }
}

/// Wraps a panel child with a top-right collapse button and an optional
/// bottom vertical resize handle.
class _PaneWrapper extends StatelessWidget {
  const _PaneWrapper({
    required this.child,
    required this.onCollapse,
    this.collapseTooltip = 'Collapse',
    this.onVerticalDrag,
  });

  final Widget child;
  final VoidCallback onCollapse;
  final String collapseTooltip;
  final ValueChanged<double>? onVerticalDrag;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: child),
              // Collapse button — top-right corner
              Positioned(
                top: 4,
                right: 4,
                child: Tooltip(
                  message: collapseTooltip,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: onCollapse,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated.withAlpha(200),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onVerticalDrag != null)
          _HorizontalDivider(onDrag: onVerticalDrag!),
      ],
    );
  }
}

class _TitleBar extends StatefulWidget {
  const _TitleBar({
    required this.splitController,
    required this.onSettings,
    required this.reviewVisible,
    required this.terminalVisible,
    required this.onToggleReview,
    required this.onToggleTerminal,
    required this.onSearch,
  });
  final HSplitViewController splitController;
  final VoidCallback onSettings;
  final bool reviewVisible;
  final bool terminalVisible;
  final VoidCallback onToggleReview;
  final VoidCallback onToggleTerminal;
  final VoidCallback onSearch;

  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> {
  @override
  void initState() {
    super.initState();
    widget.splitController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.splitController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        color: colors.surface,
        child: Row(
          children: [
            const SizedBox(width: 82), // space for macOS traffic lights + gap
            // Panel toggle buttons
            _PanelToggleButton(
              icon: Icons.view_sidebar,
              tooltip: 'Toggle Workspaces (⌘\\)',
              semanticsLabel: 'Toggle left panel',
              active: widget.splitController.leftVisible,
              onTap: widget.splitController.toggleLeft,
            ),
            const SizedBox(width: 4),
            _PanelToggleButton(
              icon: Icons.terminal,
              tooltip: 'Toggle Agents / Terminal (⌘T)',
              semanticsLabel: 'Toggle agents panel',
              active: widget.terminalVisible,
              onTap: widget.onToggleTerminal,
            ),
            const Spacer(),
            // Search button in center
            GestureDetector(
              onTap: widget.onSearch,
              child: Container(
                height: 22,
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text(
                      'Quick open…',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '⌘P / ⌘F',
                      style: TextStyle(color: AppColors.textMuted.withAlpha(120), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // File editor toggle
            BlocBuilder<FileEditorCubit, FileEditorState>(
              builder: (context, editorState) => _PanelToggleButton(
                icon: Icons.edit_document,
                tooltip: 'Toggle File Editor',
                semanticsLabel: 'Toggle file editor panel',
                active: editorState.isVisible,
                onTap: () => context.read<FileEditorCubit>().togglePanel(),
              ),
            ),
            const SizedBox(width: 4),
            _PanelToggleButton(
              icon: Icons.rate_review,
              tooltip: 'Toggle File Tree (⌘⇧\\)',
              semanticsLabel: 'Toggle right panel',
              active: widget.reviewVisible,
              onTap: widget.onToggleReview,
            ),
            const SizedBox(width: 4),
            _PanelToggleButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings (⌘,)',
              semanticsLabel: 'Open settings',
              active: false,
              onTap: widget.onSettings,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _PanelToggleButton extends StatelessWidget {
  const _PanelToggleButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: semanticsLabel ?? tooltip,
        button: true,
        toggled: active,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 24,
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withAlpha(40)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 14,
              color: active ? colors.primary : AppColors.textMuted,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
