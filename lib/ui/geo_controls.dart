import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One option of a [GeoSegmented] control.
class GeoSegment<T> {
  final T value;
  final String label;
  const GeoSegment(this.value, this.label);
}

/// Equal-width segmented control (mock `.seg`).
class GeoSegmented<T> extends StatelessWidget {
  final List<GeoSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const GeoSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: g.surface2,
        border: Border.all(color: g.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: _segment(context, segments[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, GeoSegment<T> s) {
    final g = context.geo;
    final on = s.value == selected;
    return Semantics(
      selected: on,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(s.value),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? g.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(Space.s2),
            border: Border.all(color: on ? g.border : Colors.transparent),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              fontSize: TextSize.sm,
              fontWeight: FontWeight.w600,
              color: on ? g.text : g.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped filter chip (mock `.chip` / `.chip.on`).
class GeoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const GeoChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final fg = selected ? g.bg : g.text2;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.ease,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
          decoration: BoxDecoration(
            color: selected ? g.text : g.bg,
            borderRadius: BorderRadius.circular(Radii.full),
            border: Border.all(color: selected ? g.text : g.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search box (mock `.search`): 36px, surface fill, hairline border.
class GeoSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const GeoSearchField({super.key, this.controller, this.hint = 'Search', this.onChanged});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
      decoration: BoxDecoration(
        color: g.surface,
        border: Border.all(color: g.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: g.text3),
          const SizedBox(width: Space.s2),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: TextSize.md, color: g.text),
              cursorColor: g.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: hint,
                hintStyle: TextStyle(fontSize: TextSize.md, color: g.text3),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (context, v, _) => v.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: () {
                        controller!.clear();
                        onChanged?.call('');
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: g.text3),
                    ),
            ),
        ],
      ),
    );
  }
}
