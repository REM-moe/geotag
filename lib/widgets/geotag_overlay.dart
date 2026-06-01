import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/location_overlay_cubit.dart';
import '../cubits/template_cubit.dart';
import '../templates/templates.dart';

/// Live geotag card laid over the camera viewfinder. Renders whichever
/// template is currently selected, with the floating `hellosalvia.com`
/// brand chip on top.
///
/// The outer `Stack` reserves vertical room at the top so the chip overhang
/// stays inside the RepaintBoundary's layout box — otherwise
/// `toImage()` crops it when burning the watermark onto a captured photo.
class GeotagOverlay extends StatelessWidget {
  final bool compact;
  const GeotagOverlay({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const chipOverhang = 14.0;

    return BlocBuilder<TemplateCubit, TemplateId>(
      builder: (context, templateId) {
        return BlocBuilder<LocationOverlayCubit, LocationOverlayState>(
          builder: (context, s) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: chipOverhang),
                  child: buildTemplate(templateId, s, compact: compact),
                ),
                Positioned(
                  top: 0,
                  right: 10,
                  child: _BrandChip(scheme: scheme),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BrandChip extends StatelessWidget {
  final ColorScheme scheme;
  const _BrandChip({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.eco, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Text(
            'hellosalvia.com',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
