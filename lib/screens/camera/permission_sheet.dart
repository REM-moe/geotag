import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'sheet_kit.dart';

/// Rationale shown before a system permission prompt (mock `#sh-perm`).
/// Pops `true` when the user taps the primary action.
class PermissionRationaleSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String cta;

  const PermissionRationaleSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.cta = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: g.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Icon(icon, size: 20, color: g.accent),
          ),
          const SizedBox(height: Space.s3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: TextSize.lg, fontWeight: FontWeight.w600, color: g.text),
          ),
          const SizedBox(height: Space.s3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TextSize.sm, color: g.text2, height: 1.45),
            ),
          ),
          const SizedBox(height: Space.s5),
          SheetButton(
            label: cta,
            size: SheetButtonSize.lg,
            block: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Space.s2),
          SheetButton(
            label: 'Not now',
            kind: SheetButtonKind.ghost,
            block: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
