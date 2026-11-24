import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../cubits/location_overlay_cubit.dart';
import '../data/capture.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/map_thumbnail.dart';

/// Stamp layouts. Persisted by `.name`.
enum TemplateId { classic, timestamp, survey, minimal }

/// Background behind the stamp.
enum StampSurface { glass, solid, none }

class TemplateMeta {
  final TemplateId id;
  final String name;
  final String description;
  const TemplateMeta(this.id, this.name, this.description);
}

const kTemplates = <TemplateMeta>[
  TemplateMeta(TemplateId.classic, 'Classic', 'Map, place, coordinates'),
  TemplateMeta(TemplateId.timestamp, 'Timestamp', 'Large time, place'),
  TemplateMeta(TemplateId.survey, 'Survey', 'Lat · Lng · Alt grid'),
  TemplateMeta(TemplateId.minimal, 'Minimal', 'One line, no box'),
];

TemplateMeta templateMeta(TemplateId id) => kTemplates.firstWhere((t) => t.id == id);

extension StampSurfaceX on StampSurface {
  String get label => switch (this) {
        StampSurface.glass => 'Glass',
        StampSurface.solid => 'Solid',
        StampSurface.none => 'No box',
      };
}

/// Everything the user can tweak in the Stamp studio.
class StampConfig extends Equatable {
  final TemplateId template;
  final StampSurface surface;
  final bool showMap;
  final bool showCoords;
  final bool showAltHeading;

  const StampConfig({
    this.template = TemplateId.classic,
    this.surface = StampSurface.glass,
    this.showMap = true,
    this.showCoords = true,
    this.showAltHeading = true,
  });

  StampConfig copyWith({
    TemplateId? template,
    StampSurface? surface,
    bool? showMap,
    bool? showCoords,
    bool? showAltHeading,
  }) =>
      StampConfig(
        template: template ?? this.template,
        surface: surface ?? this.surface,
        showMap: showMap ?? this.showMap,
        showCoords: showCoords ?? this.showCoords,
        showAltHeading: showAltHeading ?? this.showAltHeading,
      );

  @override
  List<Object?> get props => [template, surface, showMap, showCoords, showAltHeading];
}

// ──────────────────────────────────────────────────────────────────────────
// Formatting

String formatLat(double v) => '${v.abs().toStringAsFixed(5)}° ${v >= 0 ? 'N' : 'S'}';
String formatLng(double v) => '${v.abs().toStringAsFixed(5)}° ${v >= 0 ? 'E' : 'W'}';
String formatAltitude(double? m) => m == null ? '— m' : '${m.round()} m';

String cardinal(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[(((deg % 360) + 22.5) ~/ 45) % 8];
}

String formatHeading(double? deg) => deg == null ? '—°' : '${deg.round() % 360}° ${cardinal(deg)}';

/// Values rendered by a stamp — built either from the live feed or from a
/// saved [Capture] (Library / detail screens).
class StampData {
  final bool hasLocation;
  final String place;
  final String area;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? heading;
  final DateTime time;
  final String note;

  const StampData({
    required this.hasLocation,
    required this.place,
    required this.area,
    required this.time,
    this.latitude,
    this.longitude,
    this.altitude,
    this.heading,
    this.note = '',
  });

  factory StampData.live(LocationOverlayState s, {String note = '', DateTime? now}) {
    final fix = s.hasFix;
    final name = s.placeName;
    final coords = fix ? '${formatLat(s.latitude!)}, ${formatLng(s.longitude!)}' : null;
    String place;
    String area;
    switch (s.status) {
      case LocationStatus.ready:
        place = name ?? 'Unnamed place';
        area = s.areaName ?? coords ?? '';
      case LocationStatus.locating:
        place = fix ? (name ?? 'Locating…') : 'Locating…';
        area = fix ? (s.areaName ?? 'Improving accuracy') : 'Waiting for GPS';
      case LocationStatus.serviceOff:
        place = fix ? 'Last known · ${name ?? 'this area'}' : 'No location';
        area = fix ? 'Location services off' : 'Location services off';
      case LocationStatus.noPermission:
        place = fix ? 'Last known · ${name ?? 'this area'}' : 'No location';
        area = 'Location permission off';
    }
    return StampData(
      hasLocation: fix,
      place: place,
      area: area,
      latitude: s.latitude,
      longitude: s.longitude,
      altitude: s.altitudeMetres,
      heading: s.heading,
      time: now ?? DateTime.now(),
      note: note,
    );
  }

  factory StampData.fromCapture(Capture c) => StampData(
        hasLocation: c.hasLocation,
        place: c.place ?? (c.hasLocation ? 'Unnamed place' : 'No location'),
        area: c.address ?? '',
        latitude: c.latitude,
        longitude: c.longitude,
        altitude: c.altitudeMetres,
        heading: c.headingDegrees,
        time: c.takenAt,
        note: c.note,
      );

  String get latText => latitude == null ? '—' : formatLat(latitude!);
  String get lngText => longitude == null ? '—' : formatLng(longitude!);
  String get altText => formatAltitude(altitude);
  String get headingText => formatHeading(heading);
  String get timeText => DateFormat('HH:mm').format(time);
  String get dateText => DateFormat('d MMM yyyy').format(time);
  String get stampText => '$dateText · $timeText';
}

// ──────────────────────────────────────────────────────────────────────────
// Stamp widget

class _Palette {
  final Color fg;
  final Color divider;
  final Color cell;
  final List<Shadow>? shadows;
  const _Palette(this.fg, this.divider, this.cell, this.shadows);

