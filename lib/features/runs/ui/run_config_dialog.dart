import 'package:flutter/material.dart';
import 'package:yoloit/core/theme/app_color_scheme.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/runs/models/run_config.dart';

class RunConfigDialog extends StatefulWidget {
  const RunConfigDialog({super.key, this.initial});

  final RunConfig? initial;

  static Future<RunConfig?> show(BuildContext context, {RunConfig? initial}) {
    return showDialog<RunConfig>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => RunConfigDialog(initial: initial),
    );
  }

  @override
  State<RunConfigDialog> createState() => _RunConfigDialogState();
}

class _RunConfigDialogState extends State<RunConfigDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _commandCtrl;
  late final TextEditingController _workingDirCtrl;
  late bool _isFlutterRun;
  Color? _selectedColor;

  static const _colorChips = [
    Color(0xFF54C5F8),
    Color(0xFF00FF9F),
    Color(0xFFFFD700),
    Color(0xFFFF4F6A),
    Color(0xFF9D4EDD),
    Color(0xFFFF9500),
    Color(0xFFFF69B4),
    Color(0xFF00B4FF),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _commandCtrl = TextEditingController(text: c?.command ?? '');
    _workingDirCtrl = TextEditingController(text: c?.workingDir ?? '');
    _isFlutterRun = c?.isFlutterRun ?? false;
    _selectedColor = c?.color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _workingDirCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final command = _commandCtrl.text.trim();
    if (name.isEmpty || command.isEmpty) return;

    final existing = widget.initial;
    final config = RunConfig(
      id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      command: command,
      workingDir: _workingDirCtrl.text.trim().isEmpty
          ? null
          : _workingDirCtrl.text.trim(),
      env: existing?.env ?? {},
      color: _selectedColor,
      isFlutterRun: _isFlutterRun,
    );
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Dialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null
                    ? 'New Run Configuration'
                    : 'Edit Run Configuration',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _Field(label: 'Name', controller: _nameCtrl, hint: 'e.g. Flutter Run'),
              const SizedBox(height: 12),
              _Field(
                label: 'Command',
                controller: _commandCtrl,
                hint: 'e.g. flutter run -d macos',
                fontFamily: 'monospace',
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Working Directory',
                controller: _workingDirCtrl,
                hint: 'Leave empty to use workspace root',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _isFlutterRun,
                      onChanged: (v) =>
                          setState(() => _isFlutterRun = v ?? false),
                      activeColor: colors.primary,
                      side: const BorderSide(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Flutter Run mode (enables Hot Reload / Restart buttons)',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = null),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: _selectedColor == null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          width: _selectedColor == null ? 2 : 1,
                        ),
                      ),
                      child: _selectedColor == null
                          ? const Icon(Icons.close,
                              size: 10, color: AppColors.textPrimary)
                          : null,
                    ),
                  ),
                  ..._colorChips.map((c) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: _selectedColor?.toARGB32() == c.toARGB32()
                                ? Border.all(
                                    color: AppColors.textPrimary, width: 2)
                                : null,
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 13)),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.fontFamily,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFamily: fontFamily,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.primary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
