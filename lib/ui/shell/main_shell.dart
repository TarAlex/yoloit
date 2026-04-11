import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yoloit/core/hotkeys/hotkey_registry.dart';
import 'package:yoloit/core/hotkeys/hotkeys.dart';
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/editor/ui/file_editor_panel.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';
import 'package:yoloit/features/search/ui/file_search_overlay.dart';
import 'package:yoloit/features/settings/ui/settings_page.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/ui/workspace_panel.dart';
import 'package:yoloit/core/services/resource_monitor_service.dart';
import 'package:yoloit/ui/widgets/activity_rail.dart';
import 'package:yoloit/ui/widgets/panel_shell.dart';
import 'package:yoloit/ui/widgets/panel_visibility.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WindowListener {
  final _workspacePanelKey = GlobalKey<WorkspacePanelState>();
  final _terminalFocusNode = FocusNode();
  PanelVisibility _workspaceVis = PanelVisibility.open;
  PanelVisibility _agentsVis    = PanelVisibility.open;
  PanelVisibility _fileTreeVis  = PanelVisibility.open;
  SessionSnapshot? _sessionSnapshot;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadSessionAndInit();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSessionAndInit() async {
    final snap = await SessionPrefs.load();
    if (!mounted) return;
    setState(() {
      _workspaceVis    = snap.workspaceVis;
      _agentsVis       = snap.agentsVis;
      _fileTreeVis     = snap.fileTreeVis;
      _sessionSnapshot = snap;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize terminal services (no sessions yet — workspace listener will load them)
      context.read<TerminalCubit>().initialize();
      // Load workspaces — BlocListener in _BottomPanel will pick up active workspace
      context.read<WorkspaceCubit>().load();
      // Focus terminal after startup
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _terminalFocusNode.requestFocus();
      });
    });
  }

  void _openFileSearch() {
    showFileSearch(
      context,
      onFileOpened: () {
        if (_fileTreeVis == PanelVisibility.closed) {
          _setPanelVis('filetree', PanelVisibility.open);
        }
      },
    );
  }

  void _setPanelVis(String panelId, PanelVisibility v) {
    setState(() {
      switch (panelId) {
        case 'workspace':
          _workspaceVis = v;
        case 'agents':
          _agentsVis = v;
        case 'filetree':
          _fileTreeVis = v;
      }
    });
    SessionPrefs.savePanelVis(panelId, v);
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
            onInvoke: (_) {
              final next = _workspaceVis == PanelVisibility.open
                  ? PanelVisibility.closed
                  : PanelVisibility.open;
              _setPanelVis('workspace', next);
              return null;
            },
          ),
          ToggleTerminalPanelIntent: CallbackAction<ToggleTerminalPanelIntent>(
            onInvoke: (_) {
              final next = _agentsVis == PanelVisibility.open
                  ? PanelVisibility.closed
                  : PanelVisibility.open;
              _setPanelVis('agents', next);
              return null;
            },
          ),
          ToggleReviewPanelIntent: CallbackAction<ToggleReviewPanelIntent>(
            onInvoke: (_) {
              final next = _fileTreeVis == PanelVisibility.open
                  ? PanelVisibility.closed
                  : PanelVisibility.open;
              _setPanelVis('filetree', next);
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
                  onSettings: () => SettingsPage.show(context),
                  workspaceVis: _workspaceVis,
                  agentsVis: _agentsVis,
                  fileTreeVis: _fileTreeVis,
                  onToggleWorkspace: () {
                    final next = _workspaceVis == PanelVisibility.open
                        ? PanelVisibility.closed
                        : PanelVisibility.open;
                    _setPanelVis('workspace', next);
                  },
                  onToggleAgents: () {
                    final next = _agentsVis == PanelVisibility.open
                        ? PanelVisibility.closed
                        : PanelVisibility.open;
                    _setPanelVis('agents', next);
                  },
                  onToggleFileTree: () {
                    final next = _fileTreeVis == PanelVisibility.open
                        ? PanelVisibility.closed
                        : PanelVisibility.open;
                    _setPanelVis('filetree', next);
                  },
                  onSearch: _openFileSearch,
                ),
                Expanded(
                  child: _FourPaneLayout(
                    workspacePanelKey: _workspacePanelKey,
                    terminalFocusNode: _terminalFocusNode,
                    workspaceVis: _workspaceVis,
                    agentsVis: _agentsVis,
                    fileTreeVis: _fileTreeVis,
                    initialSnapshot: _sessionSnapshot,
                    onSetPanelVis: _setPanelVis,
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
    required this.workspacePanelKey,
    required this.terminalFocusNode,
    required this.workspaceVis,
    required this.agentsVis,
    required this.fileTreeVis,
    required this.onSetPanelVis,
    this.initialSnapshot,
  });

  final GlobalKey<WorkspacePanelState> workspacePanelKey;
  final FocusNode terminalFocusNode;
  final PanelVisibility workspaceVis;
  final PanelVisibility agentsVis;
  final PanelVisibility fileTreeVis;
  final void Function(String panelId, PanelVisibility v) onSetPanelVis;
  final SessionSnapshot? initialSnapshot;

  @override
  State<_FourPaneLayout> createState() => _FourPaneLayoutState();
}

