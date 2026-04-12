import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:xterm/xterm.dart' hide TerminalState;
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/clipboard_file_service.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/data/worktree_service.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';
import 'package:yoloit/features/workspaces/models/worktree_model.dart';
import 'package:yoloit/features/workspaces/ui/new_agent_session_dialog.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';

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
    final colors = context.appColors;
    return Container(
      color: colors.terminalBackground,
      child: Column(
        children: [
          const _TerminalHeader(sessions: [], activeIndex: 0),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.terminal_outlined, size: 32, color: colors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI Agents',
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
                              workspacePath: wsState.activeWorkspace!.workspaceDir,
                              workspaceId: wsState.activeWorkspace!.id,
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
    final colors = context.appColors;
    final activeSession = state.activeSession;

    return Container(
      color: colors.terminalBackground,
      child: Column(
        children: [
          _TerminalHeader(sessions: state.sessions, activeIndex: state.activeIndex),
          if (activeSession != null) _SessionInfoBar(session: activeSession),
          Expanded(
            child: activeSession != null
                ? _TerminalWidget(key: ValueKey(activeSession.id), session: activeSession)
                : const SizedBox(),
          ),
          _WorkspaceStatusBar(session: activeSession),
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
    final colors = context.appColors;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: const Color(0xFF32327A), width: 1)),
      ),
      child: Row(
        children: [
          // Scrollable session tabs — takes all available space
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              padding: const EdgeInsets.only(left: 4, right: 4),
              itemBuilder: (context, i) {
                final session = sessions[i];
                final isActive = i == activeIndex;
                return _AgentTab(
                  session: session,
                  isActive: isActive,
                  onTap: () => context.read<TerminalCubit>().switchTab(i),
                  onClose: () => context.read<TerminalCubit>().closeSession(session.id),
                  onRename: (name) => context.read<TerminalCubit>().renameSession(session.id, name),
                );
              },
            ),
          ),
          // "+" button to launch a new agent session
          BlocBuilder<WorkspaceCubit, WorkspaceState>(
            builder: (context, wsState) {
              final workspace = wsState is WorkspaceLoaded ? wsState.activeWorkspace : null;
              if (workspace == null) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: colors.border)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _AddSessionButton(workspace: workspace),
              );
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
    required this.onRename,
  });

  final AgentSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String> onRename;

  @override
  State<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<_AgentTab> {
  bool _hovering = false;
  bool _editing = false;
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.session.displayName);
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _editing) _commitRename();
    });
  }

  @override
  void didUpdateWidget(_AgentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.session.displayName != widget.session.displayName) {
      _nameController.text = widget.session.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _nameController.text = widget.session.displayName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _commitRename() {
    final name = _nameController.text.trim();
    widget.onRename(name);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final session = widget.session;
    final isLive = session.status == AgentStatus.live;
    final statusColor =
        isLive ? AppColors.statusActive : AppColors.statusIdle;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _editing ? null : widget.onTap,
        onDoubleTap: _editing ? null : _startEditing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isActive
                ? colors.tabActiveBg
                : _hovering
                    ? colors.surfaceHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: colors.primary.withAlpha(80))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.type.iconLabel,
                style: TextStyle(fontSize: 12, color: colors.primaryLight),
              ),
              const SizedBox(width: 5),
              if (_editing)
                SizedBox(
                  width: 90,
                  height: 20,
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide(color: colors.primary, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: BorderSide(color: colors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _commitRename(),
                    onEditingComplete: _commitRename,
                  ),
                )
              else
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
              if (!_editing) ...[
                const SizedBox(width: 4),
                Opacity(
                  opacity: _hovering ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: _hovering ? widget.onClose : null,
                    child: const Icon(Icons.close, size: 10, color: AppColors.textMuted),
                  ),
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
    final colors = context.appColors;
    return Container(
      height: 28,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            'yoloit > ',
            style: TextStyle(
              color: colors.primaryLight,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              session.type.command,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
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
  double _fontSize = 13.0;
  double _scaleBase = 13.0;
  Size _terminalSize = Size.zero;
  Offset? _clickDownPosition;

  @override
  void initState() {
    super.initState();
    _bindTerminal();
    _requestFocusAfterFrame();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    // Load persisted font size
    SessionPrefs.load().then((snap) {
      if (mounted) setState(() => _fontSize = snap.terminalFontSize);
    });
  }

  @override
  void didUpdateWidget(_TerminalWidget old) {
    super.didUpdateWidget(old);
    if (old.session.id != widget.session.id) {
      old.session.terminal.onOutput = null;
      old.session.terminal.onResize = null;
      // Remove old handler before re-adding to prevent duplicates
      HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
      _bindTerminal();
      _requestFocusAfterFrame();
      HardwareKeyboard.instance.addHandler(_handleHardwareKey);
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

  /// Intercepts macOS keyboard shortcuts and translates them to PTY control
  /// sequences before [TerminalView] can process the raw key event.
  ///
  /// Mapping (readline / bash compatible):
  ///   Cmd+V              → paste as file reference (existing behaviour)
  ///   Cmd+Backspace      → Ctrl+U  (\x15) — erase to start of line
  ///   Opt+Backspace      → Ctrl+W  (\x17) — erase word backward
  ///   Ctrl+Backspace     → Ctrl+W  (\x17) — erase word backward (PC style)
  ///   Cmd+←             → Ctrl+A  (\x01) — beginning of line
  ///   Cmd+→             → Ctrl+E  (\x05) — end of line
  /// xterm onKeyEvent — intercepts Shift+Enter to send the Kitty keyboard
  /// protocol escape sequence (\x1b[13;2u) so modern CLIs (Copilot, Claude
  /// Code) treat it as a newline in the input buffer instead of submitting.
  KeyEventResult _onTerminalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Shift+Enter → ESC+CR (newline-in-input for Copilot/Claude Code)
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      _writePty('\x1b\r');
      return KeyEventResult.handled;
    }
    // Cmd+V — already handled by _handleHardwareKey; block xterm's native
    // paste so text isn't inserted twice.
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ///   Opt+←             → ESC+b   (\x1bb) — word backward
  ///   Opt+→             → ESC+f   (\x1bf) — word forward
  ///   Cmd+K             → Ctrl+L  (\x0c) — clear screen
  bool _handleHardwareKey(KeyEvent event) {
    if (!_focusNode.hasFocus) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Cmd+V → paste as file ref (no raw paste)
    if (isCmd && !isCtrl && !isAlt && key == LogicalKeyboardKey.keyV) {
      _pasteAsFileRef();
      return true;
    }

    // Cmd+Backspace → erase to start of line (Ctrl+U)
    if (isCmd && key == LogicalKeyboardKey.backspace) {
      _writePty('\x15');
      return true;
    }

    // Option+Backspace or Ctrl+Backspace → erase word backward (Ctrl+W)
    if ((isAlt || isCtrl) && key == LogicalKeyboardKey.backspace) {
      _writePty('\x17');
      return true;
    }

    // Cmd+Left → beginning of line (Ctrl+A)
    if (isCmd && key == LogicalKeyboardKey.arrowLeft) {
      _writePty('\x01');
      return true;
    }

    // Cmd+Right → end of line (Ctrl+E)
    if (isCmd && key == LogicalKeyboardKey.arrowRight) {
      _writePty('\x05');
      return true;
    }

    // Option+Left → word backward (ESC b)
    if (isAlt && key == LogicalKeyboardKey.arrowLeft) {
      _writePty('\x1bb');
      return true;
    }

    // Option+Right → word forward (ESC f)
    if (isAlt && key == LogicalKeyboardKey.arrowRight) {
      _writePty('\x1bf');
      return true;
    }

    // Cmd+K → clear screen (Ctrl+L)
    if (isCmd && key == LogicalKeyboardKey.keyK) {
      _writePty('\x0c');
      return true;
    }

    // Cmd+= → increase font size
    if (isCmd && !isCtrl && !isAlt && key == LogicalKeyboardKey.equal) {
      setState(() => _fontSize = (_fontSize + 1).clamp(8.0, 32.0));
      return true;
    }

    // Cmd+- → decrease font size
    if (isCmd && !isCtrl && !isAlt && key == LogicalKeyboardKey.minus) {
      setState(() => _fontSize = (_fontSize - 1).clamp(8.0, 32.0));
      return true;
    }

    return false;
  }

  void _writePty(String sequence) {
    PtyService.instance.write(widget.session.id, sequence);
  }

  /// Click-to-move cursor: when the user single-clicks on the prompt row
  /// (not in alternate buffer / vim / etc.), send arrow keys to move the
  /// cursor to the clicked column. Same behavior as Superset desktop app.
  void _handleTerminalClick(Offset localPosition) {
    final terminal = widget.session.terminal;
    // Don't interfere with vim/less/etc. (alternate screen)
    if (terminal.isUsingAltBuffer) return;
    // Don't interfere with active text selection
    if (_controller.selection != null) return;

    const padding = 8.0;
    final innerWidth = _terminalSize.width - padding * 2;
    final innerHeight = _terminalSize.height - padding * 2;
    if (innerWidth <= 0 || innerHeight <= 0) return;

    final cellWidth = innerWidth / terminal.viewWidth;
    final cellHeight = innerHeight / terminal.viewHeight;

    final clickCol = ((localPosition.dx - padding) / cellWidth)
        .floor()
        .clamp(0, terminal.viewWidth - 1);
    final clickRow = ((localPosition.dy - padding) / cellHeight)
        .floor()
        .clamp(0, terminal.viewHeight - 1);

    // Only move when click is on the same row as the cursor
    if (clickRow != terminal.buffer.cursorY) return;

    final delta = clickCol - terminal.buffer.cursorX;
    if (delta == 0) return;

    // Right arrow: \x1b[C  Left arrow: \x1b[D
    final arrow = delta > 0 ? '\x1b[C' : '\x1b[D';
    _writePty(arrow * delta.abs());
  }

  Future<void> _pasteAsFileRef() async {
    // Read clipboard text first to decide how to paste.
    final clipboard = SystemClipboard.instance;
    if (clipboard != null) {
      final reader = await clipboard.read();
      if (reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null && text.isNotEmpty && text.trim().split(RegExp(r'\s+')).length <= 1000) {
          // Short text — paste directly as plain text.
          if (!mounted) return;
          PtyService.instance.write(widget.session.id, text);
          return;
        }
      }
    }

    // Long text or image — save to file and paste the path.
    final path = await ClipboardFileService.instance.saveClipboardToFile();
    if (path == null || !mounted) return;
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
    final colors = context.appColors;
    return GestureDetector(
      onScaleStart: (d) => _scaleBase = _fontSize,
      onScaleUpdate: (d) {
        final newSize = (_scaleBase * d.scale).clamp(8.0, 48.0);
        setState(() => _fontSize = newSize);
        SessionPrefs.saveTerminalFontSize(newSize);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _terminalSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
              _clickDownPosition = event.localPosition;
            },
            onPointerUp: (event) {
              final down = _clickDownPosition;
              _clickDownPosition = null;
              if (down == null) return;
              // Only treat as a click if pointer didn't move much (no drag/selection)
              if ((event.localPosition - down).distance > 6.0) return;
              _handleTerminalClick(event.localPosition);
            },
            child: TerminalView(
              widget.session.terminal,
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _onTerminalKeyEvent,
              textStyle: TerminalStyle(fontSize: _fontSize),
              theme: TerminalTheme(
                cursor: colors.primary,
                selection: colors.primary.withAlpha(68),
                foreground: const Color(0xFFCECEEE),
                background: const Color(0xFF070714),
                black: const Color(0xFF1A1A2E),
                red: const Color(0xFFFF4F6A),
                green: const Color(0xFF00FF9F),
                yellow: const Color(0xFFFFD700),
                blue: const Color(0xFF00B4FF),
                magenta: const Color(0xFFB87FFF),
                cyan: const Color(0xFF00E5FF),
                white: const Color(0xFFCECEEE),
                brightBlack: const Color(0xFF44446A),
                brightRed: const Color(0xFFFF6B85),
                brightGreen: const Color(0xFF4DFFBE),
                brightYellow: const Color(0xFFFFE866),
                brightBlue: const Color(0xFF33C5FF),
                brightMagenta: const Color(0xFFCDA0FF),
                brightCyan: const Color(0xFF33EEFF),
                brightWhite: const Color(0xFFFFFFFF),
                searchHitBackground: const Color(0xFFFF9500),
                searchHitBackgroundCurrent: const Color(0xFFFFB700),
                searchHitForeground: const Color(0xFF000000),
              ),
              padding: const EdgeInsets.all(8),
            ),
          );
        },
      ),
    );
  }
}

