import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// `notAsked`  – never requested; show rationale then system prompt.
/// `denied`    – denied once; system prompt can still be shown.
/// `blocked`   – permanently denied / restricted; only Settings can fix it.
enum PermStatus { unknown, notAsked, granted, denied, blocked }

extension PermStatusX on PermStatus {
  bool get isGranted => this == PermStatus.granted;
  bool get needsSettings => this == PermStatus.blocked;
}

class PermissionState extends Equatable {
  final PermStatus camera;
  final PermStatus microphone;
  final PermStatus location;

  /// Device-level location services (GPS toggle).
  final bool locationServiceEnabled;

  /// False when the user granted only approximate location (Android 12+/iOS 14+).
  final bool preciseLocation;

  const PermissionState({
    this.camera = PermStatus.unknown,
    this.microphone = PermStatus.unknown,
    this.location = PermStatus.unknown,
    this.locationServiceEnabled = true,
    this.preciseLocation = true,
  });

  bool get loaded => camera != PermStatus.unknown;

  /// Location can actually produce fixes.
  bool get locationUsable => location.isGranted && locationServiceEnabled;

  PermissionState copyWith({
    PermStatus? camera,
    PermStatus? microphone,
    PermStatus? location,
    bool? locationServiceEnabled,
    bool? preciseLocation,
  }) =>
      PermissionState(
        camera: camera ?? this.camera,
        microphone: microphone ?? this.microphone,
        location: location ?? this.location,
        locationServiceEnabled: locationServiceEnabled ?? this.locationServiceEnabled,
        preciseLocation: preciseLocation ?? this.preciseLocation,
      );

  @override
  List<Object?> get props => [camera, microphone, location, locationServiceEnabled, preciseLocation];
}

/// Non-blocking, just-in-time permission manager.
///
/// Nothing is requested on launch. Each feature calls the matching
/// `ensureX()` at the moment it is needed. [refresh] must be called whenever
/// the app resumes (handled by `AppLifecycleRefresher` in the shell) so that
/// returning from Settings updates the UI immediately.
class PermissionCubit extends Cubit<PermissionState> {
  PermissionCubit() : super(const PermissionState());

  PermStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermStatus.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return PermStatus.blocked;
    return PermStatus.denied;
  }

  Future<void> refresh() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final loc = await Permission.locationWhenInUse.status;
    final service = await Geolocator.isLocationServiceEnabled();
    var precise = true;
    if (loc.isGranted) {
      try {
        precise = await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.precise;
      } catch (_) {}
    }
    emit(state.copyWith(
      camera: _status(cam, state.camera),
      microphone: _status(mic, state.microphone),
      location: _status(loc, state.location),
      locationServiceEnabled: service,
      preciseLocation: precise,
    ));
  }

  /// On first read `status` reports `denied` for never-asked permissions on
  /// Android; we keep `notAsked` until a request has actually happened.
  PermStatus _status(PermissionStatus s, PermStatus previous) {
    final mapped = _map(s);
    if (mapped == PermStatus.denied &&
        (previous == PermStatus.unknown || previous == PermStatus.notAsked)) {
      return PermStatus.notAsked;
    }
    return mapped;
  }

  void setLocationServiceEnabled(bool enabled) {
    if (enabled != state.locationServiceEnabled) {
      emit(state.copyWith(locationServiceEnabled: enabled));
    }
  }

  Future<PermStatus> _ensure(Permission p, PermStatus current, PermissionState Function(PermStatus) apply) async {
    if (current.isGranted) return current;
    if (current.needsSettings) {
      await openAppSettings();
      return current;
    }
    final result = _map(await p.request());
    emit(apply(result));
    return result;
  }

  Future<bool> ensureCamera() async =>
      (await _ensure(Permission.camera, state.camera, (s) => state.copyWith(camera: s))).isGranted;

  Future<bool> ensureMicrophone() async =>
      (await _ensure(Permission.microphone, state.microphone, (s) => state.copyWith(microphone: s))).isGranted;

  /// Requests location permission; if the permission is fine but device GPS
  /// is off, opens the system location settings instead.
  Future<bool> ensureLocation() async {
    final s = await _ensure(
      Permission.locationWhenInUse,
      state.location,
      (s) => state.copyWith(location: s),
    );
    if (!s.isGranted) return false;
    if (!state.locationServiceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  Future<void> openSettings() => openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
