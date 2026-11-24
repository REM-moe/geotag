import 'package:equatable/equatable.dart';

enum CaptureKind { photo, video }

/// One geotagged photo or video stored in the in-app Library.
///
/// Media files live in the app's private documents directory (no storage
/// permission needed). A stamped copy is additionally exported to the system
/// gallery via `gal`.
class Capture extends Equatable {
  final String id;
  final CaptureKind kind;

  /// Absolute path of the stamped media file inside app storage.
  final String filePath;

  /// Absolute path of a small JPEG thumbnail (for videos: a poster frame,
  /// may be null if extraction failed).
  final String? thumbPath;

  final DateTime takenAt;

  /// Null when the shot was taken without a location fix.
  final double? latitude;
  final double? longitude;
  final double? altitudeMetres;
  final double? headingDegrees;
  final double? accuracyMetres;

  /// Short human place, e.g. "Indiranagar, Bengaluru".
  final String? place;

  /// Longer address line.
  final String? address;

  /// Location-based note attached to this capture. Empty string = no note.
  final String note;

  final Duration? videoDuration;

  const Capture({
    required this.id,
    required this.kind,
    required this.filePath,
    required this.takenAt,
    this.thumbPath,
    this.latitude,
    this.longitude,
    this.altitudeMetres,
    this.headingDegrees,
    this.accuracyMetres,
    this.place,
    this.address,
    this.note = '',
    this.videoDuration,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasNote => note.trim().isNotEmpty;
  bool get isVideo => kind == CaptureKind.video;

  Capture copyWith({String? note, String? thumbPath}) => Capture(
        id: id,
        kind: kind,
        filePath: filePath,
        takenAt: takenAt,
        thumbPath: thumbPath ?? this.thumbPath,
        latitude: latitude,
        longitude: longitude,
        altitudeMetres: altitudeMetres,
        headingDegrees: headingDegrees,
        accuracyMetres: accuracyMetres,
        place: place,
        address: address,
        note: note ?? this.note,
        videoDuration: videoDuration,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'filePath': filePath,
        'thumbPath': thumbPath,
        'takenAt': takenAt.toIso8601String(),
        'lat': latitude,
        'lng': longitude,
        'alt': altitudeMetres,
        'hdg': headingDegrees,
        'acc': accuracyMetres,
        'place': place,
        'address': address,
        'note': note,
        'durMs': videoDuration?.inMilliseconds,
      };

  factory Capture.fromJson(Map<String, dynamic> j) => Capture(
        id: j['id'] as String,
        kind: CaptureKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => CaptureKind.photo,
        ),
        filePath: j['filePath'] as String,
        thumbPath: j['thumbPath'] as String?,
        takenAt: DateTime.parse(j['takenAt'] as String),
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lng'] as num?)?.toDouble(),
        altitudeMetres: (j['alt'] as num?)?.toDouble(),
        headingDegrees: (j['hdg'] as num?)?.toDouble(),
        accuracyMetres: (j['acc'] as num?)?.toDouble(),
        place: j['place'] as String?,
        address: j['address'] as String?,
        note: (j['note'] as String?) ?? '',
        videoDuration: j['durMs'] == null ? null : Duration(milliseconds: j['durMs'] as int),
      );

  @override
  List<Object?> get props => [id, filePath, thumbPath, note, takenAt];
}
