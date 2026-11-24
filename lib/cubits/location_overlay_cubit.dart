import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Where the live location stands.
///  * `ready`        – receiving live fixes.
///  * `locating`     – permission + GPS ok, waiting for (a better) fix.
///  * `noPermission` – location permission not granted.
///  * `serviceOff`   – device location services are off.
///
/// In every state the last known values are kept so the stamp never goes
/// blank when GPS drops.
enum LocationStatus { ready, locating, noPermission, serviceOff }

class LocationOverlayState extends Equatable {
  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? heading;
  final String? locality;
  final String? subLocality;
  final String? administrativeArea;
  final String? country;
  final String? isoCountryCode;
  final String? streetLine;
  final String? postalCode;
  final double? altitudeMetres;
  final double? accuracyMetres;
  final double? magneticFieldMicroTesla;

  /// Time of the last position fix (not of compass updates).
  final DateTime? fixAt;

  const LocationOverlayState({
    this.status = LocationStatus.locating,
    this.latitude,
    this.longitude,
    this.heading,
    this.locality,
    this.subLocality,
    this.administrativeArea,
    this.country,
    this.isoCountryCode,
    this.streetLine,
    this.postalCode,
    this.altitudeMetres,
    this.accuracyMetres,
    this.magneticFieldMicroTesla,
    this.fixAt,
  });

  bool get hasFix => latitude != null && longitude != null;
  bool get isLive => status == LocationStatus.ready;

  static bool _ok(String? s) => s != null && s.trim().isNotEmpty;

  /// Short place name, e.g. "Indiranagar". Null until geocoded.
  String? get placeName {
    if (_ok(subLocality)) return subLocality;
    if (_ok(locality)) return locality;
    return null;
  }

  /// Secondary line, e.g. "Bengaluru, India".
  String? get areaName {
    final parts = <String>[
      if (_ok(locality) && locality != placeName) locality!,
      if (_ok(administrativeArea)) administrativeArea!,
      if (_ok(country)) country!,
    ];
    if (parts.isEmpty) return null;
    return parts.take(2).join(', ');
  }

  /// "Indiranagar, Bengaluru" — used as `Capture.place`.
  String? get shortPlace {
    final p = placeName;
    if (p == null) return null;
    final a = _ok(locality) && locality != p ? locality : (_ok(administrativeArea) ? administrativeArea : null);
    return a == null ? p : '$p, $a';
  }

  /// Full address line — used as `Capture.address`.
  String get streetBlock {
    final parts = <String>[
      if (_ok(streetLine)) streetLine!,
      if (_ok(locality)) locality!,
      if (_ok(administrativeArea))
        '${administrativeArea!}${_ok(postalCode) ? ' $postalCode' : ''}',
      if (_ok(country)) country!,
    ];
    return parts.join(', ');
  }

  LocationOverlayState copyWith({
    LocationStatus? status,
    double? latitude,
    double? longitude,
    double? heading,
    String? locality,
    String? subLocality,
    String? administrativeArea,
    String? country,
    String? isoCountryCode,
    String? streetLine,
    String? postalCode,
    double? altitudeMetres,
    double? accuracyMetres,
    double? magneticFieldMicroTesla,
    DateTime? fixAt,
  }) =>
      LocationOverlayState(
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        heading: heading ?? this.heading,
        locality: locality ?? this.locality,
        subLocality: subLocality ?? this.subLocality,
        administrativeArea: administrativeArea ?? this.administrativeArea,
        country: country ?? this.country,
        isoCountryCode: isoCountryCode ?? this.isoCountryCode,
        streetLine: streetLine ?? this.streetLine,
        postalCode: postalCode ?? this.postalCode,
        altitudeMetres: altitudeMetres ?? this.altitudeMetres,
        accuracyMetres: accuracyMetres ?? this.accuracyMetres,
        magneticFieldMicroTesla: magneticFieldMicroTesla ?? this.magneticFieldMicroTesla,
        fixAt: fixAt ?? this.fixAt,
      );

  @override
  List<Object?> get props => [
        status,
        latitude,
        longitude,
        heading,
        locality,
        subLocality,
        administrativeArea,
        country,
        isoCountryCode,
        streetLine,
        postalCode,
        altitudeMetres,
        accuracyMetres,
        magneticFieldMicroTesla,
        fixAt,
      ];
}

/// Live location + compass feed for the stamp.
///
/// Call [start] when the Capture tab is visible and [stop] when it is not.
/// [start] is idempotent and safe to call repeatedly (e.g. every time the
/// permission state changes): it re-evaluates permission / GPS service and
/// (re)starts the position stream only when it can actually produce fixes.
class LocationOverlayCubit extends Cubit<LocationOverlayState> {
  LocationOverlayCubit() : super(const LocationOverlayState());

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  DateTime _lastGeocode = DateTime.fromMillisecondsSinceEpoch(0);
  bool _starting = false;
  bool _wanted = false;
  bool _again = false;

