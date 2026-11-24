import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/glass.dart';

/// Small glass notice under the top bar (location off, muted video).
/// Never blocks shooting.
class InlineNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;

  const InlineNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      borderRadius: BorderRadius.circular(Radii.md),
      padding: const EdgeInsets.all(Space.s3),
      child: Row(
        children: [
          Icon(icon, size: CamSize.iconSm, color: CamColors.fg),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w600, color: CamColors.fg),
                ),
                Text(subtitle, style: const TextStyle(fontSize: TextSize.xs, color: CamColors.fgMuted)),
              ],
            ),
          ),
          const SizedBox(width: Space.s3),
          GestureDetector(
            onTap: onAction,
            child: Container(
              height: CamSize.pill,
              padding: const EdgeInsets.symmetric(horizontal: Space.s3),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: CamColors.fg, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Text(
                action,
                style: const TextStyle(fontSize: TextSize.xs, fontWeight: FontWeight.w700, color: CamColors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-area dark empty state when the camera can't run (permission off or
/// hardware error). Library/map/notes keep working.
class CameraBlockedView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const CameraBlockedView({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.icon = Icons.photo_camera_outlined,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final d = GeoColors.dark;
    Widget button(String label, VoidCallback onTap, {required bool primary}) => Material(
          color: primary ? CamColors.fg : d.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: primary ? BorderSide.none : BorderSide(color: d.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: Space.s4),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: TextSize.md,
                  fontWeight: FontWeight.w600,
                  color: primary ? CamColors.black : CamColors.fg,
                ),
              ),
            ),
          ),
        );

    return ColoredBox(
      color: CamColors.blockedBg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: d.surface2,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: d.border),
                  ),
                  child: Icon(icon, size: CamSize.icon, color: d.text2),
                ),
                const SizedBox(height: Space.s3),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: TextSize.lg, fontWeight: FontWeight.w600, color: CamColors.fg),
                ),
                const SizedBox(height: Space.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: TextSize.sm, color: d.text2, height: 1.45),
                  ),
                ),
                const SizedBox(height: Space.s5),
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s2,
                  alignment: WrapAlignment.center,
                  children: [
                    button(primaryLabel, onPrimary, primary: true),
                    if (secondaryLabel != null && onSecondary != null)
                      button(secondaryLabel!, onSecondary!, primary: false),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum ToastTone { success, warning }

/// Inverse pill toast used on the camera (instead of SnackBars over the
/// controls).
class CamToast extends StatelessWidget {
  final String message;
  final ToastTone tone;
  const CamToast({super.key, required this.message, this.tone = ToastTone.success});

  @override
  Widget build(BuildContext context) {
    final d = GeoColors.dark;
    final ok = tone == ToastTone.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
      decoration: BoxDecoration(color: d.text, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: ok ? d.positive : d.warning, shape: BoxShape.circle),
            child: Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, size: 12, color: CamColors.fg),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w500, color: d.bg),
            ),
          ),
        ],
      ),
    );
  }
}