  static _Palette of(StampSurface s) => switch (s) {
        StampSurface.solid => _Palette(GeoColors.light.text, GeoColors.light.border, GeoColors.light.surface2, null),
        StampSurface.glass => const _Palette(CamColors.fg, CamColors.hairline, CamColors.fill, null),
        StampSurface.none => const _Palette(
            CamColors.fg,
            CamColors.hairline,
            CamColors.fill,
            [Shadow(color: CamColors.textShadow, blurRadius: 6, offset: Offset(0, 1))],
          ),
      };
}

/// Renders a stamp for [config] + [data]. Pure widget (no blocs) so it can be
/// used live on the viewfinder, in the Library detail view, or burned into
/// media via a `RepaintBoundary`.
class StampView extends StatelessWidget {
  final StampConfig config;
  final StampData data;

  /// Live satellite tile for the Classic map. Off = static placeholder.
  final bool liveMap;

  const StampView({super.key, required this.config, required this.data, this.liveMap = true});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(config.surface);
    final body = DefaultTextStyle.merge(
      style: TextStyle(color: p.fg, shadows: p.shadows, height: 1.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (config.template) {
            TemplateId.classic => _classic(p),
            TemplateId.timestamp => _timestamp(p),
            TemplateId.survey => _survey(p),
            TemplateId.minimal => _minimal(p),
          },
          if (data.note.trim().isNotEmpty) _note(p),
        ],
      ),
    );

    const radius = BorderRadius.all(Radius.circular(Radii.lg));
    switch (config.surface) {
      case StampSurface.glass:
        return Glass(
          borderRadius: radius,
          color: CamColors.stampGlass,
          borderColor: CamColors.hairline,
          padding: const EdgeInsets.all(Space.s3),
          child: body,
        );
      case StampSurface.solid:
        return AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          padding: const EdgeInsets.all(Space.s3),
          decoration: BoxDecoration(
            color: GeoColors.light.bg,
            borderRadius: radius,
            border: Border.all(color: GeoColors.light.bg),
          ),
          child: body,
        );
      case StampSurface.none:
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: body);
    }
  }

  TextStyle _title([double size = TextSize.md]) => TextStyle(fontSize: size, fontWeight: FontWeight.w600);
  TextStyle _sub(_Palette p) => TextStyle(fontSize: TextSize.xs, color: p.fg.withValues(alpha: 0.7));
  TextStyle _mono(_Palette p, [double alpha = 0.85]) =>
      monoStyle(size: TextSize.xs, color: p.fg.withValues(alpha: alpha)).copyWith(shadows: p.shadows, height: 1.35);

  Widget _text(String s, TextStyle style, {TextAlign align = TextAlign.start}) =>
      Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style, textAlign: align);

  Widget _classic(_Palette p) {
    final f = config;
    final monoParts = <String>[
      if (f.showCoords) '${data.latText}, ${data.lngText}',
      if (f.showAltHeading) ...[data.altText, data.headingText],
    ];
    return Row(
      children: [
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.ease,
          child: f.showMap && data.hasLocation
              ? Padding(
                  padding: const EdgeInsets.only(right: Space.s3),
                  child: MapThumbnail(
                    latitude: data.latitude,
                    longitude: data.longitude,
                    headingDeg: data.heading,
                    size: 56,
                    live: liveMap,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _text(data.place, _title()),
              if (data.area.isNotEmpty) _text(data.area, _sub(p)),
              if (monoParts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s1),
                  child: Wrap(
                    spacing: Space.s3,
                    children: [for (final m in monoParts) Text(m, style: _mono(p))],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _text(data.stampText, _mono(p, 0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timestamp(_Palette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          data.timeText,
          style: TextStyle(
            fontSize: CamSize.displayText,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _text(data.place, _title(), align: TextAlign.end),
              _text(data.dateText, _sub(p), align: TextAlign.end),
              if (config.showCoords)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s1),
                  child: _text('${data.latText}, ${data.lngText}', _mono(p), align: TextAlign.end),
                ),
              if (config.showAltHeading)
                _text('${data.altText}  ${data.headingText}', _mono(p, 0.6), align: TextAlign.end),
            ],
          ),
        ),
      ],
    );
  }

  Widget _survey(_Palette p) {
    Widget cell(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: 6),
            decoration: BoxDecoration(color: p.cell, borderRadius: BorderRadius.circular(Radii.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: CamSize.microText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: p.fg.withValues(alpha: 0.6),
                  ),
                ),
                _text(value, _mono(p, 1)),
              ],
            ),
          ),
        );
    final cells = <Widget>[
      if (config.showCoords) ...[cell('LAT', data.latText), cell('LNG', data.lngText)],
      if (config.showAltHeading) ...[cell('ALT', data.altText), if (!config.showCoords) cell('HDG', data.headingText)],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _text(data.place, _title()),
        _text(config.showAltHeading && config.showCoords ? '${data.stampText} · ${data.headingText}' : data.stampText,
            _sub(p)),
        if (cells.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.s2),
                  cells[i],
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _minimal(_Palette p) {
    final line = [
      data.stampText,
      if (config.showCoords && data.hasLocation) '${data.latText}, ${data.lngText}',
      if (config.showAltHeading) data.headingText,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _text(data.place, _title(TextSize.sm)),
        Padding(padding: const EdgeInsets.only(top: 2), child: _text(line, _mono(p))),
      ],
    );
  }

  Widget _note(_Palette p) {
    return Container(
      margin: const EdgeInsets.only(top: Space.s2),
      padding: const EdgeInsets.only(top: Space.s2),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.divider))),
      child: _text(data.note.trim(), const TextStyle(fontSize: TextSize.xs)),
    );
  }
}
