import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/measure_size.dart';

/// Presents a bottom sheet over the Capture tab. Sheets follow the *system*
/// light/dark theme (only the camera chrome is forced dark), cover the tab
/// bar, have no shadow and a 1px hairline top border.
///
/// [transparentScrim] keeps the live viewfinder fully visible (Stamp studio).
/// [onHeight] reports the sheet's height (for lifting the live stamp above
/// it) and [onClosing] fires as soon as a pop starts (not after the exit
/// animation) so the stamp can drop back in sync.
Future<T?> showCameraSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool transparentScrim = false,
  ValueChanged<double>? onHeight,
  VoidCallback? onClosing,
}) {
  final brightness = MediaQuery.platformBrightnessOf(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0x00000000),
    elevation: 0,
    barrierColor: transparentScrim ? const Color(0x00000000) : const Color(0x66000000),
    builder: (_) => Theme(
      data: buildTheme(brightness),
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) onClosing?.call();
        },
        child: Builder(
          builder: (ctx) {
            final sheet = _SheetFrame(child: builder(ctx));
            return onHeight == null ? sheet : MeasureSize(onChange: (s) => onHeight(s.height), child: sheet);
          },
        ),
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  final Widget child;
  const _SheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.78),
        decoration: BoxDecoration(
          color: g.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          border: Border(top: BorderSide(color: g.border)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8 + mq.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Space.s4),
                  decoration: BoxDecoration(color: g.borderStrong, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Title + subtitle + trailing action, as in the mock's `.sheet-head`.
class SheetHead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SheetHead({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: TextSize.lg, fontWeight: FontWeight.w600, color: g.text)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: TextStyle(fontSize: TextSize.sm, color: g.text2)),
                  ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: Space.s3), action!],
        ],
      ),
    );
  }
}

enum SheetButtonKind { primary, secondary, ghost }

enum SheetButtonSize { sm, md, lg }

class SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SheetButtonKind kind;
  final SheetButtonSize size;
  final bool block;

  const SheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SheetButtonKind.primary,
    this.size = SheetButtonSize.md,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final (double h, double padX, double font, double radius) = switch (size) {
      SheetButtonSize.sm => (30.0, Space.s3, TextSize.sm, Radii.sm),
      SheetButtonSize.md => (36.0, Space.s4, TextSize.md, Radii.md),
      SheetButtonSize.lg => (44.0, Space.s4, TextSize.md, Radii.md),
    };
    final (Color bg, Color fg, Color? side) = switch (kind) {
      SheetButtonKind.primary => (g.accent, g.onAccent, null),
      SheetButtonKind.secondary => (g.bg, g.text, g.borderStrong),
      SheetButtonKind.ghost => (const Color(0x00000000), g.text2, null),
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side == null ? BorderSide.none : BorderSide(color: side),
    );
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: h,
          width: block ? double.infinity : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padX),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: TextStyle(fontSize: font, fontWeight: FontWeight.w600, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.chip` — `on` inverts to solid text colour.
class SheetChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const SheetChip({super.key, required this.label, required this.onTap, this.on = false});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.ease,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: Space.s3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? g.text : g.bg,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: on ? g.text : g.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w500, color: on ? g.bg : g.text2),
        ),
      ),
    );
  }
}

/// `.seg` segmented control.
class SheetSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const SheetSegmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: g.surface2,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: g.border),
      ),
      child: Row(
        spacing: 2,
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.ease,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? g.bg : g.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: v == value ? g.border : g.surface2),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: TextSize.sm,
                      fontWeight: FontWeight.w600,
                      color: v == value ? g.text : g.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
