import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Captures a widget tree (wrapped in `RepaintBoundary`) into a transparent
/// PNG at device pixel ratio.
class WatermarkCapture {
  static Future<Uint8List?> captureFromBoundary(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
