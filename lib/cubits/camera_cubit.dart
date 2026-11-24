import 'dart:async';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart' as cam;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CaptureMode { photo, video }

/// `idle`         – no controller (paused, tab hidden, not permitted yet).
/// `initializing` – opening / switching the camera.
/// `ready`        – preview running.
/// `error`        – the camera could not be opened ([CameraStateData.error]).
enum CamStatus { idle, initializing, ready, error }

/// Physical lens role inferred from `CameraDescription.name`. Used to map
/// zoom presets (0.5×, 1×, 2×, 5×) to hardware lenses on devices that expose
/// several back cameras (iPhone 11+ etc.).
enum LensRole { ultraWide, wide, telephoto2x, telephoto5x, other }

class LensOption extends Equatable {
  final int cameraIndex;
  final LensRole role;
  final double label;
  const LensOption({required this.cameraIndex, required this.role, required this.label});

  @override
  List<Object?> get props => [cameraIndex, role, label];
}

class CameraStateData extends Equatable {
  final CamStatus status;
  final List<cam.CameraDescription> cameras;
  final int activeIndex;
  final CaptureMode mode;
  final bool flashOn;
  final bool gridOn;
  final bool isRecording;
  final String? error;
  final double minZoom;
  final double maxZoom;
  final double zoom;
  final Duration recordingElapsed;
  final List<LensOption> backLenses;

  /// Whether the current controller records audio.
  final bool audioEnabled;

  /// Bumped every time the underlying controller instance changes so widgets
  /// holding the old controller rebuild.
  final int generation;

  /// Spot note that will be attached to (and shown on) the next capture.
  final String draftNote;

  const CameraStateData({
    this.status = CamStatus.idle,
    this.cameras = const [],
    this.activeIndex = 0,
    this.mode = CaptureMode.photo,
    this.flashOn = false,
    this.gridOn = false,
    this.isRecording = false,
    this.error,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
    this.zoom = 1.0,
    this.recordingElapsed = Duration.zero,
    this.backLenses = const [],
    this.audioEnabled = false,
    this.generation = 0,
    this.draftNote = '',
  });

  bool get isReady => status == CamStatus.ready;

  bool get isFront =>
      activeIndex >= 0 &&
      activeIndex < cameras.length &&
      cameras[activeIndex].lensDirection == cam.CameraLensDirection.front;

  LensOption get activeLens => backLenses.firstWhere(
        (l) => l.cameraIndex == activeIndex,
        orElse: () => const LensOption(cameraIndex: 0, role: LensRole.wide, label: 1.0),
      );

  /// Zoom the user perceives: lens label × digital zoom.
  double get effectiveZoom => isFront ? zoom : activeLens.label * zoom;

  /// Whether a 0.5× preset can be offered (ultra-wide lens or logical
  /// multi-camera with min zoom < 1).
  bool get canUltraWide =>
      !isFront && (backLenses.any((l) => l.role == LensRole.ultraWide) || minZoom < 0.95);

  CameraStateData copyWith({
    CamStatus? status,
    List<cam.CameraDescription>? cameras,
    int? activeIndex,
    CaptureMode? mode,
    bool? flashOn,
    bool? gridOn,
    bool? isRecording,
    String? error,
    bool clearError = false,
    double? minZoom,
    double? maxZoom,
    double? zoom,
    Duration? recordingElapsed,
    List<LensOption>? backLenses,
    bool? audioEnabled,
    int? generation,
    String? draftNote,
  }) =>
      CameraStateData(
        status: status ?? this.status,
        cameras: cameras ?? this.cameras,
        activeIndex: activeIndex ?? this.activeIndex,
        mode: mode ?? this.mode,
        flashOn: flashOn ?? this.flashOn,
        gridOn: gridOn ?? this.gridOn,
        isRecording: isRecording ?? this.isRecording,
        error: clearError ? null : (error ?? this.error),
        minZoom: minZoom ?? this.minZoom,
        maxZoom: maxZoom ?? this.maxZoom,
        zoom: zoom ?? this.zoom,
        recordingElapsed: recordingElapsed ?? this.recordingElapsed,
        backLenses: backLenses ?? this.backLenses,
        audioEnabled: audioEnabled ?? this.audioEnabled,
        generation: generation ?? this.generation,
        draftNote: draftNote ?? this.draftNote,
      );

