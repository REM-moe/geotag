import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Semantic tone shared by badges and alerts.
enum GeoTone { neutral, positive, warning, negative, accent }

extension GeoToneColors on GeoTone {
  /// (foreground, background) pair for this tone.
  (Color fg, Color bg) resolve(GeoColors g) => switch (this) {
        GeoTone.neutral => (g.text2, g.surface2),
        GeoTone.positive => (g.positive, g.positiveSoft),
        GeoTone.warning => (g.warning, g.warningSoft),
        GeoTone.negative => (g.negative, g.negativeSoft),
        GeoTone.accent => (g.accent, g.accentSoft),
      };
}

/// Small pill label, optionally with a status dot (mock `.badge`).
class GeoBadge extends StatelessWidget {
  final String label;
  final GeoTone tone;
  final bool dot;

  const GeoBadge(this.label, {super.key, this.tone = GeoTone.neutral, this.dot = false});

  const GeoBadge.positive(this.label, {super.key, this.dot = true}) : tone = GeoTone.positive;
  const GeoBadge.warning(this.label, {super.key, this.dot = true}) : tone = GeoTone.warning;
  const GeoBadge.negative(this.label, {super.key, this.dot = true}) : tone = GeoTone.negative;
  const GeoBadge.accent(this.label, {super.key, this.dot = false}) : tone = GeoTone.accent;

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final (fg, bg) = tone.resolve(g);
    return Container(
      height: Space.s5,
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: tone == GeoTone.neutral ? g.border : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.s1),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(fontSize: TextSize.xs, fontWeight: FontWeight.w600, color: fg, height: 1),
          ),
        ],
      ),
    );
  }
}
