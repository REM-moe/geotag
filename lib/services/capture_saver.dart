import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import '../data/capture.dart';
import '../data/capture_repository.dart';
import 'photo_stamper.dart';
import 'video_stamper.dart';

/// Location / note snapshot taken at the moment of capture.
class CaptureMeta {
  final DateTime takenAt;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? heading;
  final double? accuracy;
  final String? place;
  final String? address;
  final String note;

  const CaptureMeta({
    required this.takenAt,
    this.latitude,
    this.longitude,
    this.altitude,
    this.heading,
    this.accuracy,
    this.place,
    this.address,
    this.note = '',
  });
}

class SaveResult {
  final Capture capture;

  /// False when the copy to the system gallery failed (e.g. access denied).
  /// The capture is still in the in-app Library.
  final bool exportedToGallery;
  const SaveResult(this.capture, this.exportedToGallery);
}

/// Stamp → app storage → Library index → system gallery copy.
class CaptureSaver {
  static const album = 'Geotag';
  final CaptureRepository repo;
  const CaptureSaver(this.repo);

  Future<SaveResult> savePhoto({
    required String rawPath,
    required CaptureMeta meta,
    Uint8List? watermarkPng,
    bool mirror = false,
    bool saveOriginal = false,
  }) async {
    final slot = repo.allocate(CaptureKind.photo);
    if (saveOriginal) await _export(() => Gal.putImage(rawPath, album: album));
    final raw = await File(rawPath).readAsBytes();
    final out = await PhotoStamper.process(baseJpeg: raw, watermarkPng: watermarkPng, mirrorBase: mirror);
    String? thumbPath;
    if (out != null) {
      await File(slot.mediaPath).writeAsBytes(out.jpeg, flush: true);
      await File(slot.thumbPath).writeAsBytes(out.thumbnail, flush: true);
      thumbPath = slot.thumbPath;
    } else {
      await File(slot.mediaPath).writeAsBytes(raw, flush: true);
    }
    await _deleteQuietly(rawPath);

    final capture = _capture(slot.id, CaptureKind.photo, slot.mediaPath, thumbPath, meta);
    await repo.add(capture);
    final ok = await _export(() => Gal.putImage(slot.mediaPath, album: album));
    return SaveResult(capture, ok);
  }

  Future<SaveResult> saveVideo({
    required String rawPath,
    required CaptureMeta meta,
    required Duration duration,
    Uint8List? watermarkPng,
    bool mirror = false,
    bool saveOriginal = false,
  }) async {
    final slot = repo.allocate(CaptureKind.video);
    if (saveOriginal && watermarkPng != null) await _export(() => Gal.putVideo(rawPath, album: album));
    var stamped = false;
    if (watermarkPng != null) {
      stamped = await VideoStamper.stamp(
        inputPath: rawPath,
        outputPath: slot.mediaPath,
        watermarkPng: watermarkPng,
        mirror: mirror,
      );
    }
    if (stamped) {
      await _deleteQuietly(rawPath);
    } else {
      try {
        await File(rawPath).rename(slot.mediaPath);
      } catch (_) {
        await File(rawPath).copy(slot.mediaPath);
        await _deleteQuietly(rawPath);
      }
    }
    final hasThumb = await VideoStamper.posterFrame(videoPath: slot.mediaPath, outputPath: slot.thumbPath);

    final capture = _capture(
      slot.id,
      CaptureKind.video,
      slot.mediaPath,
      hasThumb ? slot.thumbPath : null,
      meta,
      duration: duration,
    );
    await repo.add(capture);
    final ok = await _export(() => Gal.putVideo(slot.mediaPath, album: album));
    return SaveResult(capture, ok);
  }

  Capture _capture(String id, CaptureKind kind, String path, String? thumb, CaptureMeta m, {Duration? duration}) =>
      Capture(
        id: id,
        kind: kind,
        filePath: path,
        thumbPath: thumb,
        takenAt: m.takenAt,
        latitude: m.latitude,
        longitude: m.longitude,
        altitudeMetres: m.altitude,
        headingDegrees: m.heading,
        accuracyMetres: m.accuracy,
        place: m.place,
        address: m.address,
        note: m.note,
        videoDuration: duration,
      );

  /// Copies to the system gallery. Never throws.
  Future<bool> _export(Future<void> Function() put) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return false;
      }
      await put();
      return true;
    } on GalException catch (e) {
      debugPrint('[CaptureSaver] gallery export failed: ${e.type}');
      return false;
    } catch (e) {
      debugPrint('[CaptureSaver] gallery export failed: $e');
      return false;
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
