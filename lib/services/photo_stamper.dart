import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Output of [PhotoStamper.process].
class StampedPhoto {
  final Uint8List jpeg;
  final Uint8List thumbnail;
  const StampedPhoto(this.jpeg, this.thumbnail);
}

/// Composites the stamp PNG onto the captured JPEG and produces a small
/// thumbnail. Runs on a background isolate so the viewfinder never stutters.
class PhotoStamper {
  static const thumbWidth = 480;

  static Future<StampedPhoto?> process({
    required Uint8List baseJpeg,
    Uint8List? watermarkPng,
    bool mirrorBase = false,
  }) =>
      Isolate.run(() => _process(baseJpeg, watermarkPng, mirrorBase));

  static StampedPhoto? _process(Uint8List baseJpeg, Uint8List? watermarkPng, bool mirror) {
    var base = img.decodeJpg(baseJpeg);
    if (base == null) return null;
    base = img.bakeOrientation(base);
    if (mirror) base = img.flipHorizontal(base);

    if (watermarkPng != null) {
      final mark = img.decodePng(watermarkPng);
      if (mark != null) {
        // Stamp spans the frame width minus a margin, anchored bottom-centre —
        // mirrors where it sits on the viewfinder.
        final pad = (base.width * 0.04).round();
        final targetW = base.width - pad * 2;
        final scaled = img.copyResize(mark, width: targetW, interpolation: img.Interpolation.cubic);
        final dx = ((base.width - scaled.width) / 2).round();
        final dy = base.height - scaled.height - pad;
        img.compositeImage(base, scaled, dstX: dx, dstY: dy);
      }
    }

    final jpeg = Uint8List.fromList(img.encodeJpg(base, quality: 92));
    final thumb = img.copyResize(base, width: thumbWidth, interpolation: img.Interpolation.average);
    return StampedPhoto(jpeg, Uint8List.fromList(img.encodeJpg(thumb, quality: 80)));
  }
}
