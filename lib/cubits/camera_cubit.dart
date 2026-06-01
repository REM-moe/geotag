import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CaptureMode { photo, video }

enum GeotagFlash { off, on, auto }

enum SelfTimer {
  off(0),
  s3(3),
  s5(5),
  s10(10),
  s20(20);

  final int seconds;
  const SelfTimer(this.seconds);
}

/// Physical lens role inferred from `CameraDescription.name`. Used to map
/// zoom presets (0.5×, 1×, 2×, 5×) to actual hardware lenses on devices that
/// have multiple back cameras (iPhone 11+ etc.).
enum LensRole { ultraWide, wide, telephoto2x, telephoto5x, other }

class LensOption {
  final int cameraIndex;
  final LensRole role;
  final double label;
  const LensOption({required this.cameraIndex, required this.role, required this.label});
}

class CameraStateData extends Equatable {
  final List<cam.CameraDescription> cameras;
  final int activeIndex;
  final CaptureMode mode;
  final GeotagFlash flash;
  final bool isInitializing;
  final bool isRecording;
  final String? error;
  final double minZoom;
  final double maxZoom;
  final double zoom;
  final Duration recordingElapsed;
  final SelfTimer timer;
  final int? countdown;
  final List<LensOption> backLenses;

  const CameraStateData({
    this.cameras = const [],
    this.activeIndex = 0,
    this.mode = CaptureMode.photo,
    this.flash = GeotagFlash.off,
    this.isInitializing = true,
    this.isRecording = false,
    this.error,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
    this.zoom = 1.0,
    this.recordingElapsed = Duration.zero,
    this.timer = SelfTimer.off,
    this.countdown,
    this.backLenses = const [],
  });

  bool get isFront => cameras.isNotEmpty &&
      activeIndex >= 0 &&
      activeIndex < cameras.length &&
      cameras[activeIndex].lensDirection == cam.CameraLensDirection.front;

  CameraStateData copyWith({
    List<cam.CameraDescription>? cameras,
    int? activeIndex,
    CaptureMode? mode,
    GeotagFlash? flash,
    bool? isInitializing,
    bool? isRecording,
    String? error,
    double? minZoom,
    double? maxZoom,
    double? zoom,
    Duration? recordingElapsed,
    SelfTimer? timer,
    int? countdown,
    bool clearCountdown = false,
    List<LensOption>? backLenses,
  }) =>
      CameraStateData(
        cameras: cameras ?? this.cameras,
        activeIndex: activeIndex ?? this.activeIndex,
        mode: mode ?? this.mode,
        flash: flash ?? this.flash,
        isInitializing: isInitializing ?? this.isInitializing,
        isRecording: isRecording ?? this.isRecording,
        error: error,
        minZoom: minZoom ?? this.minZoom,
        maxZoom: maxZoom ?? this.maxZoom,
        zoom: zoom ?? this.zoom,
        recordingElapsed: recordingElapsed ?? this.recordingElapsed,
        timer: timer ?? this.timer,
        countdown: clearCountdown ? null : (countdown ?? this.countdown),
        backLenses: backLenses ?? this.backLenses,
      );

  @override
  List<Object?> get props => [
        cameras,
        activeIndex,
        mode,
        flash,
        isInitializing,
        isRecording,
        error,
        minZoom,
        maxZoom,
        zoom,
        recordingElapsed,
        timer,
        countdown,
        backLenses,
      ];
}

class CameraCubit extends Cubit<CameraStateData> {
  CameraCubit() : super(const CameraStateData());

  cam.CameraController? _controller;
  Timer? _recordTicker;
  DateTime? _recordStartedAt;

  cam.CameraController? get controller => _controller;

  Future<void> init() async {
    try {
      emit(state.copyWith(isInitializing: true, error: null));
      final cameras = await cam.availableCameras();
      if (cameras.isEmpty) {
        emit(state.copyWith(isInitializing: false, error: 'No cameras available.'));
        return;
      }

      final lenses = _detectBackLenses(cameras);
      emit(state.copyWith(backLenses: lenses));

      // Default to the "wide" (1×) lens. Fall back to first back, else first.
      final wide = lenses.firstWhere(
        (l) => l.role == LensRole.wide,
        orElse: () => lenses.isNotEmpty
            ? lenses.first
            : const LensOption(cameraIndex: 0, role: LensRole.other, label: 1.0),
      );
      int idx = wide.cameraIndex;
      if (lenses.isEmpty) {
        idx = cameras.indexWhere((c) => c.lensDirection == cam.CameraLensDirection.back);
        if (idx < 0) idx = 0;
      }
      await _setupController(cameras, idx);
    } catch (e) {
      emit(state.copyWith(isInitializing: false, error: e.toString()));
    }
  }

