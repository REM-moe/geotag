import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/tokens.dart';
import 'glass.dart';

/// Real satellite-imagery thumbnail backed by **Esri World Imagery** tiles.
///
/// 100% free, no API key, no billing. Uses a long-lived MapController and
/// only re-centers when coordinates change > [_recenterMetres] — avoids
/// destroying the tile cache on every GPS tick.
class MapThumbnail extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double? headingDeg;
  final double size;
  // When false, render a lightweight static placeholder instead of the live
  // FlutterMap widget. Used inside the template picker so multiple thumbnails
  // don't fight for tile resources / map controllers.
  final bool live;

  const MapThumbnail({
    super.key,
    this.latitude,
    this.longitude,
    this.headingDeg,
    this.size = 90,
    this.live = true,
  });

  @override
  State<MapThumbnail> createState() => _MapThumbnailState();
}

class _MapThumbnailState extends State<MapThumbnail> {
  static const _esriUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const _zoom = 17.0;
  static const _recenterMetres = 5.0;

  final MapController _controller = MapController();
  LatLng? _appliedCentre;

  @override
  void didUpdateWidget(covariant MapThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeRecenter();
  }

  void _maybeRecenter() {
    if (widget.latitude == null || widget.longitude == null) return;
    final target = LatLng(widget.latitude!, widget.longitude!);
    if (_appliedCentre == null) {
      _appliedCentre = target;
      // First frame — leave to initialCenter.
      return;
    }
    final delta = const Distance().as(LengthUnit.Meter, _appliedCentre!, target);
    if (delta < _recenterMetres) return;
    _appliedCentre = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.move(target, _zoom);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = widget.latitude != null && widget.longitude != null;
    final centre = hasFix ? LatLng(widget.latitude!, widget.longitude!) : null;
    _appliedCentre ??= centre;

    final Widget content;
    if (!widget.live) {
      content = SizedBox(
        width: widget.size,
        height: widget.size,
        child: const _MapPlaceholder(),
      );
    } else {
      content = _live(hasFix, centre);
    }
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: CamColors.hairlineStrong),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(Radii.md), child: content),
    );
  }

  Widget _live(bool hasFix, LatLng? centre) {
    return SizedBox(
        width: widget.size,
        height: widget.size,
        child: hasFix
            ? RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlutterMap(
                      mapController: _controller,
                      options: MapOptions(
                        initialCenter: centre!,
                        initialZoom: _zoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                        keepAlive: true,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _esriUrl,
                          userAgentPackageName: 'com.aby.geotag',
                          tileProvider: NetworkTileProvider(),
                          // Re-use already-loaded tiles between rebuilds.
                          retinaMode: false,
                        ),
                      ],
                    ),
                    if (widget.headingDeg != null)
                      CustomPaint(painter: _HeadingCone(heading: widget.headingDeg!)),
                    const Center(child: _Pin()),
                  ],
                ),
              )
            : const _MapPlaceholder(),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GeoColors.dark.accent,
        border: Border.all(color: CamColors.fg, width: 2),
      ),
    );
  }
}

class _HeadingCone extends CustomPainter {
  final double heading;
  _HeadingCone({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    const fan = math.pi / 3;
    final start = (heading * math.pi / 180) - math.pi / 2 - fan / 2;
    final path = ui.Path()
      ..moveTo(centre.dx, centre.dy)
      ..arcTo(
        Rect.fromCircle(center: centre, radius: size.shortestSide * 0.55),
        start,
        fan,
        false,
      )
      ..close();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          GeoColors.dark.accent.withValues(alpha: 0.55),
          GeoColors.dark.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: size.shortestSide * 0.55));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingCone oldDelegate) =>
      oldDelegate.heading != heading;
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GeoColors.dark.surface3,
      child: const Center(child: _Pin()),
    );
  }
}
