import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cubits/camera_cubit.dart';

class ModeCarousel extends StatelessWidget {
  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChange;
  final bool enabled;

  const ModeCarousel({
    super.key,
    required this.mode,
    required this.onChange,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ModeItem(
              label: 'PHOTO',
              active: mode == CaptureMode.photo,
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(CaptureMode.photo);
              },
            ),
            const SizedBox(width: 28),
            _ModeItem(
              label: 'VIDEO',
              active: mode == CaptureMode.video,
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(CaptureMode.video);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeItem({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.amber : Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 24 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
