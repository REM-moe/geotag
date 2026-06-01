import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermStatus { unknown, granted, denied, permanentlyDenied }

class PermissionState extends Equatable {
  final PermStatus camera;
  final PermStatus microphone;
  final PermStatus location;
  final bool checking;

  const PermissionState({
    this.camera = PermStatus.unknown,
    this.microphone = PermStatus.unknown,
    this.location = PermStatus.unknown,
    this.checking = false,
  });

  bool get cameraAndLocationReady =>
      camera == PermStatus.granted && location == PermStatus.granted;

  PermissionState copyWith({
    PermStatus? camera,
    PermStatus? microphone,
    PermStatus? location,
    bool? checking,
  }) =>
      PermissionState(
        camera: camera ?? this.camera,
        microphone: microphone ?? this.microphone,
        location: location ?? this.location,
        checking: checking ?? this.checking,
      );

  @override
  List<Object?> get props => [camera, microphone, location, checking];
}

class PermissionCubit extends Cubit<PermissionState> {
  PermissionCubit() : super(const PermissionState());

  PermStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermStatus.granted;
    if (s.isPermanentlyDenied) return PermStatus.permanentlyDenied;
    return PermStatus.denied;
  }

  Future<void> refresh() async {
    emit(state.copyWith(checking: true));
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final loc = await Permission.locationWhenInUse.status;
    emit(state.copyWith(
      camera: _map(cam),
      microphone: _map(mic),
      location: _map(loc),
      checking: false,
    ));
  }

  Future<void> requestAll() async {
    emit(state.copyWith(checking: true));
    final results = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.microphone,
    ].request();
    emit(state.copyWith(
      camera: _map(results[Permission.camera] ?? PermissionStatus.denied),
      location: _map(results[Permission.locationWhenInUse] ?? PermissionStatus.denied),
      microphone: _map(results[Permission.microphone] ?? PermissionStatus.denied),
      checking: false,
    ));
  }

  Future<void> openSettingsPage() async {
    await openAppSettings();
  }
}