class _FourPaneLayoutState extends State<_FourPaneLayout> {
  late double _workspaceWidth;
  late double _editorWidth;
  late double _reviewWidth;

  // Vertical heights (null = fill all available space)
  double? _agentsHeight;
  double? _editorHeight;
  double? _reviewHeight;

  static const _minWidth = 160.0;
  static const _minHeight = 120.0;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSnapshot;
    _workspaceWidth = s?.workspaceWidth ?? 260;
    _editorWidth    = s?.editorWidth    ?? 480;
    _reviewWidth    = s?.reviewWidth    ?? 360;
    _agentsHeight   = s?.agentsHeight;
    _editorHeight   = s?.editorHeight;
    _reviewHeight   = s?.reviewHeight;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileEditorCubit, FileEditorState>(
      builder: (context, editorState) {
        final showWorkspace = widget.workspaceVis == PanelVisibility.open;
        final workspaceCollapsed = widget.workspaceVis == PanelVisibility.collapsed;
        final showAgents = widget.agentsVis != PanelVisibility.closed;
        final showEditor = editorState.isVisible;
        final showFileTree = widget.fileTreeVis == PanelVisibility.open;
        final fileTreeCollapsed = widget.fileTreeVis == PanelVisibility.collapsed;

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final totalHeight = constraints.maxHeight;

            return Row(
              children: [
                // ── Left ActivityRail (workspace collapsed) ─────────────────
                if (workspaceCollapsed)
                  ActivityRail(
                    side: ActivityRailSide.left,
                    items: [
                      ActivityRailItem(
                        iconWidget: SvgPicture.asset('assets/images/yoloit_mark.svg'),
                        tooltip: 'Expand Workspaces',
                        onTap: () => widget.onSetPanelVis('workspace', PanelVisibility.open),
                      ),
                    ],
                  ),

                // ── Workspace panel ──────────────────────────────────────────
                if (showWorkspace) ...[
                  SizedBox(
                    width: _workspaceWidth,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF32327A), width: 2),
                        ),
                      ),
                      child: PanelShell(
                        title: 'WORKSPACES',
                        iconWidget: SvgPicture.asset(
                          'assets/images/yoloit_mark.svg',
                          colorFilter: const ColorFilter.mode(AppColors.textMuted, BlendMode.srcIn),
                        ),
                        actions: [
                          PanelActionBtn(
                            icon: Icons.add,
                            tooltip: 'Add workspace',
                            onTap: () => widget.workspacePanelKey.currentState?.addWorkspace(),
                          ),
                        ],
                        onCollapse: () => widget.onSetPanelVis('workspace', PanelVisibility.collapsed),
                        collapseIcon: Icons.keyboard_arrow_left,
                        onClose: () => widget.onSetPanelVis('workspace', PanelVisibility.closed),
                        child: WorkspacePanel(key: widget.workspacePanelKey),
                      ),
                    ),
                  ),
                  _Divider(
                    onDrag: (dx) {
                      setState(() => _workspaceWidth = (_workspaceWidth + dx).clamp(_minWidth, totalWidth / 3));
                      SessionPrefs.saveWorkspaceWidth(_workspaceWidth);
                    },
                  ),
                ],

                // ── Terminal/Agents ──────────────────────────────────────────
                if (showAgents)
                  _sizedOrExpanded(
                    width: null,
                    height: _agentsHeight,
                    child: Focus(
                      focusNode: widget.terminalFocusNode,
                      child: Column(
                        children: [
                          Expanded(
                            child: PanelShell(
                              title: 'AGENTS',
                              icon: Icons.terminal,
                              onClose: () => widget.onSetPanelVis('agents', PanelVisibility.closed),
                              child: const _AgentsContent(),
                            ),
                          ),
                          _HorizontalDivider(onDrag: (dy) {
                            setState(() => _agentsHeight = ((_agentsHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40));
                            SessionPrefs.saveAgentsHeight(_agentsHeight);
                          }),
                        ],
                      ),
                    ),
                  ),

                // ── File Editor (when a file is open) ─────────────────────────
                if (showEditor) ...[
                  if (showAgents)
                    _Divider(
                      onDrag: (dx) {
                        setState(() => _editorWidth = (_editorWidth - dx).clamp(_minWidth, totalWidth / 2));
                        SessionPrefs.saveEditorWidth(_editorWidth);
                      },
                    ),
                  if (showAgents)
                    SizedBox(
                      width: _editorWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: PanelShell(
                              title: 'EDITOR',
                              icon: Icons.code,
                              onClose: () => context.read<FileEditorCubit>().hidePanel(),
                              child: const FileEditorPanel(),
                            ),
                          ),
                          _HorizontalDivider(onDrag: (dy) {
                            setState(() => _editorHeight = ((_editorHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40));
                            SessionPrefs.saveEditorHeight(_editorHeight);
                          }),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: PanelShell(
                              title: 'EDITOR',
                              icon: Icons.code,
                              onClose: () => context.read<FileEditorCubit>().hidePanel(),
                              child: const FileEditorPanel(),
                            ),
                          ),
                          _HorizontalDivider(onDrag: (dy) {
                            setState(() => _editorHeight = ((_editorHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40));
                            SessionPrefs.saveEditorHeight(_editorHeight);
                          }),
                        ],
                      ),
                    ),
                ],

                // ── Review / File Tree ─────────────────────────────────────────
                if (showFileTree) ...[
                  _Divider(
                    onDrag: (dx) {
                      setState(() => _reviewWidth = (_reviewWidth - dx).clamp(_minWidth, totalWidth / 2));
                      SessionPrefs.saveReviewWidth(_reviewWidth);
                    },
                  ),
                  SizedBox(
                    width: _reviewWidth,
                    child: Column(
                      children: [
                        Expanded(
                          child: PanelShell(
                            title: 'FILE TREE',
                            icon: Icons.account_tree,
                            onCollapse: () => widget.onSetPanelVis('filetree', PanelVisibility.collapsed),
                            collapseIcon: Icons.keyboard_arrow_right,
                            onClose: () => widget.onSetPanelVis('filetree', PanelVisibility.closed),
                            child: const ReviewPanel(),
                          ),
                        ),
                        _HorizontalDivider(onDrag: (dy) {
                          setState(() => _reviewHeight = ((_reviewHeight ?? totalHeight) + dy).clamp(_minHeight, totalHeight - 40));
                          SessionPrefs.saveReviewHeight(_reviewHeight);
                        }),
                      ],
                    ),
                  ),
                ],

                // ── Right ActivityRail (file tree collapsed) ─────────────────
                if (fileTreeCollapsed)
                  ActivityRail(
                    side: ActivityRailSide.right,
                    items: [
                      ActivityRailItem(
                        icon: Icons.account_tree,
                        tooltip: 'Expand File Tree',
                        onTap: () => widget.onSetPanelVis('filetree', PanelVisibility.open),
                      ),
                    ],
                  ),

                // ── Fallback when only workspace (or nothing) is showing ───────
                if (!showAgents && !showEditor && !showFileTree && !fileTreeCollapsed)
                  const Expanded(child: SizedBox.shrink()),
              ],
            );
          },
        );
      },
    );
  }
  Widget _sizedOrExpanded({required double? width, required double? height, required Widget child}) {
    if (width != null) {
      return SizedBox(width: width, height: height, child: child);
    }
    return height != null ? SizedBox(height: height, child: Expanded(child: child)) : Expanded(child: child);
  }
}