  /// Inspect `CameraDescription.name` strings to figure out which physical
  /// back lens each entry corresponds to. iOS reports descriptive names like
  /// "Back Ultra Wide Camera"; Android (with camerax variant) gives ID-style
  /// names — there we keep only the first back camera and assume 1×.
  List<LensOption> _detectBackLenses(List<cam.CameraDescription> all) {
    final back = <int>[];
    for (var i = 0; i < all.length; i++) {
      if (all[i].lensDirection == cam.CameraLensDirection.back) back.add(i);
    }
    if (back.isEmpty) return const [];

    final result = <LensOption>[];
    for (final i in back) {
      final n = all[i].name.toLowerCase();
      LensRole role;
      double label;
      if (n.contains('ultra')) {
        role = LensRole.ultraWide;
        label = 0.5;
      } else if (n.contains('telephoto')) {
        // iPhone Pro models may have 2× OR 5× telephoto; we can't reliably
        // distinguish without focal-length info. Assume 2× if there's only
        // one telephoto, 5× if a second appears.
        final teles = result.where((l) =>
            l.role == LensRole.telephoto2x || l.role == LensRole.telephoto5x);
        role = teles.isEmpty ? LensRole.telephoto2x : LensRole.telephoto5x;
        label = teles.isEmpty ? 2.0 : 5.0;
      } else if (n.contains('wide') || n.contains('back camera') || n.contains('rear')) {
        role = LensRole.wide;
        label = 1.0;
      } else {
        role = LensRole.other;
        label = 1.0;
      }
      result.add(LensOption(cameraIndex: i, role: role, label: label));
    }

    // Multi-cam composite entries (Dual / Triple) usually appear ALONGSIDE the
    // single-lens entries — those duplicate 1× slots. Dedup by label, keeping
    // the first non-composite per label.
    final byLabel = <double, LensOption>{};
    for (final l in result) {
      byLabel.putIfAbsent(l.label, () => l);
    }
    final out = byLabel.values.toList()..sort((a, b) => a.label.compareTo(b.label));
    return out;
  }

  Future<void> selectLens(LensOption lens) async {
    if (state.isRecording) return;
    if (lens.cameraIndex == state.activeIndex) {
      await setZoom(1.0);
      return;
    }
    emit(state.copyWith(isInitializing: true));
    await _setupController(state.cameras, lens.cameraIndex);
  }

  /// Standard iPhone-style preset taps. For a given desired effective zoom
  /// (0.5/1/2/5):
  ///   - prefer switching to a physical lens whose native label matches
  ///   - else fall back to digital zoom on the current lens
  Future<void> tapZoomPreset(double preset) async {
    if (state.isRecording) return;

    // Try matching physical lens (within ε to handle fp comparison).
    LensOption? match;
    for (final l in state.backLenses) {
      if ((l.label - preset).abs() < 0.05) {
        match = l;
        break;
      }
    }

    if (match != null && match.cameraIndex != state.activeIndex) {
      emit(state.copyWith(isInitializing: true));
      await _setupController(state.cameras, match.cameraIndex);
      return;
    }
    if (match != null) {
      // Same lens, reset to 1× on it.
      await setZoom(1.0);
      return;
    }

    // No physical lens — apply digital zoom on the currently active camera.
    // Translate the preset to the active lens's zoom space: a preset of 2×
    // on the 1× wide lens means setZoom(2). On a 0.5× ultra-wide, it means
    // setZoom(2/0.5)=4.
    final activeLens = state.backLenses.firstWhere(
      (l) => l.cameraIndex == state.activeIndex,
      orElse: () =>
          const LensOption(cameraIndex: 0, role: LensRole.wide, label: 1.0),
    );
    final targetZoom = preset / activeLens.label;
    await setZoom(targetZoom);
  }

