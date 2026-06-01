import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Post-processes a captured video file: overlays the watermark PNG along the
/// bottom and (optionally) horizontally flips the frames for front-camera
/// recordings. Audio stream is copied verbatim.
class VideoStamper {
  static Future<String?> stamp({
    required String inputPath,
    required Uint8List watermarkPng,
    bool mirror = false,
    double widthPct = 0.92,
    double paddingPct = 0.04,
  }) async {
    try {
      final tmp = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final wmPath = '${tmp.path}/geotag_wm_$ts.png';
      final outPath = '${tmp.path}/geotag_$ts.mp4';

      await File(wmPath).writeAsBytes(watermarkPng);

      // scale2ref keeps watermark proportional to the video's width even
      // when we don't know the resolution upfront. hflip applied first when
      // mirroring.
      //
      //   [base][wm] inputs →
      //   scale2ref scales wm to widthPct × base_w, keeps aspect ratio
      //   overlay centred horizontally, paddingPct × base_w from the bottom
      final base = mirror ? '[0]hflip[m]' : '[0]null[m]';
      final filter =
          '$base;[1][m]scale2ref=w=iw*$widthPct:h=ow/mdar[wm][bg];'
          '[bg][wm]overlay=(W-w)/2:H-h-(W*$paddingPct)';

      final args = [
        '-y',
        '-i', inputPath,
        '-i', wmPath,
        '-filter_complex', filter,
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '23',
        '-c:a', 'copy',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        outPath,
      ];

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();

      try {
        await File(wmPath).delete();
      } catch (_) {}

      if (ReturnCode.isSuccess(rc)) return outPath;

      // Surface ffmpeg failure for debugging via console.
      final logs = await session.getAllLogsAsString();
      // ignore: avoid_print
      print('[VideoStamper] ffmpeg failed rc=$rc\n$logs');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[VideoStamper] exception: $e');
      return null;
    }
  }
}
