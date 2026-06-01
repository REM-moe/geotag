import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/location_overlay_cubit.dart';
import '../cubits/template_cubit.dart';
import '../templates/templates.dart';

class TemplatePickerScreen extends StatelessWidget {
  const TemplatePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Template',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: BlocBuilder<TemplateCubit, TemplateId>(
        builder: (context, current) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: kTemplates.length,
            itemBuilder: (_, i) {
              final t = kTemplates[i];
              final selected = t.id == current;
              return _TemplateRow(
                meta: t,
                selected: selected,
                onTap: () {
                  context.read<TemplateCubit>().select(t.id);
                  Navigator.of(context).pop();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final TemplateMeta meta;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateRow({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${meta.name} Template',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'In use',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meta.tagline,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            // Snapshot the current location once for a static preview —
            // the picker doesn't need live updates and rendering five
            // FlutterMap widgets simultaneously caused render crashes.
            Builder(builder: (ctx) {
              final s = ctx.read<LocationOverlayCubit>().state;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(color: scheme.primary, width: 2)
                      : Border.all(color: scheme.outlineVariant, width: 1),
                ),
                child: buildTemplate(meta.id, s,
                    compact: true, liveMap: false),
              );
            }),
          ],
        ),
      ),
    );
  }
}
