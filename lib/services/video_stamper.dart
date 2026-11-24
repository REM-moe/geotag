import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ffmpeg helpers for recorded videos.
class VideoStamper {
  /// Burns [watermarkPng] along the bottom of [inputPath] (optionally
  /// mirroring front-camera frames) and writes the result to [outputPath].
  /// Audio is copied verbatim (or absent for muted recordings).
  static Future<bool> stamp({
    required String inputPath,
    required String outputPath,
    required Uint8List watermarkPng,
    bool mirror = false,
  }) async {
    final tmp = await getTemporaryDirectory();
    final wmPath = '${tmp.path}/geotag_wm_${DateTime.now().microsecondsSinceEpoch}.png';
    try {
      await File(wmPath).writeAsBytes(watermarkPng);

      // scale2ref sizes the stamp to 92 % of the frame width (4 % margin each
      // side) and keeps its aspect ratio; overlay anchors it bottom-centre.
      final base = mirror ? '[0:v]hflip[m]' : '[0:v]null[m]';
      final filter = '$base;[1:v][m]scale2ref=w=iw*0.92:h=ow/mdar[wm][bg];'
          '[bg][wm]overlay=(W-w)/2:H-h-(W*0.04)[out]';

      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i', inputPath,
        '-i', wmPath,
        '-filter_complex', filter,
        '-map', '[out]',
        '-map', '0:a?',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '23',
        '-c:a', 'copy',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        outputPath,
      ]);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) return true;
      debugPrint('[VideoStamper] ffmpeg failed rc=$rc\n${await session.getAllLogsAsString()}');
      return false;
    } catch (e) {
      debugPrint('[VideoStamper] exception: $e');
      return false;
    } finally {
      try {
        await File(wmPath).delete();
      } catch (_) {}
    }
  }

  /// Extracts the first frame of [videoPath] as a small JPEG.
  static Future<bool> posterFrame({required String videoPath, required String outputPath}) async {
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-ss', '0',
        '-i', videoPath,
        '-vframes', '1',
        '-vf', 'scale=480:-2',
        '-q:v', '4',
        outputPath,
      ]);
      final rc = await session.getReturnCode();
      return ReturnCode.isSuccess(rc) && await File(outputPath).exists();
    } catch (e) {
      debugPrint('[VideoStamper] poster exception: $e');
      return false;
    }
  }
}
