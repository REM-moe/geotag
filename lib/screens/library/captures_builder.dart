import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/capture.dart';
import '../../data/capture_repository.dart';

/// Rebuilds with the repository's current captures (initial snapshot +
/// every change). Handy for screens that only need the raw list.
class CapturesBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, List<Capture> items) builder;
  const CapturesBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CaptureRepository>();
    return StreamBuilder<List<Capture>>(
      stream: repo.changes,
      initialData: repo.items,
      builder: (context, snap) => builder(context, snap.data ?? repo.items),
    );
  }
}
