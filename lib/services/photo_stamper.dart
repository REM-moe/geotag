import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Composites the captured watermark PNG onto the base JPEG bytes and
/// (optionally) flips horizontally for front-camera shots so text reads
/// correctly instead of mirrored.
class PhotoStamper {
  static Future<Uint8List?> stamp({
    required Uint8List baseJpeg,
    Uint8List? watermarkPng,
    bool mirrorBase = false,
    double paddingPct = 0.04,
    double widthPct = 0.92,
  }) async {
    var base = img.decodeJpg(baseJpeg);
    if (base == null) return null;

    if (mirrorBase) {
      base = img.flipHorizontal(base);
    }

    if (watermarkPng != null) {
      final mark = img.decodePng(watermarkPng);
      if (mark != null) {
        final targetW = (base.width * widthPct).round();
        final scaled = img.copyResize(
          mark,
          width: targetW,
          interpolation: img.Interpolation.linear,
        );
        final pad = (base.width * paddingPct).round();
        final dx = ((base.width - scaled.width) / 2).round();
        final dy = base.height - scaled.height - pad;
        img.compositeImage(base, scaled, dstX: dx, dstY: dy);
      }
    }

    return Uint8List.fromList(img.encodeJpg(base, quality: 92));
  }
}
