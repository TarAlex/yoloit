import 'package:flutter/material.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/core/theme/app_theme.dart';
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/terminal/data/logging_service.dart';
import 'package:yoloit/features/terminal/data/tmux_service.dart';

/// Settings overlay shown as a modal sheet.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 80, vertical: 60),
        child: SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: BoxConstraints(maxWidth: 600, maxHeight: 620),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Appearance'),
                  const SizedBox(height: 12),
                  _ThemeSelector(),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Sessions'),
                  const SizedBox(height: 12),
                  _SessionSettings(),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Keyboard Shortcuts'),
                  const SizedBox(height: 12),
                  _ShortcutsTable(),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'About'),
                  const SizedBox(height: 12),
                  _AboutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      title,
      style: TextStyle(
        color: colors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _ThemeSelector extends StatefulWidget {
  @override
  State<_ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<_ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = ThemeManager.instance.current;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppThemePreset.values.map((preset) {
        final isActive = preset == current;
        return GestureDetector(
          onTap: () {
            ThemeManager.instance.setTheme(preset);
            setState(() {});
          },
          child: Container(
            width: 100,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? colors.primary.withAlpha(30)
                  : colors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? colors.primary : colors.border,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: preset.theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  preset.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? colors.primary : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ShortcutsTable extends StatelessWidget {
  static const _shortcuts = [
    ('⌘[', 'Previous agent tab'),
    ('⌘]', 'Next agent tab'),
    ('⌘W', 'Close terminal tab'),
    ('⌘\\', 'Toggle workspace panel'),
    ('⌘⇧\\', 'Toggle review panel'),
    ('⌘`', 'Focus terminal'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: _shortcuts.indexed.map(((int, (String, String)) entry) {
          final (index, (key, desc)) = entry;
          final isLast = index == _shortcuts.length - 1;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'yoloit — AI Orchestrator',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'A Flutter desktop app for orchestrating AI CLI tools (GitHub Copilot, Claude Code) with embedded PTY terminals and git workspace management.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Platform: macOS (primary) • Windows (coming soon)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Session Settings ─────────────────────────────────────────────────────────

class _SessionSettings extends StatefulWidget {
  @override
  State<_SessionSettings> createState() => _SessionSettingsState();
}

class _SessionSettingsState extends State<_SessionSettings> {
  final _tmux = TmuxService.instance;
  final _logging = LoggingService.instance;

  bool _loggingOn = false;
  bool _tmuxOn = false;
  bool _showLogs = false;
  List<LogFile> _logs = [];
  bool _logsLoading = false;

  @override
  void initState() {
    super.initState();
    _loggingOn = _logging.enabled;
    _tmuxOn = _tmux.enabled;
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    final logs = await _logging.listLogs();
    if (mounted) setState(() { _logs = logs; _logsLoading = false; });
  }

  Future<void> _deleteLog(String path) async {
    await _logging.deleteLog(path);
    await _loadLogs();
  }

  Future<void> _clearAll() async {
    await _logging.clearAll();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tmux toggle
          _ToggleRow(
            icon: Icons.terminal,
            title: 'Keep sessions alive after closing app',
            subtitle: _tmux.available
                ? 'Uses tmux — sessions survive app restart'
                : 'Requires tmux — install with: brew install tmux',
            value: _tmuxOn && _tmux.available,
            enabled: _tmux.available,
            onChanged: (v) async {
              await _tmux.setEnabled(v);
              if (mounted) setState(() => _tmuxOn = v);
            },
          ),
          Divider(height: 1, color: colors.border),
          // Logging toggle
          _ToggleRow(
            icon: Icons.description_outlined,
            title: 'Log terminal output to files',
            subtitle: 'Saved to ~/.yoloit/logs/',
            value: _loggingOn,
            onChanged: (v) async {
              await _logging.setEnabled(v);
              if (mounted) {
                setState(() { _loggingOn = v; if (!v) _showLogs = false; });
              }
            },
          ),
          // Logs viewer
          if (_loggingOn) ...[
            Divider(height: 1, color: colors.border),
            InkWell(
              onTap: () {
                setState(() => _showLogs = !_showLogs);
                if (!_showLogs) return;
                _loadLogs();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _showLogs ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View log files',
                      style: TextStyle(color: colors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            if (_showLogs) _buildLogsSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsSection(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_logs.length} file(s)',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              if (_logs.isNotEmpty)
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear all', style: TextStyle(fontSize: 12)),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _loadLogs,
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: AppColors.textMuted,
              ),
            ],
          ),
          if (_logsLoading)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No logs yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...(_logs.take(10).map(
              (log) => _LogRow(
                log: log,
                onDelete: () => _deleteLog(log.path),
                onView: () => _showLogContent(context, log),
              ),
            )),
        ],
      ),
    );
  }

  void _showLogContent(BuildContext context, LogFile log) {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: _LogViewerDialog(log: log),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value && enabled,
            onChanged: enabled ? onChanged : null,
            activeColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.log,
    required this.onDelete,
    required this.onView,
  });

  final LogFile log;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Text(
                log.name,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Text(log.sizeLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LogViewerDialog extends StatefulWidget {
  const _LogViewerDialog({required this.log});
  final LogFile log;

  @override
  State<_LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<_LogViewerDialog> {
  String? _content;

  @override
  void initState() {
    super.initState();
    LoggingService.instance.readLog(widget.log.path).then((c) {
      if (mounted) setState(() => _content = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.log.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(widget.log.sizeLabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: _content == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _content!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.6,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
