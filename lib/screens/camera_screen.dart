import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/camera_cubit.dart';
import '../cubits/location_overlay_cubit.dart';
import '../cubits/permission_cubit.dart';
import '../cubits/template_cubit.dart';
import '../data/capture.dart';
import '../data/capture_repository.dart';
import '../services/capture_prefs.dart';
import '../services/capture_saver.dart';
import '../services/watermark_service.dart';
import '../shell/tab_cubit.dart';
import '../templates/templates.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/live_stamp.dart';
import '../widgets/measure_size.dart';
import '../widgets/mode_carousel.dart';
import '../widgets/shutter_button.dart';
import '../widgets/zoom_selector.dart';
import 'camera/camera_parts.dart';
import 'camera/note_sheet.dart';
import 'camera/permission_sheet.dart';
import 'camera/sheet_kit.dart';
import 'camera/stamp_studio_sheet.dart';

/// Capture tab: always-dark camera chrome over the live viewfinder.
///
/// Mounted only while the Capture tab is selected (the shell unmounts it on
/// tab switch), so the camera is released in [dispose]. Permissions are
/// requested just-in-time and never block the screen.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  // Resolved once in initState: they're used from dispose / async
  // completions where `context` is no longer valid.
  late final CameraCubit _cam;
  late final LocationOverlayCubit _loc;
  late final PermissionCubit _perms;
  late final CaptureRepository _repo;
  late final CaptureSaver _saver;

  final _stampKey = GlobalKey();
  final _stackKey = GlobalKey();

  bool _foreground = true;
  bool _autoAskedCamera = false;
  bool _askingCamera = false;
  bool _busy = false;
  int _pendingSaves = 0;

  bool _flash = false;
  Offset? _focusAt;
  bool _focusVisible = false;
  int _focusTick = 0;
  Timer? _focusTimer;
  double _pinchBase = 1;

  bool _editing = false;
  double _sheetHeight = 0;
  double _belowScreen = 0;
  double _controlsHeight = 190;

  // Recording context (stamp is refreshed while recording so the burned-in
  // values stay current even if recording is cut short by a lifecycle event).
  Uint8List? _videoStamp;
  CaptureMeta? _videoMeta;
  bool _videoMirror = false;
  Timer? _videoStampTimer;

  String? _toast;
  ToastTone _toastTone = ToastTone.success;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _cam = context.read<CameraCubit>();
    _loc = context.read<LocationOverlayCubit>();
    _perms = context.read<PermissionCubit>();
    _repo = context.read<CaptureRepository>();
    _saver = CaptureSaver(_repo);
    WidgetsBinding.instance.addObserver(this);
    CapturePrefs.reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(_perms.state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _toastTimer?.cancel();
    _release();
    _loc.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    switch (s) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Not on `inactive`: that fires for system dialogs (incl. permission
        // prompts) and notification shade pulls.
        if (!_foreground) return;
        _foreground = false;
        _release();
        _loc.stop();
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        _sync(_perms.state);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Releases the camera; an in-flight recording is finished and saved.
  void _release() {
    _videoStampTimer?.cancel();
    final stamp = _videoStamp, meta = _videoMeta, mirror = _videoMirror;
    _cam.pause().then((rec) {
      if (rec != null && meta != null) _saveVideo(rec, stamp, meta, mirror);
    });
  }

  // ── Permissions ─────────────────────────────────────────────────────────

  bool _audioFor(PermissionState p) => _cam.state.mode == CaptureMode.video && p.microphone.isGranted;

  /// Reconciles camera + location with the current permission state. Called
  /// on mount, on every permission change and on resume.
  void _sync(PermissionState p) {
    if (!mounted || !_foreground || !p.loaded) return;

    if (p.camera.isGranted) {
      _cam.start(audio: _audioFor(p));
    } else if (p.camera == PermStatus.notAsked && !_autoAskedCamera) {
      _autoAskedCamera = true;
      _askCamera();
    }

    // Location: `start` re-checks permission / GPS itself and keeps the last
    // known values when unavailable.
    _loc.start();

    if (_cam.state.mode == CaptureMode.video && !_cam.state.isRecording) {
      _cam.setAudio(p.microphone.isGranted);
    }
  }

  Future<void> _askCamera() async {
    setState(() => _askingCamera = true);
    try {
      await _perms.ensureCamera();
    } finally {
      if (mounted) setState(() => _askingCamera = false);
    }
  }

  Future<void> _askLocation(PermissionState p) async {
    final permOff = !p.location.isGranted;
    final blocked = p.location.needsSettings;
    final go = await showCameraSheet<bool>(
      context,
      builder: (_) => PermissionRationaleSheet(
        icon: Icons.location_on_outlined,
        title: permOff ? 'Add location to your photos' : 'Turn on location services',
        body: permOff
            ? 'Geotag uses your location only while the app is open, to stamp the place on each photo. '
                'You can still shoot without it.'
            : "Your phone's location is off. Turn it on to add the place to new photos.",
        cta: permOff ? (blocked ? 'Open Settings' : 'Continue') : 'Turn on',
      ),
    );
    if (go == true) await _perms.ensureLocation();
  }

  Future<void> _askMicrophone(PermissionState p) async {
    if (p.microphone.needsSettings) {
      await _perms.openSettings();
    } else {
      await _perms.ensureMicrophone();
    }
  }

  Future<void> _onMode(CaptureMode m) async {
    var audio = false;
    if (m == CaptureMode.video) {
      final mic = _perms.state.microphone;
      if (mic.isGranted) {
        audio = true;
      } else if (!mic.needsSettings) {
        audio = await _perms.ensureMicrophone();
      }
    }
    await _cam.setMode(m, audio: audio);
  }

  // ── Capture ─────────────────────────────────────────────────────────────

  CaptureMeta _meta() {
    final s = _loc.state;
    final fix = s.hasFix;
    final address = s.streetBlock;
    return CaptureMeta(
      takenAt: DateTime.now(),
      latitude: fix ? s.latitude : null,
      longitude: fix ? s.longitude : null,
      altitude: fix ? s.altitudeMetres : null,
      accuracy: fix ? s.accuracyMetres : null,
      heading: s.heading,
      place: fix ? s.shortPlace : null,
      address: fix && address.isNotEmpty ? address : null,
      note: _cam.state.draftNote,
    );
  }

  Future<Uint8List?> _rasteriseStamp(double pixelRatio) async {
    final boundary = _stampKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    return WatermarkCapture.captureFromBoundary(boundary, pixelRatio: pixelRatio);
  }

  Future<void> _onShutter() async {
    final s = _cam.state;
    if (!s.isReady || _busy) return;
    Haptics.shutter();

    if (s.mode == CaptureMode.video) {
      _busy = true;
      try {
        s.isRecording ? await _stopRecording() : await _startRecording();
      } finally {
        _busy = false;
      }
      return;
    }

    _busy = true;
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    final meta = _meta();
    final mirror = s.isFront;
    final stampF = _rasteriseStamp(6);
    final file = await _cam.takePhoto();
    final stamp = await stampF;
    _busy = false;
    if (file == null) {
      _showToast("Couldn't take the photo. Try again.", ToastTone.warning);
      return;
    }
    if (meta.note.isNotEmpty) _cam.clearDraftNote();
    _track(
      _saver.savePhoto(
        rawPath: file.path,
        meta: meta,
        watermarkPng: stamp,
        mirror: mirror,
        saveOriginal: CapturePrefs.saveOriginal,
      ),
      what: 'Photo',
    );
  }

  Future<void> _startRecording() async {
    final meta = _meta();
    final mirror = _cam.state.isFront;
    final ok = await _cam.startVideo();
    if (!ok) {
      _showToast("Couldn't start recording.", ToastTone.warning);
      return;
    }
    _videoMeta = meta;
    _videoMirror = mirror;
    _videoStamp = await _rasteriseStamp(5);
    _videoStampTimer?.cancel();
    _videoStampTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final png = await _rasteriseStamp(5);
      if (png != null) _videoStamp = png;
    });
  }

  Future<void> _stopRecording() async {
    _videoStampTimer?.cancel();
    final stamp = await _rasteriseStamp(5) ?? _videoStamp;
    final meta = _videoMeta ?? _meta();
    final mirror = _videoMirror;
    final rec = await _cam.stopVideo();
    _videoMeta = null;
    _videoStamp = null;
    if (rec == null) {
      _showToast("Couldn't save the video.", ToastTone.warning);
      return;
    }
    if (meta.note.isNotEmpty) _cam.clearDraftNote();
    _saveVideo(rec, stamp, meta, mirror);
  }

  void _saveVideo(RecordedVideo rec, Uint8List? stamp, CaptureMeta meta, bool mirror) {
    _track(
      _saver.saveVideo(
        rawPath: rec.file.path,
        meta: meta,
        duration: rec.duration,
        watermarkPng: stamp,
        mirror: mirror,
        saveOriginal: CapturePrefs.saveOriginal,
      ),
      what: 'Video',
    );
  }

  void _track(Future<SaveResult> job, {required String what}) {
    if (mounted) setState(() => _pendingSaves++);
    job.then((r) {
      if (r.exportedToGallery) {
        _showToast('$what saved to Library');
      } else {
        _showToast("$what saved to Library · couldn't add to Photos", ToastTone.warning);
      }
    }).catchError((Object _) {
      _showToast("Couldn't save the ${what.toLowerCase()}.", ToastTone.warning);
    }).whenComplete(() {
      if (mounted) setState(() => _pendingSaves = math.max(0, _pendingSaves - 1));
    });
  }

  void _showToast(String msg, [ToastTone tone = ToastTone.success]) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() {
      _toast = msg;
      _toastTone = tone;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── Gestures ────────────────────────────────────────────────────────────

  void _onTapFocus(TapUpDetails d, Size size) {
    if (!_cam.state.isReady || _editing) return;
    _cam.setFocusPoint(d.localPosition.dx / size.width, d.localPosition.dy / size.height);
    Haptics.light();
    _focusTimer?.cancel();
    setState(() {
      _focusAt = d.localPosition;
      _focusVisible = true;
      _focusTick++;
    });
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusVisible = false);
    });
  }

  // ── Sheets ──────────────────────────────────────────────────────────────

  Future<void> _openStudio() async {
    if (_cam.state.isRecording) return;
    Haptics.selection();
    // Height of whatever sits below this screen (the shell's tab bar) — the
    // sheet covers it too.
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final screenBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      _belowScreen = math.max(0, MediaQuery.sizeOf(context).height - screenBottom);
    }
    setState(() {
      _editing = true;
      if (_sheetHeight == 0) _sheetHeight = 300;
    });
    await showCameraSheet<void>(
      context,
      transparentScrim: true,
      onHeight: (h) {
        if (mounted && (h - _sheetHeight).abs() > 0.5) setState(() => _sheetHeight = h);
      },
      onClosing: () {
        if (mounted) setState(() => _editing = false);
      },
      builder: (_) => const StampStudioSheet(),
    );
    if (mounted && _editing) setState(() => _editing = false);
  }

  Future<void> _openNote() async {
    Haptics.selection();
    final s = _loc.state;
    final line = s.hasFix
        ? 'Pinned to ${s.placeName ?? 'this spot'} · ${formatLat(s.latitude!)}, ${formatLng(s.longitude!)}'
        : 'No location — note will attach to the photo only';
    final result = await showCameraSheet<String>(
      context,
      builder: (_) => NoteSheet(initial: _cam.state.draftNote, locationLine: line),
    );
    if (result == null || !mounted) return;
    final had = _cam.state.draftNote.isNotEmpty;
    _cam.setDraftNote(result);
    if (result.isNotEmpty) {
      _showToast('Note will be added to your next shot');
    } else if (had) {
      _showToast('Note removed');
    }
  }

  /// Bottom offset (within this screen) that puts the stamp just above the
  /// open sheet.
  double _liftedBottom() => math.max(0, _sheetHeight - _belowScreen);

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionCubit, PermissionState>(
      listener: (_, p) => _sync(p),
      child: ColoredBox(
        color: CamColors.black,
        child: BlocBuilder<PermissionCubit, PermissionState>(
          builder: (context, perms) {
            final camState = context.watch<CameraCubit>().state;
            if (perms.loaded && !perms.camera.isGranted && !_askingCamera) {
              final blocked = perms.camera.needsSettings;
              return CameraBlockedView(
                title: 'Camera is off',
                body: 'Allow camera to take geotagged photos. Your library, map and notes keep working.',
                primaryLabel: blocked ? 'Open Settings' : 'Allow camera',
                onPrimary: blocked ? _perms.openSettings : _askCamera,
                secondaryLabel: 'Open library',
                onSecondary: () => context.read<TabCubit>().go(AppTab.library),
              );
            }
            if (camState.status == CamStatus.error) {
              return CameraBlockedView(
                icon: Icons.no_photography_outlined,
                title: 'Camera unavailable',
                body: camState.error ?? 'Something went wrong opening the camera.',
                primaryLabel: 'Try again',
                onPrimary: () => _cam.start(audio: _audioFor(perms)),
                secondaryLabel: 'Open library',
                onSecondary: () => context.read<TabCubit>().go(AppTab.library),
              );
            }
            return _camera(context, camState, perms);
          },
        ),
      ),
    );
  }

  Widget _camera(BuildContext context, CameraStateData s, PermissionState perms) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final pad = mq.padding;
    final sideInset = math.max(pad.left, Space.s4);
    final rightInset = math.max(pad.right, Space.s4);
    final controller = _cam.controller;
    final previewReady = s.isReady && controller != null && controller.value.isInitialized;
    final notices = _notices(s, perms);

    return LayoutBuilder(
      key: _stackKey,
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final stampBottom = _editing ? _liftedBottom() : (landscape ? 0.0 : _controlsHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Viewfinder: tap to focus, pinch to zoom.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onTapFocus(d, size),
              onScaleStart: (_) => _pinchBase = s.zoom,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) _cam.setZoom(_pinchBase * d.scale);
              },
              child: AnimatedSwitcher(
                duration: Motion.sheet,
                child: previewReady
                    ? _Viewfinder(key: ValueKey(s.generation), controller: controller)
                    : const ColoredBox(color: CamColors.black, child: SizedBox.expand()),
              ),
            ),
            const _Scrims(),
            IgnorePointer(
              child: AnimatedOpacity(
                duration: Motion.fast,
                opacity: s.gridOn ? 1 : 0,
                child: const CustomPaint(painter: _GridPainter(), size: Size.infinite),
              ),
            ),
            if (_focusAt != null)
              Positioned(
                left: _focusAt!.dx - CamSize.focusReticle / 2,
                top: _focusAt!.dy - CamSize.focusReticle / 2,
                child: IgnorePointer(child: _FocusReticle(key: ValueKey(_focusTick), visible: _focusVisible)),
              ),
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _flash ? 0.7 : 0,
                child: const ColoredBox(color: CamColors.fg, child: SizedBox.expand()),
              ),
            ),

            // Top bar + non-blocking notices.
            Positioned(
              top: pad.top + Space.s2,
              left: sideInset,
              right: rightInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(state: s, onStamp: _openStudio),
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _editing ? 0 : 1,
                    child: AnimatedSize(
                      duration: Motion.fast,
                      curve: Motion.ease,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final n in notices)
                            Padding(
                              padding: EdgeInsets.only(top: Space.s3, right: landscape ? size.width * 0.35 : 0),
                              child: n,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (s.isRecording)
              Positioned(
                top: pad.top + Space.s2 + 5,
                left: 0,
                right: 0,
                child: Center(child: _RecordingPill(elapsed: s.recordingElapsed)),
              ),

            // Controls.
            if (landscape)
              Positioned(
                top: pad.top + Space.s2 + CamSize.iconButton,
                bottom: 0,
                right: rightInset,
                child: IgnorePointer(
                  ignoring: _editing,
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _editing ? 0 : 1,
                    child: Center(child: _landscapeControls(s)),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MeasureSize(
                  onChange: (sz) {
                    if (mounted && sz.height != _controlsHeight) setState(() => _controlsHeight = sz.height);
                  },
                  child: IgnorePointer(
                    ignoring: _editing,
                    child: AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: _editing ? 0 : 1,
                      child: _portraitControls(s),
                    ),
                  ),
                ),
              ),

            // Live stamp (lifts above the Stamp studio sheet while editing).
            AnimatedPositioned(
              duration: Motion.sheet,
              curve: Motion.ease,
              left: landscape ? sideInset - Space.s4 : 0,
              right: landscape ? null : 0,
              width: landscape ? math.min(400, size.width * 0.5) : null,
              bottom: stampBottom,
              child: _StampZone(
                stampKey: _stampKey,
                editing: _editing,
                note: s.draftNote,
                onNote: s.isRecording ? null : _openNote,
                onTemplate: _openStudio,
              ),
            ),

            // Toast (top, never over the shutter).
            Positioned(
              top: pad.top + Space.s2 + CamSize.iconButton + Space.s3,
              left: sideInset,
              right: rightInset,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, -0.2), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: _toast == null
                      ? const SizedBox.shrink()
                      : CamToast(key: ValueKey(_toast), message: _toast!, tone: _toastTone),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _notices(CameraStateData s, PermissionState p) {
    if (!p.loaded) return const [];
    final out = <Widget>[];
    if (!p.locationUsable) {
      final permOff = !p.location.isGranted;
      out.add(InlineNotice(
        key: const ValueKey('loc'),
        icon: Icons.location_off_outlined,
        title: permOff ? 'Location not allowed' : 'Location services are off',
        subtitle: permOff ? 'Photos still save with time & compass' : 'Using last known place for now',
        action: permOff ? (p.location.needsSettings ? 'Open Settings' : 'Allow') : 'Turn on',
        onAction: () => _askLocation(p),
      ));
    }
    if (s.mode == CaptureMode.video && !p.microphone.isGranted) {
      out.add(InlineNotice(
        key: const ValueKey('mic'),
        icon: Icons.mic_off_outlined,
        title: 'Recording without sound',
        subtitle: 'Allow microphone for audio',
        action: p.microphone.needsSettings ? 'Open Settings' : 'Allow',
        onAction: () => _askMicrophone(p),
      ));
    }
    return out;
  }

  Widget _zoom(CameraStateData s, {Axis direction = Axis.horizontal}) => ZoomSelector(
        effectiveZoom: s.effectiveZoom,
        showUltraWide: s.canUltraWide,
        direction: direction,
        onSelect: _cam.tapZoomPreset,
      );

  Widget _portraitControls(CameraStateData s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s6, 0, Space.s6, Space.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoom(s),
          const SizedBox(height: Space.s3),
          ModeSwitch(mode: s.mode, enabled: !s.isRecording, onChange: _onMode),
          const SizedBox(height: Space.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LastCaptureThumb(repo: _repo, enabled: !s.isRecording),
              _shutter(s),
              _FlipButton(enabled: !s.isRecording && s.cameras.length > 1, onTap: _cam.flipCamera),
            ],
          ),
        ],
      ),
    );
  }

  Widget _landscapeControls(CameraStateData s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoom(s, direction: Axis.vertical),
        const SizedBox(width: Space.s4),
        ModeSwitch(mode: s.mode, enabled: !s.isRecording, onChange: _onMode, direction: Axis.vertical),
        const SizedBox(width: Space.s4),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FlipButton(enabled: !s.isRecording && s.cameras.length > 1, onTap: _cam.flipCamera),
            const SizedBox(height: Space.s3),
            _shutter(s),
            const SizedBox(height: Space.s3),
            _LastCaptureThumb(repo: _repo, enabled: !s.isRecording),
          ],
        ),
      ],
    );
  }

  Widget _shutter(CameraStateData s) => ShutterButton(
        mode: s.mode,
        isRecording: s.isRecording,
        saving: _pendingSaves > 0,
        enabled: s.isReady,
        onTap: _onShutter,
      );
}

