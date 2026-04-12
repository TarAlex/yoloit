import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/settings/data/setup_check_service.dart';

/// Embedded version used inside the Settings panel (no dialog chrome).
class SetupGuideEmbedded extends StatefulWidget {
  const SetupGuideEmbedded({super.key});

  @override
  State<SetupGuideEmbedded> createState() => _SetupGuideEmbeddedState();
}

class _SetupGuideEmbeddedState extends State<SetupGuideEmbedded> {
  SetupCheckResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _loading = true);
    final result = await SetupCheckService.check();
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: _LoadingView());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Body(result: _result!, onRecheck: _runChecks),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                _result!.allRequiredDepsOk ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 13,
                color: _result!.allRequiredDepsOk ? AppColors.neonGreen : AppColors.neonOrange,
              ),
              const SizedBox(width: 6),
              Text(
                _result!.allRequiredDepsOk
                    ? 'All required dependencies found'
                    : 'Some required dependencies are missing',
                style: TextStyle(
                  color: _result!.allRequiredDepsOk ? AppColors.neonGreen : AppColors.neonOrange,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _runChecks,
                icon: const Icon(Icons.refresh, size: 12),
                label: const Text('Re-check', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class SetupGuidePage extends StatefulWidget {
  const SetupGuidePage({super.key, this.isWizard = false});

  /// When true, shows "Get Started" button and marks setup as complete on dismiss.
  final bool isWizard;

  static Future<void> show(BuildContext context, {bool isWizard = false}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isWizard,
      barrierColor: Colors.black.withAlpha(180),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: SetupGuidePage(isWizard: isWizard),
      ),
    );
  }

  /// Show on first launch if setup has not been completed.
  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final completed = await SessionPrefs.isSetupCompleted();
    if (!completed && context.mounted) {
      await show(context, isWizard: true);
    }
  }

  @override
  State<SetupGuidePage> createState() => _SetupGuidePageState();
}

class _SetupGuidePageState extends State<SetupGuidePage> {
  SetupCheckResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _loading = true);
    final result = await SetupCheckService.check();
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  Future<void> _dismiss() async {
    if (widget.isWizard) await SessionPrefs.markSetupCompleted();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _Header(isWizard: widget.isWizard, onClose: widget.isWizard ? null : () => Navigator.of(context).pop()),
          Expanded(
            child: _loading
                ? const Center(child: _LoadingView())
                : _Body(result: _result!, onRecheck: _runChecks),
          ),
          _Footer(
            isWizard: widget.isWizard,
            result: _result,
            onDismiss: _dismiss,
            onRecheck: _runChecks,
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isWizard, this.onClose});
  final bool isWizard;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checklist_rounded, color: AppColors.neonBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWizard ? 'Welcome to yoloit 👋' : 'Setup Guide',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Check dependencies and configure AI agents',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
              splashRadius: 16,
            ),
        ],
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)),
        SizedBox(height: 12),
        Text('Checking your environment...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.result, required this.onRecheck});
  final SetupCheckResult result;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dependencies ───────────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.settings_suggest_outlined,
            label: 'System Dependencies',
            subtitle: 'Required for core functionality',
          ),
          const SizedBox(height: 10),
          ...result.deps.map((dep) => _DepRow(dep: dep)),
          const SizedBox(height: 28),

          // ── AI Agents ─────────────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.smart_toy_outlined,
            label: 'AI Agents',
            subtitle: result.anyAgentAvailable
                ? 'Detected on your system'
                : 'No agents detected — install at least one to get started',
            subtitleColor: result.anyAgentAvailable ? null : AppColors.neonOrange,
          ),
          const SizedBox(height: 10),
          ...result.agents.map((agent) => _AgentRow(agent: agent)),

          if (!result.anyAgentAvailable) ...[
            const SizedBox(height: 16),
            _InstallSuggestion(),
          ],
        ],
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, required this.subtitle, this.subtitleColor});
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.neonBlue),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(color: subtitleColor ?? AppColors.textMuted, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Dep row ───────────────────────────────────────────────────────────────────

class _DepRow extends StatelessWidget {
  const _DepRow({required this.dep});
  final DependencyStatus dep;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ok = dep.isAvailable;
    final statusColor = ok
        ? AppColors.neonGreen
        : dep.isRequired ? Colors.red.shade400 : AppColors.neonOrange;
    final statusIcon = ok ? Icons.check_circle_outline : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ok ? colors.border : statusColor.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(dep.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                    if (dep.isRequired)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('required', style: TextStyle(color: Colors.redAccent, fontSize: 8)),
                      ),
                    if (ok && dep.version != null) ...[
                      const SizedBox(width: 8),
                      Text(dep.version!, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(dep.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          if (!ok) ...[
            const SizedBox(width: 8),
            _CopyInstallButton(hint: dep.installHint),
          ],
        ],
      ),
    );
  }
}

// ── Agent row ─────────────────────────────────────────────────────────────────

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});
  final DependencyStatus agent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ok = agent.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ok ? AppColors.neonGreen.withAlpha(50) : colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: (ok ? AppColors.neonGreen : AppColors.textMuted).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              ok ? Icons.check : Icons.download_outlined,
              size: 14,
              color: ok ? AppColors.neonGreen : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(agent.name,
                        style: TextStyle(
                          color: ok ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        )),
                    if (ok && agent.version != null) ...[
                      const SizedBox(width: 8),
                      Text(agent.version!, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ],
                ),
                Text(agent.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ok)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Available', style: TextStyle(color: AppColors.neonGreen, fontSize: 9, fontWeight: FontWeight.w600)),
            )
          else
            _CopyInstallButton(hint: agent.installHint),
        ],
      ),
    );
  }
}

// ── Copy install command button ───────────────────────────────────────────────

class _CopyInstallButton extends StatefulWidget {
  const _CopyInstallButton({required this.hint});
  final String hint;

  @override
  State<_CopyInstallButton> createState() => _CopyInstallButtonState();
}

class _CopyInstallButtonState extends State<_CopyInstallButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.hint,
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.hint));
          setState(() => _copied = true);
          await Future<void>.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _copied = false);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.neonBlue.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy_outlined,
                size: 10,
                color: AppColors.neonBlue,
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? 'Copied!' : 'Install',
                style: const TextStyle(color: AppColors.neonBlue, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Install suggestion (no agents found) ──────────────────────────────────────

class _InstallSuggestion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonBlue.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.neonBlue),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recommended: GitHub Copilot CLI',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Install with Node.js: npm install -g @github/copilot-cli',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CopyInstallButton(hint: 'npm install -g @github/copilot-cli'),
        ],
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isWizard,
    required this.result,
    required this.onDismiss,
    required this.onRecheck,
  });
  final bool isWizard;
  final SetupCheckResult? result;
  final VoidCallback onDismiss;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final allOk = result?.allRequiredDepsOk ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (result != null) ...[
            Icon(
              allOk ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 14,
              color: allOk ? AppColors.neonGreen : AppColors.neonOrange,
            ),
            const SizedBox(width: 6),
            Text(
              allOk
                  ? 'All required dependencies found'
                  : 'Some required dependencies are missing',
              style: TextStyle(
                color: allOk ? AppColors.neonGreen : AppColors.neonOrange,
                fontSize: 11,
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: onRecheck,
            icon: const Icon(Icons.refresh, size: 13),
            label: const Text('Re-check', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onDismiss,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(isWizard ? 'Get Started →' : 'Close'),
          ),
        ],
      ),
    );
  }
}