class _AddSessionButton extends StatelessWidget {
  const _AddSessionButton({required this.workspace});

  final Workspace workspace;

  Future<void> _showDialog(BuildContext context) async {
    // Load worktrees for all repos in the workspace
    final worktrees = <String, List<WorktreeEntry>>{};
    for (final repoPath in workspace.paths) {
      worktrees[repoPath] =
          await WorktreeService.instance.listWorktrees(repoPath);
    }
    if (!context.mounted) return;
    showNewAgentSessionDialog(
      context,
      workspace: workspace,
      worktrees: worktrees,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: 'New agent session',
      child: GestureDetector(
        onTap: () => _showDialog(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.primary.withAlpha(80)),
            ),
            child: Icon(Icons.add, size: 16, color: colors.primaryLight),
          ),
        ),
      ),
    );
  }
}

class _AgentLaunchButton extends StatelessWidget {
  const _AgentLaunchButton({
    required this.type,
    required this.workspacePath,
    required this.workspaceId,
  });

  final AgentType type;
  final String workspacePath;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: 'Start ${type.displayName} session',
      child: GestureDetector(
        onTap: () => context.read<TerminalCubit>().spawnSession(
              type: type,
              workspacePath: workspacePath,
              workspaceId: workspaceId,
            ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.primary.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type.iconLabel, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                type.displayName,
                style: TextStyle(
                  color: colors.primaryLight,
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

class _WorkspaceStatusBar extends StatelessWidget {
  const _WorkspaceStatusBar({this.session});
  final AgentSession? session;

  void _showColorPicker(BuildContext context, Workspace ws, Color current) {
    showDialog<void>(
      context: context,
      builder: (_) => _WorkspaceColorPickerDialog(
        workspace: ws,
        initial: ws.color ?? current,
        onSave: (c) => context.read<WorkspaceCubit>().setWorkspaceColor(ws.id, c),
        onReset: () => context.read<WorkspaceCubit>().setWorkspaceColor(ws.id, null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (session == null) return const SizedBox();
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, wsState) {
        final ws = wsState is WorkspaceLoaded ? wsState.activeWorkspace : null;
        final accentColor = ws?.color ?? colors.primary;
        final wsName = ws?.name ?? 'No workspace';

        return Tooltip(
          message: 'Click to change workspace colour',
          child: GestureDetector(
            onTap: ws != null ? () => _showColorPicker(context, ws, accentColor) : null,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                border: Border(
                  top: BorderSide(color: accentColor.withAlpha(180), width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            wsName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accentColor.withAlpha(220),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (ws?.gitBranch != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.alt_route, size: 10, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              ws!.gitBranch!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.palette_outlined, size: 10, color: accentColor.withAlpha(120)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full custom color picker dialog for a workspace.
class _WorkspaceColorPickerDialog extends StatefulWidget {
  const _WorkspaceColorPickerDialog({
    required this.workspace,
    required this.initial,
    required this.onSave,
    required this.onReset,
  });

  final Workspace workspace;
  final Color initial;
  final ValueChanged<Color> onSave;
  final VoidCallback onReset;

  @override
  State<_WorkspaceColorPickerDialog> createState() =>
      _WorkspaceColorPickerDialogState();
}

class _WorkspaceColorPickerDialogState
    extends State<_WorkspaceColorPickerDialog> {
  late Color _current;
  late final TextEditingController _hexCtrl;

  static const _presets = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
    Color(0xFFDB2777), Color(0xFF65A30D), Color(0xFF9333EA),
    Color(0xFFEA580C), Color(0xFF0D9488), Color(0xFF4F46E5),
    Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFEF4444),
    Color(0xFF6366F1), Color(0xFFF97316), Color(0xFF14B8A6),
    Color(0xFFEC4899), Color(0xFF84CC16),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _hexCtrl = TextEditingController(text: _toHex(_current));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.r.toInt().toRadixString(16).padLeft(2, '0')}'
      '${c.g.toInt().toRadixString(16).padLeft(2, '0')}'
      '${c.b.toInt().toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  void _setColor(Color c) {
    setState(() {
      _current = c;
      _hexCtrl.text = _toHex(c);
    });
  }

  void _onHexSubmit(String value) {
    final cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final v = int.tryParse('FF$cleaned', radix: 16);
      if (v != null) _setColor(Color(v));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F0F2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _current,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Colour — ${widget.workspace.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Color wheel + sliders
              ColorPicker(
                pickerColor: _current,
                onColorChanged: _setColor,
                pickerAreaHeightPercent: 0.5,
                enableAlpha: false,
                displayThumbColor: true,
                labelTypes: const [],
                hexInputBar: false,
              ),

              const SizedBox(height: 12),

              // Hex input
              Row(
                children: [
                  const Text(
                    'HEX',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _hexCtrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1A1A3E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: _current.withAlpha(80)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: _current.withAlpha(80)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onSubmitted: _onHexSubmit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Preview swatch
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _current,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Preset swatches
              const Text(
                'PRESETS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((c) {
                  final isSelected = _current.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => _setColor(c),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: c.withAlpha(180), blurRadius: 6)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      widget.onReset();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reset to theme'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(_current);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _current,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
