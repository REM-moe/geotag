import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/capture.dart';
import '../../theme/tokens.dart';

/// Square-cropped thumbnail for a capture. Uses `thumbPath`, falling back
/// to the media file itself for photos, then to a neutral placeholder.
class CaptureThumb extends StatelessWidget {
  final Capture capture;
  final double? size;
  final double radius;

  /// Decode width hint in logical pixels (multiplied by DPR).
  final double decodeWidth;

  const CaptureThumb({
    super.key,
    required this.capture,
    this.size,
    this.radius = 0,
    this.decodeWidth = 160,
  });

  String? get _path => capture.thumbPath ?? (capture.isVideo ? null : capture.filePath);

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final placeholder = Container(
      color: g.surface2,
      alignment: Alignment.center,
      child: Icon(
        capture.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        size: 18,
        color: g.text3,
      ),
    );
    final path = _path;
    Widget img = path == null
        ? placeholder
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: (decodeWidth * dpr).round(),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) {
              // Thumb missing — fall back to the full photo once.
              if (path != capture.filePath && !capture.isVideo) {
                return Image.file(
                  File(capture.filePath),
                  fit: BoxFit.cover,
                  cacheWidth: (decodeWidth * dpr).round(),
                  errorBuilder: (_, _, _) => placeholder,
                );
              }
              return placeholder;
            },
          );
    img = ColoredBox(color: g.surface2, child: img);
    if (radius > 0) img = ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
    if (size != null) img = SizedBox.square(dimension: size, child: img);
    return img;
  }
}
