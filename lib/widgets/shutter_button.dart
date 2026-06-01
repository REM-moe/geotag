import 'package:flutter/material.dart';

import '../cubits/camera_cubit.dart';

class ShutterButton extends StatelessWidget {
  final CaptureMode mode;
  final bool isRecording;
  final VoidCallback onTap;

  const ShutterButton({
    super.key,
    required this.mode,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
            // Inner shape — animated between circle (photo) and rounded square (recording)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isRecording ? 32 : 64,
              height: isRecording ? 32 : 64,
              decoration: BoxDecoration(
                color: mode == CaptureMode.video || isRecording
                    ? const Color(0xFFE53935)
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(isRecording ? 6 : 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