/// Content of the Agents panel: listens to workspace changes and hosts TerminalPanel.
class _AgentsContent extends StatelessWidget {
  const _AgentsContent();

  @override
  Widget build(BuildContext context) {
    return BlocListener<WorkspaceCubit, WorkspaceState>(
      listenWhen: (prev, curr) {
        if (curr is! WorkspaceLoaded) return false;
        if (prev is! WorkspaceLoaded) return true;
        return prev.activeWorkspaceId != curr.activeWorkspaceId &&
            curr.activeWorkspaceId != null;
      },
      listener: (context, state) {
        if (state is! WorkspaceLoaded) return;
        final wsId = state.activeWorkspaceId;
        if (wsId == null) return;
        final ws = state.workspaces.firstWhere(
          (w) => w.id == wsId,
          orElse: () => state.workspaces.first,
        );
        context.read<TerminalCubit>().setActiveWorkspace(
          workspaceId: wsId,
          workspacePath: ws.workspaceDir,
        );
        context.read<RunCubit>().loadForWorkspace(ws.path);
        context.read<ReviewCubit>().loadWorkspace(ws.paths);
      },
      child: const TerminalPanel(),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.label,
    required this.icon,
    required this.isActive,
  });

  final String label;
  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedContainer(
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

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.onSettings,
    required this.workspaceVis,
    required this.agentsVis,
    required this.fileTreeVis,
    required this.onToggleWorkspace,
    required this.onToggleAgents,
    required this.onToggleFileTree,
    required this.onSearch,
  });
  final VoidCallback onSettings;
  final PanelVisibility workspaceVis;
  final PanelVisibility agentsVis;
  final PanelVisibility fileTreeVis;
  final VoidCallback onToggleWorkspace;
  final VoidCallback onToggleAgents;
  final VoidCallback onToggleFileTree;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 44,
        color: colors.surface,
        child: Row(
          children: [
            const SizedBox(width: 82), // space for macOS traffic lights + gap
            // Panel toggle buttons
            _PanelToggleButton(
              icon: Icons.view_sidebar,
              tooltip: 'Toggle Workspaces (⌘\\)',
              semanticsLabel: 'Toggle left panel',
              active: workspaceVis == PanelVisibility.open,
              onTap: onToggleWorkspace,
            ),
            const SizedBox(width: 4),
            _PanelToggleButton(
              icon: Icons.terminal,
              tooltip: 'Toggle Agents / Terminal (⌘T)',
              semanticsLabel: 'Toggle agents panel',
              active: agentsVis == PanelVisibility.open,
              onTap: onToggleAgents,
            ),
            const Spacer(),
            // Search button in center
            GestureDetector(
              onTap: onSearch,
              child: Container(
                height: 26,
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
                    const Icon(Icons.search, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text(
                      'Quick open…',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '⌘O',
                      style: TextStyle(color: AppColors.textMuted.withAlpha(120), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Resource monitor chip
            const _ResourceChip(),
            const SizedBox(width: 8),
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
              active: fileTreeVis == PanelVisibility.open,
              onTap: onToggleFileTree,
            ),
            const SizedBox(width: 4),
            _PanelToggleButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings (⌘,)',
              semanticsLabel: 'Open settings',
              active: false,
              onTap: onSettings,
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
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withAlpha(40)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 16,
              color: active ? colors.primary : AppColors.textMuted,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Resource Monitor Chip ────────────────────────────────────────────────────

class _ResourceChip extends StatefulWidget {
  const _ResourceChip();

  @override
  State<_ResourceChip> createState() => _ResourceChipState();
}

class _ResourceChipState extends State<_ResourceChip> {
  ResourceSnapshot _snap = ResourceMonitorService.instance.current;
  late final _sub = ResourceMonitorService.instance.stream
      .listen((s) => setState(() => _snap = s));

  OverlayEntry? _overlay;

  @override
  void dispose() {
    _sub.cancel();
    _overlay?.remove();
    super.dispose();
  }

  void _toggle(BuildContext context) {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(builder: (_) => _ResourcePanel(
      snapshot: _snap,
      position: Offset(offset.dx - 260 + box.size.width, offset.dy + box.size.height + 4),
      onClose: () { _overlay?.remove(); _overlay = null; },
    ));
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final mem = formatBytes(_snap.appMemoryBytes);
    final cpu = _snap.appCpuPercent;
    return GestureDetector(
      onTap: () => _toggle(context),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF32327A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory, size: 11, color: Color(0xFF7C7CFF)),
            const SizedBox(width: 4),
            Text(
              cpu > 0 ? '${cpu.toStringAsFixed(1)}%  $mem' : mem,
              style: const TextStyle(
                color: Color(0xFFB0B0D0),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcePanel extends StatefulWidget {
  const _ResourcePanel({
    required this.snapshot,
    required this.position,
    required this.onClose,
  });
  final ResourceSnapshot snapshot;
  final Offset position;
  final VoidCallback onClose;

  @override
  State<_ResourcePanel> createState() => _ResourcePanelState();
}

class _ResourcePanelState extends State<_ResourcePanel> {
  late ResourceSnapshot _snap = widget.snapshot;
  late final _sub = ResourceMonitorService.instance.stream
      .listen((s) => setState(() => _snap = s));

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-outside to close
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: widget.position.dx,
          top: widget.position.dy,
          width: 280,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16163A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF32327A)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 16)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.monitor_heart_outlined, size: 13, color: Color(0xFF7C7CFF)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'RESOURCE USAGE',
                            style: TextStyle(
                              color: Color(0xFFE0E0F0),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Icon(Icons.close, size: 12, color: Color(0xFF6060A0)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF32327A)),
                  // Summary row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        _StatCell(label: 'CPU', value: '${_snap.appCpuPercent.toStringAsFixed(1)}%'),
                        _StatCell(label: 'APP RAM', value: formatBytes(_snap.appMemoryBytes)),
                        if (_snap.totalSystemMemoryBytes > 0)
                          _StatCell(
                            label: 'RAM %',
                            value: '${(_snap.appMemoryBytes / _snap.totalSystemMemoryBytes * 100).toStringAsFixed(1)}%',
                          ),
                      ],
                    ),
                  ),
                  if (_snap.agents.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0xFF32327A)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: const Text(
                        'AGENTS & TOOLS',
                        style: TextStyle(color: Color(0xFF6060A0), fontSize: 9, letterSpacing: 0.8),
                      ),
                    ),
                    ..._snap.agents.map((a) => _ProcessRow(stat: a)),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6060A0), fontSize: 9, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Color(0xFFE0E0F0), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.stat});
  final ProcessStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 5, color: Color(0xFF7C7CFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stat.name,
              style: const TextStyle(color: Color(0xFFB0B0D0), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${stat.cpuPercent.toStringAsFixed(1)}%',
            style: const TextStyle(color: Color(0xFF8080B0), fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              formatBytes(stat.memoryBytes),
              style: const TextStyle(color: Color(0xFF8080B0), fontSize: 10, fontFamily: 'monospace'),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
