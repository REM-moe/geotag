import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/camera_cubit.dart';
import '../cubits/location_overlay_cubit.dart';
import '../cubits/template_cubit.dart';
import '../templates/templates.dart';
import '../theme/tokens.dart';

/// The live stamp shown on the viewfinder: current template/surface/fields,
/// live location and the pending spot note. Every config change plays a
/// short "bump" so the user sees what changed.
///
/// [boundaryKey] wraps the bare stamp in a `RepaintBoundary` so it can be
/// rasterised and burned into captured media.
class LiveStamp extends StatefulWidget {
  final GlobalKey boundaryKey;
  const LiveStamp({super.key, required this.boundaryKey});

  @override
  State<LiveStamp> createState() => _LiveStampState();
}

class _LiveStampState extends State<LiveStamp> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keep the time on the stamp current even without location updates.
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<TemplateCubit>().state;
    final loc = context.watch<LocationOverlayCubit>().state;
    final note = context.select<CameraCubit, String>((c) => c.state.draftNote);
    return Bump(
      trigger: (config, note),
      child: AnimatedSize(
        duration: Motion.sheet,
        curve: Motion.ease,
        alignment: Alignment.bottomCenter,
        child: RepaintBoundary(
          key: widget.boundaryKey,
          child: StampView(config: config, data: StampData.live(loc, note: note)),
        ),
      ),
    );
  }
}

/// Plays a 240 ms scale/fade-in whenever [trigger] changes.
class Bump extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  const Bump({super.key, required this.trigger, required this.child});

  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.ease);

  @override
  void didUpdateWidget(covariant Bump oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: 0.55 + 0.45 * _t.value,
        child: Transform.scale(scale: 0.97 + 0.03 * _t.value, child: child),
      ),
    );
  }
}
