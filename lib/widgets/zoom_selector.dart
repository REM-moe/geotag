import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../services/capture_prefs.dart';
import 'glass.dart';

/// Glass zoom pill: `.5  1×  2  5`. The active preset shows the live zoom
/// value (e.g. `1.4×`) after a pinch.
class ZoomSelector extends StatelessWidget {
  final double effectiveZoom;
  final bool showUltraWide;
  final ValueChanged<double> onSelect;
  final Axis direction;

  const ZoomSelector({
    super.key,
    required this.effectiveZoom,
    required this.onSelect,
    this.showUltraWide = true,
    this.direction = Axis.horizontal,
  });

  static const _presets = [0.5, 1.0, 2.0, 5.0];

  String _label(double p) => switch (p) { 0.5 => '.5', 1.0 => '1', 2.0 => '2', _ => '5' };

  String _fmt(double z) {
    final r = (z * 10).round() / 10;
    final s = r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
    return '${s.startsWith('0.') ? s.substring(1) : s}×';
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets.where((p) => showUltraWide || p >= 1).toList();
    // Active = largest preset not above the current zoom.
    var active = presets.first;
    for (final p in presets) {
      if (effectiveZoom + 0.01 >= p) active = p;
    }

    final children = [
      for (final p in presets)
        _ZoomButton(
          label: p == active ? _fmt(effectiveZoom) : _label(p),
          on: p == active,
          onTap: () {
            Haptics.selection();
            onSelect(p);
          },
        ),
    ];

    return Glass(
      padding: const EdgeInsets.all(3),
      child: Flex(
        direction: direction,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: children,
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _ZoomButton({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.ease,
        width: 36,
        height: CamSize.pill,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? CamColors.fgStrong : const Color(0x00000000),
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: monoStyle(
            size: TextSize.xs,
            color: on ? CamColors.black : CamColors.fgSoft,
            weight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
