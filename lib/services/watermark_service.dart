import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Captures a widget subtree (wrapped in `RepaintBoundary`) into a
/// transparent PNG.
class WatermarkCapture {
  static Future<Uint8List?> captureFromBoundary(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
