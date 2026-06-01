import 'package:flutter/material.dart';

import '../cubits/camera_cubit.dart';

/// iPhone-native style zoom row: presets like 0.5× / 1× / 2× / 5×.
/// A preset is shown if either (a) a physical lens with that label exists, or
/// (b) the current lens has enough digital zoom range to reach that effective
/// magnification. Tapping a preset either switches lenses or applies digital
/// zoom, transparently.
class ZoomSelector extends StatelessWidget {
  final double effectiveZoom;
  final double maxZoomOnActive;
  final double activeLensLabel;
  final List<LensOption> lenses;
  final ValueChanged<double> onSelectPreset;

  const ZoomSelector({
    super.key,
    required this.effectiveZoom,
    required this.maxZoomOnActive,
    required this.activeLensLabel,
    required this.lenses,
    required this.onSelectPreset,
  });

  static const List<double> _kPresets = [0.5, 1.0, 2.0, 5.0];

  String _fmt(double z) {
    if (z < 1) return '${z.toStringAsFixed(1)}×';
    if (z == z.truncateToDouble()) return '${z.toInt()}×';
    return '${z.toStringAsFixed(1)}×';
  }

  @override
  Widget build(BuildContext context) {
    // Presets to show: physical lens matches OR within digital reach.
    final shown = <double>[];
    for (final p in _kPresets) {
      final hasPhysical = lenses.any((l) => (l.label - p).abs() < 0.05);
      // Digital reach: preset / active label must be within [1.0, maxZoomOnActive]
      // (we don't allow zooming out below 1× on a given lens).
      final digitalRatio = p / activeLensLabel;
      final reachable = digitalRatio >= 1.0 && digitalRatio <= maxZoomOnActive;
      if (hasPhysical || reachable) shown.add(p);
    }

    if (shown.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: shown.map((p) {
          final selected = (effectiveZoom - p).abs() < 0.15;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onSelectPreset(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 44 : 36,
                height: selected ? 44 : 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.amber : Colors.white.withValues(alpha: 0.06),
                ),
                child: Text(
                  _fmt(p),
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: selected ? 13 : 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