  /// Effective focal-length multiplier that the user perceives: active lens
  /// label × current digital zoom. Used by the UI to highlight the right pill.
  double get effectiveZoom {
    final activeLens = state.backLenses.firstWhere(
      (l) => l.cameraIndex == state.activeIndex,
      orElse: () =>
          const LensOption(cameraIndex: 0, role: LensRole.wide, label: 1.0),
    );
    return activeLens.label * state.zoom;
  }

  Future<void> _setupController(List<cam.CameraDescription> cameras, int index) async {
    await _controller?.dispose();
    final c = cam.CameraController(
      cameras[index],
      cam.ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );
    await c.initialize();
    try {
      await c.setFlashMode(_toPlugin(state.flash));
    } catch (_) {}
    final minZ = await c.getMinZoomLevel();
    final maxZ = await c.getMaxZoomLevel();
    _controller = c;
    emit(state.copyWith(
      cameras: cameras,
      activeIndex: index,
      isInitializing: false,
      error: null,
      minZoom: minZ,
      maxZoom: maxZ,
      zoom: 1.0,
    ));
  }

  Future<void> flipCamera() async {
    if (state.cameras.length < 2 || state.isRecording) return;
    final next = (state.activeIndex + 1) % state.cameras.length;
    emit(state.copyWith(isInitializing: true));
    await _setupController(state.cameras, next);
  }

  Future<void> cycleFlash() async {
    final order = [GeotagFlash.off, GeotagFlash.auto, GeotagFlash.on];
    final next = order[(order.indexOf(state.flash) + 1) % order.length];
    emit(state.copyWith(flash: next));
    try {
      await _controller?.setFlashMode(_toPlugin(next));
    } catch (_) {}
  }

  void cycleTimer() {
    const order = SelfTimer.values;
    final next = order[(order.indexOf(state.timer) + 1) % order.length];
    emit(state.copyWith(timer: next));
  }

  /// Runs the self-timer countdown, emitting `countdown` ticks each second.
  /// Returns when the countdown reaches zero (or immediately if timer = off).
  Future<void> runCountdown() async {
    if (state.timer == SelfTimer.off) return;
    for (int i = state.timer.seconds; i > 0; i--) {
      emit(state.copyWith(countdown: i));
      await Future.delayed(const Duration(seconds: 1));
    }
    emit(state.copyWith(clearCountdown: true));
  }

  void cancelCountdown() {
    if (state.countdown != null) emit(state.copyWith(clearCountdown: true));
  }

  Future<void> setMode(CaptureMode m) async {
    if (state.isRecording) return;
    emit(state.copyWith(mode: m));
  }

  Future<void> setZoom(double z) async {
    final clamped = z.clamp(state.minZoom, state.maxZoom);
    try {
      await _controller?.setZoomLevel(clamped);
      emit(state.copyWith(zoom: clamped));
    } catch (_) {}
  }

  Future<cam.XFile?> takePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    try {
      return await c.takePicture();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return null;
    }
  }

  Future<void> startVideo() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) return;
    try {
      await c.startVideoRecording();
      _recordStartedAt = DateTime.now();
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_recordStartedAt == null) return;
        emit(state.copyWith(
          recordingElapsed: DateTime.now().difference(_recordStartedAt!),
        ));
      });
      emit(state.copyWith(isRecording: true, recordingElapsed: Duration.zero));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<cam.XFile?> stopVideo() async {
    final c = _controller;
    if (c == null || !c.value.isRecordingVideo) return null;
    try {
      final file = await c.stopVideoRecording();
      _recordTicker?.cancel();
      _recordTicker = null;
      _recordStartedAt = null;
      emit(state.copyWith(isRecording: false, recordingElapsed: Duration.zero));
      return file;
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isRecording: false));
      return null;
    }
  }

  static cam.FlashMode _toPlugin(GeotagFlash f) {
    switch (f) {
      case GeotagFlash.off:
        return cam.FlashMode.off;
      case GeotagFlash.on:
        return cam.FlashMode.always;
      case GeotagFlash.auto:
        return cam.FlashMode.auto;
    }
  }

  @override
  Future<void> close() async {
    _recordTicker?.cancel();
    await _controller?.dispose();
    return super.close();
  }
}