  @override
  List<Object?> get props => [
        status,
        cameras,
        activeIndex,
        mode,
        flashOn,
        gridOn,
        isRecording,
        error,
        minZoom,
        maxZoom,
        zoom,
        recordingElapsed,
        backLenses,
        audioEnabled,
        generation,
        draftNote,
      ];
}

/// Result of a finished recording.
class RecordedVideo {
  final cam.XFile file;
  final Duration duration;
  const RecordedVideo(this.file, this.duration);
}

/// Owns the [cam.CameraController].
///
/// All controller mutations (open, switch lens, pause) are serialised through
/// a single queue so rapid lifecycle / tab / permission events can't race.
/// The screen calls [start] when the camera may run and [pause] when it must
/// be released (app paused/hidden, Capture tab unmounted).
class CameraCubit extends Cubit<CameraStateData> {
  CameraCubit() : super(const CameraStateData());

  cam.CameraController? _controller;
  Future<void> _queue = Future.value();
  bool _wantRunning = false;
  bool _wantAudio = false;
  Timer? _recordTicker;
  DateTime? _recordStartedAt;

  cam.CameraController? get controller => _controller;

  void _set(CameraStateData s) {
    if (!isClosed) emit(s);
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op()).catchError((Object e) {
      _set(state.copyWith(status: CamStatus.error, error: _describe(e)));
    });
    _queue = next;
    return next;
  }

  static String _describe(Object e) {
    if (e is cam.CameraException) {
      switch (e.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return 'Camera access is off.';
        case 'AudioAccessDenied':
        case 'AudioAccessDeniedWithoutPrompt':
        case 'AudioAccessRestricted':
          return 'Microphone access is off.';
      }
      return e.description ?? e.code;
    }
    return e.toString();
  }

  /// Opens the camera (if not already running with the requested audio).
  Future<void> start({required bool audio}) {
    _wantRunning = true;
    _wantAudio = audio;
    return _enqueue(() async {
      if (!_wantRunning || isClosed) return;
      final c = _controller;
      if (c != null && c.value.isInitialized && (state.audioEnabled == _wantAudio || state.isRecording)) return;

      var cameras = state.cameras;
      var lenses = state.backLenses;
      var index = state.activeIndex;
      if (cameras.isEmpty) {
        _set(state.copyWith(status: CamStatus.initializing, clearError: true));
        cameras = await cam.availableCameras();
        if (cameras.isEmpty) {
          _set(state.copyWith(status: CamStatus.error, error: 'No camera found on this device.'));
          return;
        }
        lenses = _detectBackLenses(cameras);
        index = _defaultIndex(cameras, lenses);
        _set(state.copyWith(cameras: cameras, backLenses: lenses, activeIndex: index));
      }
      await _open(index);
    });
  }

  /// Releases the camera hardware. Safe to call repeatedly. If a recording
  /// was in progress it is finished and returned so the caller can save it.
  Future<RecordedVideo?> pause() async {
    _wantRunning = false;
    final started = _recordStartedAt;
    final wasRecording = state.isRecording;
    _stopTicker();
    final c = _controller;
    _controller = null;
    if (c != null || state.status != CamStatus.idle) {
      _set(state.copyWith(
        status: CamStatus.idle,
        isRecording: false,
        recordingElapsed: Duration.zero,
        generation: state.generation + 1,
      ));
    }
    RecordedVideo? rec;
    await _enqueue(() async {
      if (c == null) return;
      if (wasRecording && c.value.isRecordingVideo) {
        try {
          final file = await c.stopVideoRecording();
          rec = RecordedVideo(file, started == null ? Duration.zero : DateTime.now().difference(started));
        } catch (_) {}
      }
      try {
        await c.dispose();
      } catch (_) {}
    });
    return rec;
  }

  /// Re-opens the controller with/without audio if it differs.
  Future<void> setAudio(bool audio) {
    if (_wantAudio == audio && state.audioEnabled == audio) return Future.value();
    _wantAudio = audio;
    if (!_wantRunning || state.isRecording) return Future.value();
    return _enqueue(() async {
      if (!_wantRunning || state.isRecording) return;
      if (_controller != null && state.audioEnabled == _wantAudio) return;
      await _open(state.activeIndex);
    });
  }

  int _defaultIndex(List<cam.CameraDescription> cameras, List<LensOption> lenses) {
    if (lenses.isNotEmpty) {
      return lenses
          .firstWhere((l) => l.role == LensRole.wide, orElse: () => lenses.first)
          .cameraIndex;
    }
    final back = cameras.indexWhere((c) => c.lensDirection == cam.CameraLensDirection.back);
    return back < 0 ? 0 : back;
  }

  /// iOS reports descriptive names ("Back Ultra Wide Camera"); Android
  /// (CameraX) gives ids — there we keep the first back camera as 1×.
  List<LensOption> _detectBackLenses(List<cam.CameraDescription> all) {
    final result = <LensOption>[];
    for (var i = 0; i < all.length; i++) {
      if (all[i].lensDirection != cam.CameraLensDirection.back) continue;
      final n = all[i].name.toLowerCase();
      LensRole role;
      double label;
      if (n.contains('ultra')) {
        role = LensRole.ultraWide;
        label = 0.5;
      } else if (n.contains('telephoto')) {
        final teles = result.where((l) => l.role == LensRole.telephoto2x || l.role == LensRole.telephoto5x);
        role = teles.isEmpty ? LensRole.telephoto2x : LensRole.telephoto5x;
        label = teles.isEmpty ? 2.0 : 5.0;
      } else if (n.contains('dual') || n.contains('triple')) {
        continue; // composite virtual devices duplicate the 1× slot
      } else {
        role = n.contains('wide') || n.contains('back') || n.contains('rear') ? LensRole.wide : LensRole.other;
        label = 1.0;
      }
      result.add(LensOption(cameraIndex: i, role: role, label: label));
    }
    final byLabel = <double, LensOption>{};
    for (final l in result) {
      byLabel.putIfAbsent(l.label, () => l);
    }
    return byLabel.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<void> _open(int index) async {
    final cameras = state.cameras;
    if (index < 0 || index >= cameras.length) return;

    final old = _controller;
    _controller = null;
    _set(state.copyWith(status: CamStatus.initializing, clearError: true, generation: state.generation + 1));
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }

    final audio = _wantAudio;
    final c = cam.CameraController(
      cameras[index],
      state.mode == CaptureMode.photo ? cam.ResolutionPreset.max : cam.ResolutionPreset.veryHigh,
      enableAudio: audio,
    );
    try {
      await c.initialize();
    } catch (e) {
      try {
        await c.dispose();
      } catch (_) {}
      rethrow;
    }
    if (!_wantRunning || isClosed) {
      await c.dispose();
      return;
    }
    double minZ = 1, maxZ = 1;
    try {
      minZ = await c.getMinZoomLevel();
      maxZ = await c.getMaxZoomLevel();
    } catch (_) {}
    _controller = c;
    _set(state.copyWith(
      status: CamStatus.ready,
      activeIndex: index,
      clearError: true,
      minZoom: minZ,
      maxZoom: maxZ,
      zoom: 1.0,
      audioEnabled: audio,
      generation: state.generation + 1,
    ));
    await _applyFlash();
  }

  Future<void> _switchTo(int index) {
    if (state.isRecording) return Future.value();
    return _enqueue(() async {
      if (!_wantRunning) return;
      await _open(index);
    });
  }

  /// Toggle front/back.
  Future<void> flipCamera() {
    if (state.cameras.length < 2 || state.isRecording) return Future.value();
    final wantFront = !state.isFront;
    int next;
    if (wantFront) {
      next = state.cameras.indexWhere((c) => c.lensDirection == cam.CameraLensDirection.front);
    } else {
      next = _defaultIndex(state.cameras, state.backLenses);
    }
    if (next < 0) next = (state.activeIndex + 1) % state.cameras.length;
    return _switchTo(next);
  }

  /// iPhone-style preset taps (0.5 / 1 / 2 / 5): prefer a physical lens with
  /// that native label, else digital zoom on the current lens.
  Future<void> tapZoomPreset(double preset) async {
    if (state.isRecording && state.backLenses.length > 1) {
      // Lens switching while recording would stop the recording — digital only.
      await setZoom(preset / state.activeLens.label);
      return;
    }
    if (!state.isFront) {
      for (final l in state.backLenses) {
        if ((l.label - preset).abs() < 0.05) {
          if (l.cameraIndex != state.activeIndex) {
            await _switchTo(l.cameraIndex);
          } else {
            await setZoom(1.0);
          }
          return;
        }
      }
    }
    final label = state.isFront ? 1.0 : state.activeLens.label;
    await setZoom(preset / label);
  }

  Future<void> setZoom(double z) async {
    final clamped = z.clamp(state.minZoom, state.maxZoom).toDouble();
    try {
      await _controller?.setZoomLevel(clamped);
      _set(state.copyWith(zoom: clamped));
    } catch (_) {}
  }

  Future<void> setFocusPoint(double x, double y) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final p = (x: x.clamp(0.0, 1.0), y: y.clamp(0.0, 1.0));
    try {
      await c.setFocusPoint(Offset(p.x, p.y));
    } catch (_) {}
    try {
      await c.setExposurePoint(Offset(p.x, p.y));
    } catch (_) {}
  }

  Future<void> toggleFlash() async {
    _set(state.copyWith(flashOn: !state.flashOn));
    await _applyFlash();
  }

  void toggleGrid() => _set(state.copyWith(gridOn: !state.gridOn));

  Future<void> _applyFlash() async {
    final c = _controller;
    if (c == null) return;
    final mode = !state.flashOn
        ? cam.FlashMode.off
        : (state.mode == CaptureMode.video ? cam.FlashMode.torch : cam.FlashMode.always);
    try {
      await c.setFlashMode(mode);
    } catch (_) {}
  }

  /// Switches photo/video. The controller is re-opened because the
  /// resolution preset and audio track differ per mode.
  Future<void> setMode(CaptureMode m, {required bool audio}) {
    if (state.isRecording || state.mode == m) return Future.value();
    _set(state.copyWith(mode: m));
    _wantAudio = audio;
    if (!_wantRunning) return Future.value();
    return _enqueue(() async {
      if (!_wantRunning) return;
      await _open(state.activeIndex);
    });
  }

  void setDraftNote(String note) => _set(state.copyWith(draftNote: note.trim()));
  void clearDraftNote() => _set(state.copyWith(draftNote: ''));

  Future<cam.XFile?> takePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
    try {
      return await c.takePicture();
    } catch (e) {
      _set(state.copyWith(error: _describe(e)));
      return null;
    }
  }

  Future<bool> startVideo() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) return false;
    try {
      await c.startVideoRecording();
      _recordStartedAt = DateTime.now();
      _recordTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        final s = _recordStartedAt;
        if (s == null) return;
        _set(state.copyWith(recordingElapsed: DateTime.now().difference(s)));
      });
      _set(state.copyWith(isRecording: true, recordingElapsed: Duration.zero));
      return true;
    } catch (e) {
      _set(state.copyWith(error: _describe(e)));
      return false;
    }
  }

  Future<RecordedVideo?> stopVideo() async {
    final c = _controller;
    final started = _recordStartedAt;
    _stopTicker();
    if (c == null || !c.value.isRecordingVideo) {
      _set(state.copyWith(isRecording: false, recordingElapsed: Duration.zero));
      return null;
    }
    try {
      final file = await c.stopVideoRecording();
      _set(state.copyWith(isRecording: false, recordingElapsed: Duration.zero));
      final dur = started == null ? Duration.zero : DateTime.now().difference(started);
      return RecordedVideo(file, dur);
    } catch (e) {
      _set(state.copyWith(error: _describe(e), isRecording: false, recordingElapsed: Duration.zero));
      return null;
    }
  }

  void _stopTicker() {
    _recordTicker?.cancel();
    _recordTicker = null;
    _recordStartedAt = null;
  }

  @override
  Future<void> close() async {
    _wantRunning = false;
    _stopTicker();
    final c = _controller;
    _controller = null;
    await c?.dispose();
    return super.close();
  }
}
