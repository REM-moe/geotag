import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../cubits/location_overlay_cubit.dart';
import '../widgets/map_thumbnail.dart';

/// Identifier for each watermark layout. Persisted as `.name` string.
enum TemplateId { classic, datetime, reporting, navigational, minimal }

class TemplateMeta {
  final TemplateId id;
  final String name;
  final String tagline;
  const TemplateMeta(this.id, this.name, this.tagline);
}

const kTemplates = <TemplateMeta>[
  TemplateMeta(TemplateId.classic, 'Classic',
      'Satellite map · place · address · coords · time'),
  TemplateMeta(TemplateId.datetime, 'DateTime', 'Big time + date over location'),
  TemplateMeta(TemplateId.reporting, 'Reporting',
      'Check-in pill, map, full address'),
  TemplateMeta(TemplateId.navigational, 'Navigational',
      'Live compass, heading, altitude'),
  TemplateMeta(TemplateId.minimal, 'Minimal', 'One-line place + coordinates'),
];

/// Builds the widget for a given template id.
Widget buildTemplate(
  TemplateId id,
  LocationOverlayState s, {
  bool compact = false,
  bool liveMap = true,
}) {
  switch (id) {
    case TemplateId.classic:
      return _ClassicTemplate(state: s, compact: compact, liveMap: liveMap);
    case TemplateId.datetime:
      return _DateTimeTemplate(state: s);
    case TemplateId.reporting:
      return _ReportingTemplate(state: s, liveMap: liveMap);
    case TemplateId.navigational:
      return _NavigationalTemplate(state: s, liveMap: liveMap);
    case TemplateId.minimal:
      return _MinimalTemplate(state: s);
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Shared bits

String _flagEmoji(String? iso) {
  if (iso == null || iso.length != 2) return '';
  final base = 0x1F1E6 - 'A'.codeUnitAt(0);
  return String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => c + base));
}

String _coords(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Searching for GPS…';
  return 'Lat ${lat.toStringAsFixed(6)}, Long ${lng.toStringAsFixed(6)}';
}

BoxDecoration _cardBg() => BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 6),
        )
      ],
    );

// ──────────────────────────────────────────────────────────────────────────
// 1. Classic — current default layout (map + place + address)

