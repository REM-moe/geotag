import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Large page title with subtitle and trailing action (mock `.app-header`).
/// Includes the top safe-area inset.
class GeoPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const GeoPageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: TextSize.xxl,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02 * TextSize.xxl,
                      color: g.text,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: TextSize.sm, color: g.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: Space.s3), trailing!],
          ],
        ),
      ),
    );
  }
}
