import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xterm/xterm.dart' hide TerminalState;
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/clipboard_file_service.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';

class TerminalPanel extends StatelessWidget {
  const TerminalPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TerminalCubit, TerminalState>(
      builder: (context, state) {
        if (state is TerminalLoaded && state.sessions.isNotEmpty) {
          return _TerminalView(state: state);
        }
        return _EmptyTerminal();
      },
    );
  }
}

class _EmptyTerminal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.terminalBackground,
      child: Column(
        children: [
          const _TerminalHeader(sessions: [], activeIndex: 0),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.terminal_outlined, size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Agent Terminal',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open a workspace and start an AI agent to begin',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<WorkspaceCubit, WorkspaceState>(
                    builder: (context, wsState) {
                      final hasActive = wsState is WorkspaceLoaded &&
                          wsState.activeWorkspace != null;
                      if (!hasActive) {
                        return const Text(
                          'Select a workspace from the left panel first',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        );
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: AgentType.values.map((type) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _AgentLaunchButton(
                              type: type,
                              workspacePath: wsState.activeWorkspace!.path,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalView extends StatelessWidget {
  const _TerminalView({required this.state});
  final TerminalLoaded state;

  @override
  Widget build(BuildContext context) {
    final activeSession = state.activeSession;

    return Container(
      color: AppColors.terminalBackground,
      child: Column(
        children: [
          _TerminalHeader(sessions: state.sessions, activeIndex: state.activeIndex),
          if (activeSession != null) _SessionInfoBar(session: activeSession),
          Expanded(
            child: activeSession != null
                ? _TerminalWidget(key: ValueKey(activeSession.id), session: activeSession)
                : const SizedBox(),
          ),
          _TokenUsageBar(session: activeSession),
        ],
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({required this.sessions, required this.activeIndex});
  final List<AgentSession> sessions;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: const Text(
                'Agent Terminal',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, i) {
                final session = sessions[i];
                final isActive = i == activeIndex;
                return _AgentTab(
                  session: session,
                  isActive: isActive,
                  onTap: () => context.read<TerminalCubit>().switchTab(i),
                  onClose: () => context.read<TerminalCubit>().closeSession(session.id),
                );
              },
            ),
          ),
          BlocBuilder<WorkspaceCubit, WorkspaceState>(
            builder: (context, wsState) {
              if (wsState is WorkspaceLoaded && wsState.activeWorkspace != null) {
                return Row(
                  children: [
                    ...AgentType.values.map((type) => _AgentLaunchButton(
                          type: type,
                          workspacePath: wsState.activeWorkspace!.path,
                          compact: true,
                        )),
                    const SizedBox(width: 8),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
    );
  }
}

class _AgentTab extends StatefulWidget {
  const _AgentTab({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final AgentSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<_AgentTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isLive = session.status == AgentStatus.live;
    final statusColor =
        isLive ? AppColors.statusActive : AppColors.statusIdle;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.tabActiveBg
                : _hovering
                    ? AppColors.surfaceHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: AppColors.primary.withAlpha(80))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.type.iconLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.primaryLight),
              ),
              const SizedBox(width: 5),
              Text(
                session.displayName,
                style: TextStyle(
                  color: widget.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isLive ? 'Live' : 'Idle',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovering) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, size: 10, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionInfoBar extends StatelessWidget {
  const _SessionInfoBar({required this.session});
  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'yoloit > ',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            session.type.command,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            'Session ID: ${session.sessionId ?? '-'}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Mods: Orchestrate',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalWidget extends StatefulWidget {
  const _TerminalWidget({super.key, required this.session});
  final AgentSession session;

  @override
  State<_TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<_TerminalWidget> {
  final _controller = TerminalController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bindTerminal();
    _requestFocusAfterFrame();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void didUpdateWidget(_TerminalWidget old) {
    super.didUpdateWidget(old);
    if (old.session.id != widget.session.id) {
      old.session.terminal.onOutput = null;
      old.session.terminal.onResize = null;
      _bindTerminal();
      _requestFocusAfterFrame();
    }
  }

  void _requestFocusAfterFrame() {
    // endOfFrame is more reliable than addPostFrameCallback on macOS desktop
    // because it waits for the full render pipeline to settle.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _bindTerminal() {
    widget.session.terminal.onOutput = (data) {
      PtyService.instance.write(widget.session.id, data);
    };
    // Keep PTY size in sync with the xterm viewport so TUI apps render correctly.
    widget.session.terminal.onResize = (cols, rows, pixelWidth, pixelHeight) {
      PtyService.instance.resize(widget.session.id, cols, rows);
    };
  }

  /// Intercepts Cmd+V: saves clipboard content to a temp file and writes
  /// the file path into the terminal instead of pasting raw content.
  bool _handleHardwareKey(KeyEvent event) {
    if (!_focusNode.hasFocus) return false;
    if (event is! KeyDownEvent) return false;

    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isV = event.logicalKey == LogicalKeyboardKey.keyV;

    if (isCmd && isV) {
      _pasteAsFileRef();
      return true; // consumed — prevent TerminalView from doing a raw paste
    }
    return false;
  }

  Future<void> _pasteAsFileRef() async {
    final path = await ClipboardFileService.instance.saveClipboardToFile();
    if (path == null || !mounted) return;
    // Write the path directly into the PTY (no newline — user confirms with Enter).
    PtyService.instance.write(widget.session.id, path);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    widget.session.terminal.onOutput = null;
    widget.session.terminal.onResize = null;
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener fires on pointer-down (before gesture recognisers), giving
    // the most reliable focus request on macOS desktop.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!_focusNode.hasFocus) _focusNode.requestFocus();
      },
      child: TerminalView(
        widget.session.terminal,
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        theme: const TerminalTheme(
        cursor: Color(0xFF9D4EDD),
        selection: Color(0x449D4EDD),
        foreground: Color(0xFFCECEEE),
        background: Color(0xFF070714),
        black: Color(0xFF1A1A2E),
        red: Color(0xFFFF4F6A),
        green: Color(0xFF00FF9F),
        yellow: Color(0xFFFFD700),
        blue: Color(0xFF00B4FF),
        magenta: Color(0xFFB87FFF),
        cyan: Color(0xFF00E5FF),
        white: Color(0xFFCECEEE),
        brightBlack: Color(0xFF44446A),
        brightRed: Color(0xFFFF6B85),
        brightGreen: Color(0xFF4DFFBE),
        brightYellow: Color(0xFFFFE866),
        brightBlue: Color(0xFF33C5FF),
        brightMagenta: Color(0xFFCDA0FF),
        brightCyan: Color(0xFF33EEFF),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFFF9500),
        searchHitBackgroundCurrent: Color(0xFFFFB700),
        searchHitForeground: Color(0xFF000000),
      ),
      padding: const EdgeInsets.all(8),
    ),
    );
  }
}

class _AgentLaunchButton extends StatelessWidget {
  const _AgentLaunchButton({
    required this.type,
    required this.workspacePath,
    this.compact = false,
  });

  final AgentType type;
  final String workspacePath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Start ${type.displayName} session',
      child: GestureDetector(
        onTap: () => context.read<TerminalCubit>().spawnSession(
              type: type,
              workspacePath: workspacePath,
            ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type.iconLabel, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                type.displayName,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenUsageBar extends StatelessWidget {
  const _TokenUsageBar({this.session});
  final AgentSession? session;

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SizedBox();
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'token/request usage',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(
                value: 0.56,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Session Usage: — / 8000 tokens',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
