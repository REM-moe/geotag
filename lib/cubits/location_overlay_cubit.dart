import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class LocationOverlayState extends Equatable {
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
  final DateTime updatedAt;
  final bool hasFix;

  LocationOverlayState({
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
    DateTime? updatedAt,
    this.hasFix = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  String get headlinePlace {
    final parts = <String>[
      if (subLocality != null && subLocality!.isNotEmpty) subLocality!,
      if (administrativeArea != null && administrativeArea!.isNotEmpty) administrativeArea!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.isEmpty ? 'Locating…' : parts.join(', ');
  }

  String get streetBlock {
    final parts = <String>[
      if (streetLine != null && streetLine!.isNotEmpty) streetLine!,
      if (locality != null && locality!.isNotEmpty) locality!,
      if (administrativeArea != null && administrativeArea!.isNotEmpty)
        '${administrativeArea!}${postalCode != null && postalCode!.isNotEmpty ? ' $postalCode' : ''}',
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  LocationOverlayState copyWith({
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
    DateTime? updatedAt,
    bool? hasFix,
  }) =>
      LocationOverlayState(
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
        updatedAt: updatedAt ?? this.updatedAt,
        hasFix: hasFix ?? this.hasFix,
      );

  @override
  List<Object?> get props => [
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
        updatedAt,
        hasFix,
      ];
}

class LocationOverlayCubit extends Cubit<LocationOverlayState> {
  LocationOverlayCubit() : super(LocationOverlayState());

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<MagnetometerEvent>? _magnetoSub;
  DateTime _lastGeocode = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start() async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) return;

    // `high` ≈ ~10m accuracy. distanceFilter=0 means iOS pushes every fix
    // (the OS already smooths internally) — necessary for the lat/long
    // display to update as the user walks, not only after large jumps.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(_onPosition);

    // Throttle compass to ~10 Hz; raw magnetometer can fire 60+ Hz.
    DateTime lastHeading = DateTime.fromMillisecondsSinceEpoch(0);
    _compassSub = FlutterCompass.events?.listen((e) {
      if (e.heading == null) return;
      final now = DateTime.now();
      if (now.difference(lastHeading).inMilliseconds < 100) return;
      lastHeading = now;
      emit(state.copyWith(heading: e.heading));
    });

    // Magnetometer field strength (µT). Throttle to 1 Hz — the value is
    // slow-moving and we just display it.
    DateTime lastMag = DateTime.fromMillisecondsSinceEpoch(0);
    _magnetoSub = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) {
      final now = DateTime.now();
      if (now.difference(lastMag).inMilliseconds < 1000) return;
      lastMag = now;
      final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      emit(state.copyWith(magneticFieldMicroTesla: magnitude));
    });
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    await _compassSub?.cancel();
    await _magnetoSub?.cancel();
    _positionSub = null;
    _compassSub = null;
    _magnetoSub = null;
  }

  Future<void> _onPosition(Position p) async {
    emit(state.copyWith(
      latitude: p.latitude,
      longitude: p.longitude,
      altitudeMetres: p.altitude,
      accuracyMetres: p.accuracy,
      updatedAt: DateTime.now(),
      hasFix: true,
    ));

    // Throttle geocode lookups — every ~6s max.
    final now = DateTime.now();
    if (now.difference(_lastGeocode).inSeconds < 6) return;
    _lastGeocode = now;

    try {
      final placemarks = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isEmpty) return;
      final pm = placemarks.first;
      emit(state.copyWith(
        locality: pm.locality,
        subLocality: pm.subLocality?.isNotEmpty == true ? pm.subLocality : pm.locality,
        administrativeArea: pm.administrativeArea,
        country: pm.country,
        isoCountryCode: pm.isoCountryCode,
        streetLine: [pm.street, pm.thoroughfare]
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .join(', '),
        postalCode: pm.postalCode,
      ));
    } catch (_) {
      // Geocoding can fail offline — silent. Coordinates still shown.
    }
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