class _ClassicTemplate extends StatelessWidget {
  final LocationOverlayState state;
  final bool compact;
  final bool liveMap;
  const _ClassicTemplate({
    required this.state,
    this.compact = false,
    this.liveMap = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, dd/MM/yyyy hh:mm a');
    final tz = state.updatedAt.timeZoneName;
    final dateLine = '${dateFmt.format(state.updatedAt)} $tz';

    return Container(
      decoration: _cardBg(),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MapThumbnail(
            latitude: state.latitude,
            longitude: state.longitude,
            headingDeg: state.heading,
            size: compact ? 72 : 90,
            live: liveMap,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.headlinePlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 15 : 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_flagEmoji(state.isoCountryCode),
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  state.streetBlock.isEmpty
                      ? 'Resolving address…'
                      : state.streetBlock,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _coords(state.latitude, state.longitude),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
                if (state.altitudeMetres != null || state.accuracyMetres != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (state.altitudeMetres != null) ...[
                        const Icon(Icons.terrain, size: 11, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text('${state.altitudeMetres!.toStringAsFixed(1)} m',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10.5)),
                      ],
                      if (state.accuracyMetres != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.gps_fixed,
                            size: 11, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text('±${state.accuracyMetres!.toStringAsFixed(0)} m',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10.5)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 2. DateTime — big time on left, date stacked beside, location underneath

class _DateTimeTemplate extends StatelessWidget {
  final LocationOverlayState state;
  const _DateTimeTemplate({required this.state});

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('hh:mm a').format(state.updatedAt);
    final d = DateFormat('dd MMM yyyy').format(state.updatedAt);
    final day = DateFormat('EEEE').format(state.updatedAt);

    return Container(
      decoration: _cardBg(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  hm,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 2,
                  color: Colors.amber,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1.1)),
                    const SizedBox(height: 2),
                    Text(day,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(
                  state.headlinePlace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(_flagEmoji(state.isoCountryCode),
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            state.streetBlock.isEmpty ? 'Resolving address…' : state.streetBlock,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            _coords(state.latitude, state.longitude),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 3. Reporting — Classic + green "Check In" pill above the map

class _ReportingTemplate extends StatelessWidget {
  final LocationOverlayState state;
  final bool liveMap;
  const _ReportingTemplate({required this.state, this.liveMap = true});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, dd/MM/yyyy hh:mm a');
    final tz = state.updatedAt.timeZoneName;
    final dateLine = '${dateFmt.format(state.updatedAt)} $tz';

    return Container(
      decoration: _cardBg(),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Check In',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              MapThumbnail(
                latitude: state.latitude,
                longitude: state.longitude,
                headingDeg: state.heading,
                size: 78,
                live: liveMap,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.headlinePlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_flagEmoji(state.isoCountryCode),
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  state.streetBlock.isEmpty
                      ? 'Resolving address…'
                      : state.streetBlock,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _coords(state.latitude, state.longitude),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 4. Navigational — compass + bearing + altitude + tiny map thumbnail

class _NavigationalTemplate extends StatelessWidget {
  final LocationOverlayState state;
  final bool liveMap;
  const _NavigationalTemplate({required this.state, this.liveMap = true});

  String _cardinal(double? deg) {
    if (deg == null) return '–';
    const dirs = ['N','NE','E','SE','S','SW','W','NW'];
    final i = (((deg % 360) + 22.5) ~/ 45) % 8;
    return dirs[i];
  }

  String _facing(String? c) => c == null ? '' : 'Facing $c';

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, dd/MM/yyyy hh:mm a');
    final dateLine = dateFmt.format(state.updatedAt);
    final card = _cardinal(state.heading);
    final headingTxt =
        state.heading == null ? '–' : '${state.heading!.toStringAsFixed(0)}° $card';
    final alt = state.altitudeMetres == null
        ? '–'
        : '${state.altitudeMetres!.toStringAsFixed(1)} m';

    return Container(
      decoration: _cardBg(),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compass column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _CompassPainter(heading: state.heading ?? 0),
                  child: Center(
                    child: Text(
                      headingTxt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _facing(card),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.headlinePlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_flagEmoji(state.isoCountryCode),
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  state.streetBlock.isEmpty
                      ? 'Resolving address…'
                      : state.streetBlock,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _coords(state.latitude, state.longitude),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  dateLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 3,
                  children: [
                    _StatChip(icon: Icons.terrain, label: alt),
                    _StatChip(
                      icon: Icons.explore,
                      label: 'Azim ${state.heading?.toStringAsFixed(1) ?? '–'}°',
                    ),
                    if (state.magneticFieldMicroTesla != null)
                      _StatChip(
                        icon: Icons.bolt,
                        label:
                            '${state.magneticFieldMicroTesla!.toStringAsFixed(0)} µT',
                      ),
                    if (state.accuracyMetres != null)
                      _StatChip(
                        icon: Icons.gps_fixed,
                        label: '±${state.accuracyMetres!.toStringAsFixed(0)} m',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          MapThumbnail(
            latitude: state.latitude,
            longitude: state.longitude,
            headingDeg: state.heading,
            size: 56,
            live: liveMap,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  _CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 2;

    // Outer ring
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF1B1F24).withValues(alpha: 0.85));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.4));

    // Tick marks every 15°
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (int deg = 0; deg < 360; deg += 15) {
      final angle = (deg - 90) * math.pi / 180;
      final isMajor = deg % 90 == 0;
      final inner = r - (isMajor ? 8 : 4);
      final p1 = Offset(c.dx + math.cos(angle) * inner,
          c.dy + math.sin(angle) * inner);
      final p2 = Offset(c.dx + math.cos(angle) * (r - 1),
          c.dy + math.sin(angle) * (r - 1));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // N / E / S / W labels
    void label(String s, double deg, Color color) {
      final angle = (deg - 90) * math.pi / 180;
      final inset = r - 18;
      final p = Offset(c.dx + math.cos(angle) * inset,
          c.dy + math.sin(angle) * inset);
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    label('N', 0, Colors.redAccent);
    label('E', 90, Colors.white);
    label('S', 180, Colors.white);
    label('W', 270, Colors.white);

    // Needle pointing to heading (red north)
    final needleAngle = (heading - 90) * math.pi / 180;
    final tip = Offset(
        c.dx + math.cos(needleAngle) * (r - 14),
        c.dy + math.sin(needleAngle) * (r - 14));
    final left = Offset(c.dx + math.cos(needleAngle + math.pi * 0.92) * 6,
        c.dy + math.sin(needleAngle + math.pi * 0.92) * 6);
    final right = Offset(c.dx + math.cos(needleAngle - math.pi * 0.92) * 6,
        c.dy + math.sin(needleAngle - math.pi * 0.92) * 6);
    final needle = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFE53935));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.heading != heading;
}

// ──────────────────────────────────────────────────────────────────────────
// 5. Minimal — single line, low chrome

class _MinimalTemplate extends StatelessWidget {
  final LocationOverlayState state;
  const _MinimalTemplate({required this.state});

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('HH:mm').format(state.updatedAt);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.headlinePlace,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.latitude == null
                ? '–'
                : '${state.latitude!.toStringAsFixed(4)}, ${state.longitude!.toStringAsFixed(4)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hm,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
