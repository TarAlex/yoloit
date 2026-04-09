import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yoloit/core/hotkeys/hotkeys.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/review/ui/review_panel.dart';
import 'package:yoloit/features/settings/ui/settings_page.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/ui/terminal_panel.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
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
  bool _reviewVisible = false;

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
    return Shortcuts(
      shortcuts: yoloitShortcuts,
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
          ToggleWorkspacePanelIntent:
              CallbackAction<ToggleWorkspacePanelIntent>(
            onInvoke: (_) => _splitController.toggleLeft(),
          ),
          ToggleReviewPanelIntent: CallbackAction<ToggleReviewPanelIntent>(
            onInvoke: (_) {
              setState(() => _reviewVisible = !_reviewVisible);
            },
          ),
          FocusTerminalIntent: CallbackAction<FocusTerminalIntent>(
            onInvoke: (_) => _terminalFocusNode.requestFocus(),
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) => SettingsPage.show(context),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _TitleBar(
                  splitController: _splitController,
                  onSettings: () => SettingsPage.show(context),
                  reviewVisible: _reviewVisible,
                  onToggleReview: () => setState(() => _reviewVisible = !_reviewVisible),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Main layout: workspace panel + terminal (no right split)
                      HSplitView(
                        left: const WorkspacePanel(),
                        center: Focus(
                          focusNode: _terminalFocusNode,
                          child: const TerminalPanel(),
                        ),
                        right: const SizedBox.shrink(),
                        initialLeftWidth: 260,
                        initialRightWidth: 0,
                        controller: _splitController,
                      ),
                      // Review panel slides in from the right as overlay
                      AnimatedSlide(
                        offset: _reviewVisible ? Offset.zero : const Offset(1, 0),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 420,
                            child: Material(
                              elevation: 16,
                              shadowColor: Colors.black54,
                              child: const ReviewPanel(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatefulWidget {
  const _TitleBar({
    required this.splitController,
    required this.onSettings,
    required this.reviewVisible,
    required this.onToggleReview,
  });
  final HSplitViewController splitController;
  final VoidCallback onSettings;
  final bool reviewVisible;
  final VoidCallback onToggleReview;

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
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 36,
        color: AppColors.surface,
        child: Row(
          children: [
            const SizedBox(width: 72), // space for macOS traffic lights
            // Panel toggle buttons
            _PanelToggleButton(
              icon: Icons.view_sidebar,
              tooltip: 'Toggle Workspaces (⌘\\)',
              semanticsLabel: 'Toggle left panel',
              active: widget.splitController.leftVisible,
              onTap: widget.splitController.toggleLeft,
            ),
            const Spacer(),
            const Text(
              'yoloit — AI Orchestrator',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            _PanelToggleButton(
              icon: Icons.rate_review,
              tooltip: 'Toggle Review Panel (⌘⇧\\)',
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
                  ? AppColors.primary.withAlpha(40)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 14,
              color: active ? AppColors.primary : AppColors.textMuted,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
