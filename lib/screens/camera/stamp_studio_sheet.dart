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
                height: 38,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: g.surface2, borderRadius: BorderRadius.circular(Radii.sm)),
                child: _MiniSchematic(id: meta.id, active: on),
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

class _MiniSchematic extends StatelessWidget {
  final TemplateId id;
  final bool active;
  const _MiniSchematic({required this.id, required this.active});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final strong = active ? g.accent : g.text2;
    final faint = active ? g.accent.withValues(alpha: 0.4) : g.text3;

    Widget bar(double h, Color c, [double? w]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        );

    return switch (id) {
      TemplateId.classic => Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(4)),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(4, strong), const SizedBox(height: 4), bar(3, faint, 22)],
              ),
            ),
          ],
        ),
      TemplateId.timestamp => Row(
          children: [
            Text('09', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1, color: strong)),
            Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 5), color: faint),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [bar(4, strong), const SizedBox(height: 4), bar(3, faint, 18)],
              ),
            ),
          ],
        ),
      TemplateId.survey => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(3.5, strong, 28),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: bar(10, faint)),
                const SizedBox(width: 3),
                Expanded(child: bar(10, faint)),
                const SizedBox(width: 3),
                Expanded(child: bar(10, faint)),
              ],
            ),
          ],
        ),
      TemplateId.minimal => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [bar(3.5, strong, 30), const SizedBox(height: 4), bar(2.5, faint, 42)],
        ),
    };
  }
}
