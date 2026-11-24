import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/capture.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../detail/capture_detail_screen.dart';
import '../detail/maps_launcher.dart';
import '../library/capture_format.dart';
import '../library/capture_thumb.dart';
import '../library/captures_builder.dart';

/// Satellite tiles (Esri World Imagery — free, no API key) and OpenStreetMap
/// street fallback.
const _satelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const _streetTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgentPackage = 'com.aby.geotag';

const _darkTileFilter = ColorFilter.matrix(<double>[
  -0.85, 0, 0, 0, 225,
  0, -0.85, 0, 0, 225,
  0, 0, -0.85, 0, 225,
  0, 0, 0, 1, 0,
]);

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CapturesBuilder(
      builder: (context, items) {
        final pins = items.where((c) => c.hasLocation).toList();
        final missing = items.length - pins.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GeoPageHeader(
              title: 'Map',
              subtitle: '${pins.length} ${pins.length == 1 ? 'place' : 'places'} · $missing without location',
            ),
            Expanded(
              child: pins.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                      child: GeoEmptyState(
                        icon: Icons.map_outlined,
                        title: items.isEmpty ? 'No places yet' : 'No located captures',
                        message: items.isEmpty
                            ? 'Captures taken with location on appear here as pins.'
                            : 'None of your captures have a location. Turn on location before shooting to pin them here.',
                      ),
                    )
                  : _MapBody(pins: pins),
            ),
          ],
        );
      },
    );
  }
}

class _MapBody extends StatefulWidget {
  final List<Capture> pins;
  const _MapBody({required this.pins});

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  final _map = MapController();
  String? _selectedId;
  bool _ready = false;
  bool _satellite = true;

  static const _fitPadding = EdgeInsets.fromLTRB(56, 72, 56, 48);

  List<LatLng> get _points => [for (final c in widget.pins) LatLng(c.latitude!, c.longitude!)];

  Capture? get _selected {
    for (final c in widget.pins) {
      if (c.id == _selectedId) return c;
    }
    return widget.pins.isEmpty ? null : widget.pins.first;
  }

  @override
  void didUpdateWidget(covariant _MapBody old) {
    super.didUpdateWidget(old);
    if (_ready && old.pins.length != widget.pins.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.pins.isNotEmpty) _fitAll();
      });
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fitAll() {
    _map.fitCamera(CameraFit.coordinates(coordinates: _points, padding: _fitPadding, maxZoom: 15));
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(2, 18));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selected;

    // Column (not a scroll view) so map pan gestures never fight a scrollable.
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: g.surface2,
                border: Border.all(color: g.border),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      backgroundColor: g.surface2,
                      initialCameraFit: CameraFit.coordinates(coordinates: _points, padding: _fitPadding, maxZoom: 15),
                      minZoom: 2,
                      maxZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onMapReady: () => _ready = true,
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey(_satellite),
                        urlTemplate: _satellite ? _satelliteTileUrl : _streetTileUrl,
                        userAgentPackageName: _userAgentPackage,
                        tileBuilder: !_satellite && dark
                            ? (context, tileWidget, tile) =>
                                ColorFiltered(colorFilter: _darkTileFilter, child: tileWidget)
                            : null,
                      ),
                      MarkerLayer(
                        markers: [
                          for (final c in widget.pins)
                            Marker(
                              key: ValueKey(c.id),
                              point: LatLng(c.latitude!, c.longitude!),
                              width: 56,
                              height: 60,
                              alignment: Alignment.topCenter,
                              child: _Pin(
                                capture: c,
                                selected: c.id == selected?.id,
                                onTap: () => setState(() => _selectedId = c.id),
                              ),
                            ),
                        ],
                      ),
                      SimpleAttributionWidget(
                        backgroundColor: g.bg.withValues(alpha: 0.8),
                        source: Text(
                          _satellite ? '© Esri World Imagery' : '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 10, color: g.text2),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: Space.s3,
                    right: Space.s3,
                    child: Column(
                      children: [
                        GeoIconButton(
                          icon: _satellite ? Icons.map_outlined : Icons.satellite_alt_rounded,
                          tooltip: _satellite ? 'Switch to street map' : 'Switch to satellite',
                          onPressed: () => setState(() => _satellite = !_satellite),
                        ),
                        const SizedBox(height: Space.s2),
                        GeoIconButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onPressed: () => _zoom(1)),
                        const SizedBox(height: Space.s2),
                        GeoIconButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onPressed: () => _zoom(-1)),
                        const SizedBox(height: Space.s2),
                        GeoIconButton(icon: Icons.fit_screen_outlined, tooltip: 'Show all', onPressed: _fitAll),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected != null) ...[const SizedBox(height: Space.s4), _SelectedCard(capture: selected)],
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Capture capture;
  final bool selected;
  final VoidCallback onTap;

  const _Pin({required this.capture, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: Motion.fast,
            curve: Motion.ease,
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.md + 2),
                    color: selected ? g.accent : g.borderStrong,
                  ),
                  padding: EdgeInsets.all(selected ? 2 : 1),
                  child: Container(
                    decoration: BoxDecoration(color: g.bg, borderRadius: BorderRadius.circular(Radii.md)),
                    padding: const EdgeInsets.all(2),
                    child: CaptureThumb(capture: capture, radius: Radii.md - 2, decodeWidth: 80),
                  ),
                ),
                if (capture.hasNote)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: g.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: g.bg, width: 1.5),
                      ),
                      child: Icon(Icons.edit, size: 9, color: g.onAccent),
                    ),
                  ),
              ],
            ),
          ),
          Container(width: 2, height: 8, color: g.text),
        ],
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  final Capture capture;
  const _SelectedCard({required this.capture});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final c = capture;
    return GeoListGroup(
      children: [
        GeoListRow(
          leading: CaptureThumb(capture: c, size: 48, radius: Radii.sm, decodeWidth: 96),
          title: CaptureFormat.place(c),
          subtitle: c.hasNote ? c.note : CaptureFormat.when(c.takenAt),
          subtitleMaxLines: 1,
          chevron: true,
          onTap: () => CaptureDetailScreen.open(context, c.id),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [CaptureFormat.coords(c), if (c.altitudeMetres != null) CaptureFormat.altitude(c)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: TextSize.xs, color: g.text2),
                ),
              ),
              const SizedBox(width: Space.s2),
              GeoButton(
                label: 'Directions',
                icon: Icons.directions_outlined,
                variant: GeoButtonVariant.ghost,
                size: GeoButtonSize.sm,
                onPressed: () async {
                  final ok = await MapsLauncher.directions(c);
                  if (!ok && context.mounted) showGeoToast(context, 'No maps app found', success: false);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
