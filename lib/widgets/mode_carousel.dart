import 'package:flutter/material.dart';

import '../cubits/camera_cubit.dart';
import '../theme/tokens.dart';
import '../services/capture_prefs.dart';
import 'glass.dart';

/// `PHOTO   VIDEO` text switch; active mode in focus yellow.
class ModeSwitch extends StatelessWidget {
  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChange;
  final bool enabled;
  final Axis direction;

  const ModeSwitch({
    super.key,
    required this.mode,
    required this.onChange,
    this.enabled = true,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(CaptureMode m, String label) {
      final on = m == mode;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !on
            ? () {
                Haptics.selection();
                onChange(m);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s1),
          child: AnimatedDefaultTextStyle(
            duration: Motion.fast,
            style: TextStyle(
              fontSize: TextSize.xs,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: on ? CamColors.focus : (enabled ? CamColors.fgFaint : CamColors.hairlineStrong),
            ),
            child: Text(label),
          ),
        ),
      );
    }

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      spacing: direction == Axis.horizontal ? Space.s6 : Space.s3,
      children: [item(CaptureMode.photo, 'PHOTO'), item(CaptureMode.video, 'VIDEO')],
    );
  }
}