// ──────────────────────────────────────────────────────────────────────────

class _Viewfinder extends StatelessWidget {
  final cam.CameraController controller;
  const _Viewfinder({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return const ColoredBox(color: CamColors.black, child: SizedBox.expand());
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    // previewSize is reported in sensor (landscape) orientation.
    final w = portrait ? preview.height : preview.width;
    final h = portrait ? preview.width : preview.height;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: w, height: h, child: cam.CameraPreview(controller)),
        ),
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [CamColors.scrimTop, Color(0x00000000)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), CamColors.scrimBottom],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CamColors.grid
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _FocusReticle extends StatelessWidget {
  final bool visible;
  const _FocusReticle({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: visible ? 1 : 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.2, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Motion.ease,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: CamSize.focusReticle,
          height: CamSize.focusReticle,
          decoration: BoxDecoration(
            border: Border.all(color: CamColors.focus, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CameraStateData state;
  final VoidCallback onStamp;
  const _TopBar({required this.state, required this.onStamp});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    return Row(
      children: [
        CamIconButton(
          icon: state.flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          tooltip: 'Flash',
          on: state.flashOn,
          onTap: () {
            Haptics.selection();
            cubit.toggleFlash();
          },
        ),
        const SizedBox(width: Space.s2),
        CamIconButton(
          icon: Icons.grid_on_rounded,
          tooltip: 'Grid',
          on: state.gridOn,
          onTap: () {
            Haptics.selection();
            cubit.toggleGrid();
          },
        ),
        const Spacer(),
        CamIconButton(icon: Icons.grid_view_rounded, tooltip: 'Stamp', onTap: onStamp),
      ],
    );
  }
}

class _RecordingPill extends StatelessWidget {
  final Duration elapsed;
  const _RecordingPill({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = elapsed.inHours;
    final t = '${h > 0 ? '$h:' : ''}${two(elapsed.inMinutes.remainder(60))}:${two(elapsed.inSeconds.remainder(60))}';
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
      decoration: BoxDecoration(color: CamColors.record, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: CamColors.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(t, style: monoStyle(size: TextSize.xs, color: CamColors.fg, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StampZone extends StatelessWidget {
  final GlobalKey stampKey;
  final bool editing;
  final String note;
  final VoidCallback? onNote;
  final VoidCallback onTemplate;

  const _StampZone({
    required this.stampKey,
    required this.editing,
    required this.note,
    required this.onNote,
    required this.onTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final template = context.select<TemplateCubit, TemplateId>((c) => c.state.template);
    final accent = GeoColors.dark.accent;
    const r = Radii.lg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: CamSize.pill,
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: editing,
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: editing ? 0 : 1,
                    child: Row(
                      children: [
                        Flexible(
                          child: CamPill(
                            leading: Icons.edit_outlined,
                            label: note.isEmpty ? 'Add note' : note,
                            filled: note.isNotEmpty,
                            onTap: onNote,
                          ),
                        ),
                        const SizedBox(width: Space.s2),
                        const Spacer(),
                        CamPill(
                          label: templateMeta(template).name,
                          trailing: Icons.keyboard_arrow_down_rounded,
                          onTap: onTemplate,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: editing ? 1 : 0,
                      child: const _LivePreviewHint(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s2),
          IgnorePointer(
            ignoring: editing,
            child: GestureDetector(
              onTap: onTemplate,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  LiveStamp(boundaryKey: stampKey),
                  // Accent ring while editing (outside the RepaintBoundary, so
                  // it's never burned into media).
                  Positioned(
                    left: -2,
                    top: -2,
                    right: -2,
                    bottom: -2,
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r + 2),
                          border: Border.all(color: editing ? accent : accent.withValues(alpha: 0), width: 2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -6,
                    top: -6,
                    right: -6,
                    bottom: -6,
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r + 6),
                          border: Border.all(color: editing ? CamColors.glassBorder : const Color(0x00000000), width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePreviewHint extends StatelessWidget {
  const _LivePreviewHint();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: Space.s3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: CamColors.live, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'Live preview',
              style: TextStyle(fontSize: TextSize.xs, fontWeight: FontWeight.w600, color: CamColors.fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastCaptureThumb extends StatelessWidget {
  final CaptureRepository repo;
  final bool enabled;
  const _LastCaptureThumb({required this.repo, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Capture>>(
      stream: repo.changes,
      initialData: repo.items,
      builder: (context, snap) {
        final items = snap.data ?? const <Capture>[];
        final last = items.isEmpty ? null : items.first;
        final thumb = last?.thumbPath ?? (last != null && !last.isVideo ? last.filePath : null);
        return Semantics(
          button: true,
          label: 'Open library, ${items.length} items',
          child: GestureDetector(
            onTap: enabled ? () => context.read<TabCubit>().go(AppTab.library) : null,
            child: Container(
              width: CamSize.sideButton,
              height: CamSize.sideButton,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: GeoColors.dark.surface2,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: CamColors.fgMuted, width: 1.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb != null)
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      child: Image.file(
                        File(thumb),
                        key: ValueKey(thumb),
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    )
                  else
                    const Icon(Icons.photo_library_outlined, size: CamSize.icon, color: CamColors.fgMuted),
                  if (items.isNotEmpty)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: CamColors.scrimBottom,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${items.length}',
                          style: monoStyle(size: CamSize.microText, color: CamColors.fg),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlipButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _FlipButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Switch camera',
      child: GestureDetector(
        onTap: enabled
            ? () {
                Haptics.selection();
                onTap();
              }
            : null,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: enabled ? 1 : 0.4,
          child: SizedBox.square(
            dimension: CamSize.sideButton,
            child: Glass(
              borderRadius: BorderRadius.circular(Radii.md),
              child: const Icon(Icons.cameraswitch_outlined, size: CamSize.icon, color: CamColors.fg),
            ),
          ),
        ),
      ),
    );
  }
}
