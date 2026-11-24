import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'geo_badge.dart';

/// Inline, non-blocking alert (mock `.alert.info` / `.alert.warn`).
class GeoAlert extends StatelessWidget {
  final String title;
  final String? body;
  final IconData icon;
  final GeoTone tone;
  final Widget? action;

  const GeoAlert({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.info_outline_rounded,
    this.tone = GeoTone.accent,
    this.action,
  });

  const GeoAlert.warning({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.warning_amber_rounded,
    this.action,
  }) : tone = GeoTone.warning;

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final warn = tone == GeoTone.warning;
    final (fg, _) = tone.resolve(g);
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: warn ? g.warningSoft : g.surface,
        border: Border.all(color: warn ? Colors.transparent : g.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w600, color: g.text)),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!, style: TextStyle(fontSize: TextSize.sm, color: g.text2)),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: Space.s3), action!],
        ],
      ),
    );
  }
}

/// Centered empty state (mock `.empty`).
class GeoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const GeoEmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s10, horizontal: Space.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: g.surface2, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Icon(icon, size: 20, color: g.text3),
          ),
          const SizedBox(height: Space.s1 + Space.s2),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TextSize.md, fontWeight: FontWeight.w600, color: g.text)),
          if (message != null) ...[
            const SizedBox(height: Space.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(message!,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: TextSize.sm, color: g.text2)),
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.s4), action!],
        ],
      ),
    );
  }
}

/// Floating toast (mock `.toast`): inverted surface, optional green check.
void showGeoToast(BuildContext context, String message, {bool success = true}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final g = context.geo;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        margin: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
        padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
        backgroundColor: g.text,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        content: Row(
          children: [
            if (success) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: g.positive, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: Space.s3),
            ],
            Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w500, color: g.bg)),
            ),
          ],
        ),
      ),
    );
}
