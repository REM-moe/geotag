import 'package:flutter/material.dart';

import '../cubits/camera_cubit.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// 72px shutter. Photo = white disc, video = red disc, recording = red
/// rounded square. While media is being stamped/saved in the background a
/// thin arc spins around the ring.
class ShutterButton extends StatefulWidget {
  final CaptureMode mode;
  final bool isRecording;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  const ShutterButton({
    super.key,
    required this.mode,
    required this.isRecording,
    required this.onTap,
    this.saving = false,
    this.enabled = true,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.mode == CaptureMode.video;
    final innerSize = widget.isRecording ? 24.0 : (video ? 54.0 : CamSize.shutterInner);
    final label = widget.isRecording ? 'Stop recording' : (video ? 'Record video' : 'Take photo');

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Motion.ease,
          child: AnimatedOpacity(
            duration: Motion.fast,
            opacity: widget.enabled ? 1 : 0.5,
            child: SizedBox.square(
              dimension: CamSize.shutter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: Motion.fast,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.saving ? CamColors.fgFaint : CamColors.fg,
                        width: 3,
                      ),
                    ),
                  ),
                  if (widget.saving)
                    const SizedBox.square(
                      dimension: CamSize.shutter,
                      child: CircularProgressIndicator(strokeWidth: 3, color: CamColors.fg),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Motion.ease,
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      color: video ? CamColors.record : CamColors.fg,
                      borderRadius: BorderRadius.circular(widget.isRecording ? Radii.sm : innerSize / 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
