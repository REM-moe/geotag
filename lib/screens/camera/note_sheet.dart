import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'sheet_kit.dart';

/// "Note for this spot" — returns the note text (may be empty to clear), or
/// null when cancelled.
class NoteSheet extends StatefulWidget {
  final String initial;
  final String locationLine;
  const NoteSheet({super.key, required this.initial, required this.locationLine});

  static const suggestions = ['Site check-in', 'Best light early', 'Entrance on north side', 'Follow up'];

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: g.borderStrong),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(
          title: 'Note for this spot',
          subtitle: widget.locationLine,
          action: SheetButton(
            label: 'Cancel',
            kind: SheetButtonKind.ghost,
            size: SheetButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 5,
          maxLength: 280,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: TextSize.md, color: g.text),
          decoration: InputDecoration(
            hintText: 'What should you remember about this place?',
            hintStyle: TextStyle(color: g.text3),
            counterText: '',
            filled: true,
            fillColor: g.bg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: g.accent)),
          ),
        ),
        const SizedBox(height: Space.s4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            spacing: Space.s2,
            children: [
              for (final s in NoteSheet.suggestions)
                SheetChip(
                  label: s,
                  onTap: () {
                    _text.text = s;
                    _text.selection = TextSelection.collapsed(offset: s.length);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s4),
        SheetButton(
          label: 'Attach note',
          size: SheetButtonSize.lg,
          block: true,
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
        ),
      ],
    );
  }
}
