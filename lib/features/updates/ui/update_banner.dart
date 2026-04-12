import 'package:flutter/material.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/updates/data/update_service.dart';

/// Slim in-app banner shown at the top of the shell when an update is available.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.info,
    required this.onDownload,
    required this.onDismiss,
  });

  final UpdateInfo info;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neonBlue.withAlpha(230),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'yoloit ${info.tagName} is available',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _ActionButton(
              label: 'Download',
              icon: Icons.download_rounded,
              onTap: onDownload,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Skip this version',
              onTap: onDismiss,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
