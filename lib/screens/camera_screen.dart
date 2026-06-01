import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../cubits/camera_cubit.dart';
import '../cubits/location_overlay_cubit.dart';
import '../cubits/template_cubit.dart';
import '../services/photo_stamper.dart';
import '../services/video_stamper.dart';
import '../services/watermark_service.dart';
import '../templates/templates.dart';
import '../widgets/geotag_overlay.dart';
import '../widgets/mode_carousel.dart';
import '../widgets/shutter_button.dart';
import '../widgets/zoom_selector.dart';
import 'template_picker_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final GlobalKey _overlayKey = GlobalKey();
  bool _capturing = false;
  bool _flash = false;
  Offset? _focusDot;
  double _pinchBaseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraCubit>().init();
      context.read<LocationOverlayCubit>().start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final cam = context.read<CameraCubit>();
    final loc = context.read<LocationOverlayCubit>();
    switch (s) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        cam.controller?.dispose();
        loc.stop();
        break;
      case AppLifecycleState.resumed:
        cam.init();
        loc.start();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _onShutter() async {
    if (_capturing) return;
    final cam = context.read<CameraCubit>();
    final s = cam.state;

    // Video mode — no timer for stopping mid-recording.
    if (s.mode == CaptureMode.video) {
      if (s.isRecording) {
        // Capture the watermark BEFORE stopping recording so the overlay is
        // still mounted and the GPS reading is fresh.
        final wm = await _captureWatermarkPng();
        final isFront = cam.state.isFront;
        final file = await cam.stopVideo();
        if (file != null) {
          await _saveVideo(file.path, watermark: wm, isFront: isFront);
        }
        return;
      }
      await cam.runCountdown();
      if (!mounted) return;
      await cam.startVideo();
      return;
    }

    // Photo mode — countdown first if timer enabled.
    await cam.runCountdown();
    if (!mounted) return;

    setState(() {
      _capturing = true;
      _flash = true;
    });
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _flash = false);
    });
    final file = await cam.takePhoto();
    if (file != null) {
      await _saveStampedPhoto(file.path, isFront: cam.state.isFront);
    }
    if (mounted) setState(() => _capturing = false);
  }

  Future<void> _onTapFocus(TapDownDetails d, Size viewSize) async {
    final ctrl = context.read<CameraCubit>().controller;
    if (ctrl == null) return;
    final nx = (d.localPosition.dx / viewSize.width).clamp(0.0, 1.0);
    final ny = (d.localPosition.dy / viewSize.height).clamp(0.0, 1.0);
    try {
      await ctrl.setFocusPoint(Offset(nx, ny));
      await ctrl.setExposurePoint(Offset(nx, ny));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _focusDot = d.localPosition);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _focusDot = null);
    });
  }

  void _onPinchStart(ScaleStartDetails _) {
    _pinchBaseZoom = context.read<CameraCubit>().state.zoom;
  }

  void _onPinchUpdate(ScaleUpdateDetails d) {
    if (d.scale == 1.0) return;
    context.read<CameraCubit>().setZoom(_pinchBaseZoom * d.scale);
  }

  Future<void> _saveStampedPhoto(String path, {required bool isFront}) async {
    try {
      final raw = await File(path).readAsBytes();

      Uint8List? watermark;
      final boundary =
          _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        watermark = await WatermarkCapture.captureFromBoundary(boundary);
      }

      final stamped = await PhotoStamper.stamp(
        baseJpeg: raw,
        watermarkPng: watermark,
        mirrorBase: isFront,
      );
      final output = stamped ?? raw;

      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/geotag_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(output);

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);
      await Gal.putImageBytes(output, album: 'Geotag');

      _toast('Saved to Photos');
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  Future<Uint8List?> _captureWatermarkPng() async {
    final boundary =
        _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return WatermarkCapture.captureFromBoundary(boundary);
  }

  Future<void> _saveVideo(String path,
      {Uint8List? watermark, required bool isFront}) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) await Gal.requestAccess(toAlbum: true);

      String finalPath = path;
      if (watermark != null) {
        _toast('Processing video…');
        final stamped = await VideoStamper.stamp(
          inputPath: path,
          watermarkPng: watermark,
          mirror: isFront,
        );
        if (stamped != null) finalPath = stamped;
      }

      await Gal.putVideo(finalPath, album: 'Geotag');
      _toast('Video saved');
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<CameraCubit, CameraStateData>(
        builder: (context, s) {
          final controller = context.read<CameraCubit>().controller;
          if (s.isInitializing || controller == null || !controller.value.isInitialized) {
            if (s.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Gesture-wrapped viewfinder: tap = focus, pinch = zoom
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final viewSize = Size(c.maxWidth, c.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _onTapFocus(d, viewSize),
                      onScaleStart: _onPinchStart,
                      onScaleUpdate: _onPinchUpdate,
                      child: _Viewfinder(controller: controller),
                    );
                  },
                ),
              ),

              // Capture-flash overlay
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _flash ? 0.45 : 0.0,
                  child: Container(color: Colors.white),
                ),
              ),

              // Self-timer countdown overlay
              if (s.countdown != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: _CountdownNumber(value: s.countdown!),
                    ),
                  ),
                ),

              // Tap-focus indicator
              if (_focusDot != null)
                Positioned(
                  left: _focusDot!.dx - 30,
                  top: _focusDot!.dy - 30,
                  child: const _FocusRing(),
                ),

              // Orientation-aware control layout.
              if (MediaQuery.of(context).orientation == Orientation.portrait) ...[
                Positioned(
                  top: media.padding.top + 6,
                  left: 12,
                  right: 12,
                  child: _TopBar(state: s),
                ),
                if (s.isRecording)
                  Positioned(
                    top: media.padding.top + 60,
                    left: 0,
                    right: 0,
                    child: Center(
                        child: _RecordingPill(elapsed: s.recordingElapsed)),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _PortraitBottomStack(
                    state: s,
                    capturing: _capturing,
                    overlayKey: _overlayKey,
                    effectiveZoom: context.read<CameraCubit>().effectiveZoom,
                    onShutter: _onShutter,
                    onFlip: () => context.read<CameraCubit>().flipCamera(),
                    onMode: (m) => context.read<CameraCubit>().setMode(m),
                    onPreset: (p) =>
                        context.read<CameraCubit>().tapZoomPreset(p),
                  ),
                ),
              ] else ...[
                // Landscape: bottom strip first (drawn UNDER the rails so its
                // gradient container doesn't swallow taps that belong to the
                // right rail's mode toggle).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _LandscapeBottomStrip(
                    state: s,
                    overlayKey: _overlayKey,
                    effectiveZoom: context.read<CameraCubit>().effectiveZoom,
                    onPreset: (p) =>
                        context.read<CameraCubit>().tapZoomPreset(p),
                  ),
                ),
                Positioned(
                  top: media.padding.top + 10,
                  bottom: media.padding.bottom + 12,
                  left: math.max<double>(media.padding.left, 12.0),
                  child: _LandscapeLeftRail(
                    state: s,
                    isRecording: s.isRecording,
                  ),
                ),
                Positioned(
                  top: media.padding.top + 10,
                  bottom: media.padding.bottom + 12,
                  right: math.max<double>(media.padding.right, 12.0),
                  child: _LandscapeRightRail(
                    state: s,
                    capturing: _capturing,
                    onShutter: _onShutter,
                    onFlip: () => context.read<CameraCubit>().flipCamera(),
                    onMode: (m) => context.read<CameraCubit>().setMode(m),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  final cam.CameraController controller;
  const _Viewfinder({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final preview = controller.value.previewSize;
    if (preview == null) return const ColoredBox(color: Colors.black);

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final pw = isPortrait ? preview.height : preview.width;
    final ph = isPortrait ? preview.width : preview.height;
    final scale = (size.width / pw < size.height / ph)
        ? size.height / ph
        : size.width / pw;

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SizedBox(
          width: pw * scale,
          height: ph * scale,
          child: cam.CameraPreview(controller),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CameraStateData state;
  const _TopBar({required this.state});

  IconData _flashIcon(GeotagFlash f) => switch (f) {
        GeotagFlash.off => Icons.flash_off,
        GeotagFlash.on => Icons.flash_on,
        GeotagFlash.auto => Icons.flash_auto,
      };

  @override
  Widget build(BuildContext context) {
    final timerLabel = state.timer == SelfTimer.off
        ? null
        : '${state.timer.seconds}s';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: _flashIcon(state.flash),
          onTap: () => context.read<CameraCubit>().cycleFlash(),
        ),
        BlocBuilder<TemplateCubit, TemplateId>(
          builder: (context, tid) {
            final meta = kTemplates.firstWhere((t) => t.id == tid);
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TemplatePickerScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_customize_outlined,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(meta.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white70, size: 16),
                  ],
                ),
              ),
            );
          },
        ),
        _CircleIconButton(
          icon: state.timer == SelfTimer.off ? Icons.timer_outlined : Icons.timer,
          label: timerLabel,
          highlighted: state.timer != SelfTimer.off,
          onTap: () => context.read<CameraCubit>().cycleTimer(),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool highlighted;
  final VoidCallback onTap;
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? Colors.amber.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.45);
    final fg = highlighted ? Colors.black : Colors.white;
    return Material(
      color: bg,
      shape: StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 20),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label!,
                    style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  final Duration elapsed;
  const _RecordingPill({required this.elapsed});

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmt(elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

/// Vertically stacked bottom area: overlay card, zoom row, shutter row, modes.
class _PortraitBottomStack extends StatelessWidget {
  final CameraStateData state;
  final bool capturing;
  final GlobalKey overlayKey;
  final double effectiveZoom;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final ValueChanged<CaptureMode> onMode;
  final ValueChanged<double> onPreset;

  const _PortraitBottomStack({
    required this.state,
    required this.capturing,
    required this.overlayKey,
    required this.effectiveZoom,
    required this.onShutter,
    required this.onFlip,
    required this.onMode,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 16, 12, 22 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: overlayKey,
            child: const GeotagOverlay(),
          ),
          const SizedBox(height: 14),
          ZoomSelector(
            effectiveZoom: effectiveZoom,
            maxZoomOnActive: state.maxZoom,
            activeLensLabel: state.backLenses
                .firstWhere(
                  (l) => l.cameraIndex == state.activeIndex,
                  orElse: () => const LensOption(
                      cameraIndex: 0, role: LensRole.wide, label: 1.0),
                )
                .label,
            lenses: state.backLenses,
            onSelectPreset: onPreset,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left spacer keeps shutter centered; flip on right.
              const SizedBox(width: 52),
              ShutterButton(
                mode: state.mode,
                isRecording: state.isRecording,
                onTap: onShutter,
              ),
              SizedBox(
                width: 52,
                child: Center(
                  child: IconButton(
                    onPressed: state.isRecording ? null : onFlip,
                    icon: const Icon(Icons.flip_camera_android_outlined,
                        color: Colors.white, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ModeCarousel(
            mode: state.mode,
            onChange: onMode,
            enabled: !state.isRecording,
          ),
        ],
      ),
    );
  }
}

class _CountdownNumber extends StatelessWidget {
  final int value;
  const _CountdownNumber({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 1.4, end: 0.95),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (_, v, __) => Transform.scale(
        scale: v,
        child: Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 140,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 18, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.4, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Transform.scale(
        scale: v,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 2),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Landscape rails — controls on left/right edges, overlay strip at bottom.

class _LandscapeLeftRail extends StatelessWidget {
  final CameraStateData state;
  final bool isRecording;
  const _LandscapeLeftRail({required this.state, required this.isRecording});

  IconData _flashIcon(GeotagFlash f) => switch (f) {
        GeotagFlash.off => Icons.flash_off,
        GeotagFlash.on => Icons.flash_on,
        GeotagFlash.auto => Icons.flash_auto,
      };

  @override
  Widget build(BuildContext context) {
    final timerLabel = state.timer == SelfTimer.off ? null : '${state.timer.seconds}s';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CircleIconButton(
              icon: _flashIcon(state.flash),
              onTap: () => context.read<CameraCubit>().cycleFlash(),
            ),
            const SizedBox(height: 10),
            BlocBuilder<TemplateCubit, TemplateId>(
              builder: (context, tid) {
                final meta = kTemplates.firstWhere((t) => t.id == tid);
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const TemplatePickerScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dashboard_customize_outlined,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(meta.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _CircleIconButton(
              icon: state.timer == SelfTimer.off ? Icons.timer_outlined : Icons.timer,
              label: timerLabel,
              highlighted: state.timer != SelfTimer.off,
              onTap: () => context.read<CameraCubit>().cycleTimer(),
            ),
          ],
        ),
        if (isRecording) _RecordingPill(elapsed: state.recordingElapsed),
      ],
    );
  }
}

class _LandscapeRightRail extends StatelessWidget {
  final CameraStateData state;
  final bool capturing;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final ValueChanged<CaptureMode> onMode;

  const _LandscapeRightRail({
    required this.state,
    required this.capturing,
    required this.onShutter,
    required this.onFlip,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: state.isRecording ? null : onFlip,
          icon: const Icon(Icons.flip_camera_android_outlined,
              color: Colors.white, size: 24),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 20),
        ShutterButton(
          mode: state.mode,
          isRecording: state.isRecording,
          onTap: onShutter,
        ),
        const SizedBox(height: 14),
        // Vertical mode toggle — no RotatedBox (its hit region falls outside
        // the parent rail's bounds in some layouts and swallows taps).
        _VerticalModeToggle(
          mode: state.mode,
          onChange: onMode,
          enabled: !state.isRecording,
        ),
      ],
    );
  }
}

class _VerticalModeToggle extends StatelessWidget {
  final CaptureMode mode;
  final ValueChanged<CaptureMode> onChange;
  final bool enabled;

  const _VerticalModeToggle({
    required this.mode,
    required this.onChange,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modePill('PHOTO', CaptureMode.photo),
              const SizedBox(height: 4),
              _modePill('VIDEO', CaptureMode.video),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modePill(String label, CaptureMode m) {
    final active = mode == m;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChange(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _LandscapeBottomStrip extends StatelessWidget {
  final CameraStateData state;
  final GlobalKey overlayKey;
  final double effectiveZoom;
  final ValueChanged<double> onPreset;

  const _LandscapeBottomStrip({
    required this.state,
    required this.overlayKey,
    required this.effectiveZoom,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Reserve room for the side rails (~80px each) PLUS the device's own
    // landscape safe-area cutouts (Dynamic Island lives on one side).
    final leftInset = math.max<double>(media.padding.left, 0.0) + 80.0;
    final rightInset = math.max<double>(media.padding.right, 0.0) + 80.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
          leftInset, 8, rightInset, 10 + media.padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RepaintBoundary(
              key: overlayKey,
              child: const GeotagOverlay(compact: true),
            ),
          ),
          const SizedBox(width: 12),
          ZoomSelector(
            effectiveZoom: effectiveZoom,
            maxZoomOnActive: state.maxZoom,
            activeLensLabel: state.backLenses
                .firstWhere(
                  (l) => l.cameraIndex == state.activeIndex,
                  orElse: () => const LensOption(
                      cameraIndex: 0, role: LensRole.wide, label: 1.0),
                )
                .label,
            lenses: state.backLenses,
            onSelectPreset: onPreset,
          ),
        ],
      ),
    );
  }
}
