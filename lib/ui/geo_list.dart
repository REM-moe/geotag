import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Uppercase micro label above a group (mock `.section-label`).
class GeoSectionLabel extends StatelessWidget {
  final String text;
  const GeoSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s1, 0, Space.s1, Space.s2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: TextSize.xs,
          fontWeight: FontWeight.w600,
          letterSpacing: TextSize.xs * 0.04,
          color: context.geo.text3,
        ),
      ),
    );
  }
}

/// Bordered, rounded container whose children are separated by hairlines
/// (mock `.list`).
class GeoListGroup extends StatelessWidget {
  final List<Widget> children;
  const GeoListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Container(
      decoration: BoxDecoration(
        color: g.bg,
        border: Border.all(color: g.border),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: g.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Row inside a [GeoListGroup] (mock `.row`): optional icon tile, title,
/// subtitle and trailing widget. Pass [onTap] to make it tappable; set
/// [chevron] to show a disclosure arrow.
class GeoListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final int subtitleMaxLines;

  const GeoListRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final lead = leading ??
        (icon == null
            ? null
            : Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: g.surface2,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(icon, size: 16, color: g.text2),
              ));

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: Space.s3)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSize.md, fontWeight: FontWeight.w500, color: g.text),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: TextSize.sm, color: g.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: Space.s3), trailing!],
            if (chevron) ...[
              const SizedBox(width: Space.s2),
              Icon(Icons.chevron_right_rounded, size: 18, color: g.text3),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, hoverColor: g.surface, child: row);
  }
}

/// Key/value rows with mono values (mock `.dl` inside a `.card`).
class GeoDescriptionList extends StatelessWidget {
  final List<(String, String)> entries;
  const GeoDescriptionList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
      decoration: BoxDecoration(
        color: g.bg,
        border: Border.all(color: g.border),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: Space.s3),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: g.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(entries[i].$1, style: TextStyle(fontSize: TextSize.sm, color: g.text2)),
                  const SizedBox(width: Space.s4),
                  Expanded(
                    child: SelectableText(
                      entries[i].$2,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      style: monoStyle(size: TextSize.xs, color: g.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