  void _set(LocationOverlayState s) {
    if (!isClosed) emit(s);
  }

  Future<void> start() async {
    _wanted = true;
    _startSensors();
    if (_starting) {
      _again = true;
      return;
    }
    _starting = true;
    _again = false;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever ||
          perm == LocationPermission.unableToDetermine) {
        await _cancelPosition();
        _set(state.copyWith(status: LocationStatus.noPermission));
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        await _cancelPosition();
        _set(state.copyWith(status: LocationStatus.serviceOff));
        return;
      }
      if (!_wanted || _positionSub != null) return;

      if (state.status != LocationStatus.ready) {
        _set(state.copyWith(status: LocationStatus.locating));
      }

      // Seed with the OS cache so the stamp has something immediately.
      if (!state.hasFix) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && !state.hasFix) {
            _onPosition(last, live: false);
          }
        } catch (_) {}
      }
      if (!_wanted || _positionSub != null) return;

      // `high` ≈ ~10 m. distanceFilter 0 so the coordinates keep updating as
      // the user walks (the OS already smooths internally).
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0),
      ).listen(
        (p) => _onPosition(p, live: true),
        onError: (Object e) {
          // Keep last known values; just reflect the new status.
          _positionSub?.cancel();
          _positionSub = null;
          if (e is LocationServiceDisabledException) {
            _set(state.copyWith(status: LocationStatus.serviceOff));
          } else if (e is PermissionDeniedException) {
            _set(state.copyWith(status: LocationStatus.noPermission));
          } else {
            _set(state.copyWith(status: LocationStatus.locating));
          }
        },
        onDone: () => _positionSub = null,
        cancelOnError: true,
      );
    } catch (_) {
      _set(state.copyWith(status: LocationStatus.locating));
    } finally {
      _starting = false;
      if (_again && _wanted) unawaited(start());
    }
  }

  /// Called when the app learns that permission / GPS is no longer usable.
  /// Stops the stream but keeps last known values.
  Future<void> markUnavailable({required bool permissionGranted}) async {
    await _cancelPosition();
    _set(state.copyWith(
      status: permissionGranted ? LocationStatus.serviceOff : LocationStatus.noPermission,
    ));
  }

  void _startSensors() {
    // Throttle compass to ~10 Hz; raw magnetometer can fire 60+ Hz.
    if (_compassSub == null) {
      var lastHeading = DateTime.fromMillisecondsSinceEpoch(0);
      _compassSub = FlutterCompass.events?.listen((e) {
        final h = e.heading;
        if (h == null) return;
        final now = DateTime.now();
        if (now.difference(lastHeading).inMilliseconds < 100) return;
        lastHeading = now;
        _set(state.copyWith(heading: (h + 360) % 360));
      }, onError: (_) {});
    }
    if (_magnetoSub == null) {
      var lastMag = DateTime.fromMillisecondsSinceEpoch(0);
      _magnetoSub = magnetometerEventStream(samplingPeriod: const Duration(milliseconds: 200)).listen(
        (e) {
          final now = DateTime.now();
          if (now.difference(lastMag).inMilliseconds < 1000) return;
          lastMag = now;
          _set(state.copyWith(magneticFieldMicroTesla: math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z)));
        },
        onError: (_) {},
      );
    }
  }

  Future<void> _cancelPosition() async {
    final sub = _positionSub;
    _positionSub = null;
    await sub?.cancel();
  }

  Future<void> stop() async {
    _wanted = false;
    await _cancelPosition();
    final c = _compassSub, m = _magnetoSub;
    _compassSub = null;
    _magnetoSub = null;
    await c?.cancel();
    await m?.cancel();
  }

  Future<void> _onPosition(Position p, {required bool live}) async {
    _set(state.copyWith(
      status: live ? LocationStatus.ready : state.status,
      latitude: p.latitude,
      longitude: p.longitude,
      altitudeMetres: p.altitude,
      accuracyMetres: p.accuracy,
      fixAt: p.timestamp,
    ));

    // Throttle reverse-geocoding — every ~6 s max.
    final now = DateTime.now();
    if (now.difference(_lastGeocode).inSeconds < 6) return;
    _lastGeocode = now;

    try {
      final placemarks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isEmpty) return;
      final pm = placemarks.first;
      _set(state.copyWith(
        locality: pm.locality,
        subLocality: pm.subLocality?.isNotEmpty == true ? pm.subLocality : pm.locality,
        administrativeArea: pm.administrativeArea,
        country: pm.country,
        isoCountryCode: pm.isoCountryCode,
        streetLine: [pm.street, pm.thoroughfare].where((s) => s != null && s.isNotEmpty).toSet().join(', '),
        postalCode: pm.postalCode,
      ));
    } catch (_) {
      // Geocoding fails offline — coordinates are still shown.
    }
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
