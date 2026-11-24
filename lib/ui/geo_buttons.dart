import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum GeoButtonVariant { primary, secondary, ghost, danger }

enum GeoButtonSize { sm, md, lg }

/// Button matching mock `.btn` (+ `.btn-primary/secondary/ghost/danger`,
/// `.btn-sm/.btn-lg`). Flat, hairline-bordered, no elevation.
class GeoButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GeoButtonVariant variant;
  final GeoButtonSize size;
  final bool expand;

  /// Overrides the foreground colour (e.g. a red ghost "Delete" button).
  final Color? foreground;

  const GeoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = GeoButtonVariant.primary,
    this.size = GeoButtonSize.md,
    this.expand = false,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final enabled = onPressed != null;
    final (double h, double padX, double fs, double radius) = switch (size) {
      GeoButtonSize.sm => (30.0, Space.s3, TextSize.sm, Radii.sm),
      GeoButtonSize.md => (36.0, Space.s4, TextSize.md, Radii.md),
      GeoButtonSize.lg => (44.0, Space.s4, TextSize.md, Radii.md),
    };
    final (Color bg, Color fg, Color? border) = switch (variant) {
      GeoButtonVariant.primary => (g.accent, g.onAccent, null),
      GeoButtonVariant.secondary => (g.bg, g.text, g.borderStrong),
      GeoButtonVariant.ghost => (Colors.transparent, g.text2, null),
      GeoButtonVariant.danger => (g.bg, g.negative, g.borderStrong),
    };
    final fgColor = foreground ?? fg;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: size == GeoButtonSize.sm ? 14 : 16, color: fgColor),
          const SizedBox(width: Space.s2),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: fgColor),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: g.surface2,
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: padX),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 36×36 icon button (mock `.icon-btn` / `.icon-btn.bordered`).
class GeoIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool bordered;
  final String? tooltip;
  final double size;

  const GeoIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.bordered = true,
    this.tooltip,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    Widget w = Material(
      color: bordered ? g.bg : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: bordered ? BorderSide(color: g.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: g.surface2,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 18, color: onPressed == null ? g.text3 : g.text2),
        ),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// Compact 36×20 switch (mock `.switch`).
class GeoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const GeoSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          width: 36,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? g.accent : g.surface3,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: AnimatedAlign(
            duration: Motion.fast,
            curve: Motion.ease,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
