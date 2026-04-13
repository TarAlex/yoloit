import 'package:flutter/material.dart';
import 'package:yoloit/core/theme/app_colors.dart';
import 'package:yoloit/features/updates/data/update_service.dart';

/// Slim in-app banner shown at the top of the shell when an update is available.
/// Handles the full download-mount-install-relaunch flow with progress display.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
    required this.info,
    required this.onDismiss,
  });

  final UpdateInfo info;
  final VoidCallback onDismiss;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  double? _progress;       // 0.0–1.0 during download, null during other steps
  String _status = '';
  bool _isWorking = false;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _isWorking = true;
      _error = null;
      _status = 'Starting…';
    });

    try {
      await UpdateService.downloadAndInstall(
        widget.info,
        onProgress: (progress, status) {
          if (mounted) setState(() { _progress = progress; _status = status; });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _error = e.toString().replaceFirst('Exception: ', '');
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neonBlue.withAlpha(230),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _isWorking ? Icons.downloading_rounded : Icons.system_update_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isWorking
                        ? _status
                        : _error != null
                            ? 'Update failed: $_error'
                            : 'YoLoIT ${widget.info.tagName} is available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_isWorking) ...[
                  _ActionButton(
                    label: 'Update',
                    icon: Icons.download_rounded,
                    onTap: _startUpdate,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Skip this version',
                    onTap: () {
                      UpdateService.skipVersion(widget.info.version);
                      widget.onDismiss();
                    },
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close, size: 14, color: Colors.white70),
                  ),
                ] else ...[
                  // Show % during download
                  if (_progress != null)
                    Text(
                      '${(_progress! * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                ],
              ],
            ),
            // Progress bar during download
            if (_isWorking && _progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            // Indeterminate bar during mount/install/relaunch
            if (_isWorking && _progress == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
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
