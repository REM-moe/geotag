import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/template_cubit.dart';
import '../../templates/templates.dart';
import '../../theme/tokens.dart';
import '../../services/capture_prefs.dart';
import 'sheet_kit.dart';

/// Compact Stamp studio. Shown with a transparent scrim; the real stamp on
/// the viewfinder lifts above this sheet and updates live.
class StampStudioSheet extends StatelessWidget {
  const StampStudioSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TemplateCubit>();
    void tap(VoidCallback f) {
      Haptics.selection();
      f();
    }

    return BlocBuilder<TemplateCubit, StampConfig>(
      builder: (context, c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(
            title: 'Stamp',
            subtitle: 'Changes show live on your photo above',
            action: SheetButton(
              label: 'Done',
              size: SheetButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Row(
            spacing: Space.s2,
            children: [
              for (final t in kTemplates)
                Expanded(
                  child: _TemplateTile(
                    meta: t,
                    on: t.id == c.template,
                    onTap: () => tap(() => cubit.select(t.id)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.s3),
          SheetSegmented<StampSurface>(
            options: [for (final s in StampSurface.values) (s, s.label)],
            value: c.surface,
            onChanged: (s) => tap(() => cubit.setSurface(s)),
          ),
          const SizedBox(height: Space.s3),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              SheetChip(label: 'Map', on: c.showMap, onTap: () => tap(cubit.toggleMap)),
              SheetChip(label: 'Coordinates', on: c.showCoords, onTap: () => tap(cubit.toggleCoords)),
              SheetChip(label: 'Altitude & heading', on: c.showAltHeading, onTap: () => tap(cubit.toggleAltHeading)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final TemplateMeta meta;
  final bool on;
  final VoidCallback onTap;
  const _TemplateTile({required this.meta, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Semantics(
      button: true,
      selected: on,
      label: '${meta.name} stamp. ${meta.description}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          padding: const EdgeInsets.all(Space.s2),
          decoration: BoxDecoration(
            color: on ? g.accentSoft : g.bg,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: on ? g.accent : g.border, width: on ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 34,
                decoration: BoxDecoration(color: g.surface2, borderRadius: BorderRadius.circular(Radii.sm)),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned(
                        left: Space.s2,
                        top: 10,
                        width: box.maxWidth * 0.5,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: g.text2, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Positioned(
                        left: Space.s2,
                        top: 20,
                        width: box.maxWidth * 0.34,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: g.text3, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.s2),
              Text(
                meta.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w600, color: g.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
