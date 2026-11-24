import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Camera chrome palette. The Capture tab is always dark and sits directly on
/// top of the live viewfinder, so these are translucent whites/blacks plus the
/// two iOS-camera status hues (focus yellow, record red). Everything else in
/// the app must use `context.geo`.
abstract final class CamColors {
  static const Color fg = Color(0xFFFFFFFF);
  static const Color fgStrong = Color(0xF2FFFFFF); // 95%
  static const Color fgSoft = Color(0xD9FFFFFF); // 85%
  static const Color fgMuted = Color(0xA6FFFFFF); // 65%
  static const Color fgFaint = Color(0x80FFFFFF); // 50%
  static const Color hairline = Color(0x24FFFFFF); // 14%
  static const Color hairlineStrong = Color(0x2EFFFFFF); // 18%
  static const Color fill = Color(0x14FFFFFF); // 8%
  static const Color glass = Color(0x8C141416); // rgba(20,20,22,.55)
  static const Color glassBorder = Color(0x1FFFFFFF); // 12%
  static const Color stampGlass = Color(0x990E0E10); // rgba(14,14,16,.6)
  static const Color scrimTop = Color(0x8C000000); // 55%
  static const Color scrimBottom = Color(0xB3000000); // 70%
  static const Color textShadow = Color(0xB3000000);
  static const Color grid = Color(0x40FFFFFF); // 25%
  static const Color black = Color(0xFF000000);
  static const Color focus = Color(0xFFFFD60A);
  static const Color record = Color(0xFFFF453A);
  static const Color live = Color(0xFF30D158);
  static const Color blockedBg = Color(0xFF0B0B0C);
}

/// Sizes specific to camera chrome (not part of the global spacing scale).
abstract final class CamSize {
  static const double iconButton = 36;
  static const double pill = 28;
  static const double shutter = 72;
  static const double shutterInner = 58;
  static const double sideButton = 48;
  static const double focusReticle = 64;
  static const double icon = 18;
  static const double iconSm = 16;
  static const double iconXs = 14;
  static const double microText = 9;
  static const double displayText = 34;
}

/// Frosted dark surface used for every control floating over the viewfinder.
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Color borderColor;

  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.full)),
    this.padding,
    this.color = CamColors.glass,
    this.borderColor = CamColors.glassBorder,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 36px round glass icon button (flash, grid, stamp). `on` = solid white.
class CamIconButton extends StatelessWidget {
  final IconData icon;
  final bool on;
  final VoidCallback? onTap;
  final String tooltip;

  const CamIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.on = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CamSize.iconButton,
          child: Glass(
            color: on ? CamColors.fg : CamColors.glass,
            borderColor: on ? CamColors.fg : CamColors.glassBorder,
            child: Center(
              child: Icon(icon, size: CamSize.icon, color: on ? CamColors.black : CamColors.fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// 28px glass pill (Add note, template name). `filled` = solid white.
class CamPill extends StatelessWidget {
  final IconData? leading;
  final IconData? trailing;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final double maxWidth;

  const CamPill({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.filled = false,
    this.onTap,
    this.maxWidth = 230,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? CamColors.black : CamColors.fg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: CamSize.pill,
          child: Glass(
            color: filled ? CamColors.fg : CamColors.glass,
            borderColor: filled ? CamColors.fg : CamColors.glassBorder,
            padding: const EdgeInsets.symmetric(horizontal: Space.s3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: CamSize.iconXs, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSize.xs, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailing, size: CamSize.iconXs, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
