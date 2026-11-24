import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/capture.dart';
import '../../data/capture_repository.dart';
import '../../shell/tab_cubit.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../detail/capture_detail_screen.dart';
import 'capture_format.dart';
import 'capture_thumb.dart';
import 'library_cubit.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LibraryCubit(ctx.read<CaptureRepository>()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LibraryCubit>().state;
    final cubit = context.read<LibraryCubit>();
    final total = state.all.length;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GeoPageHeader(
            title: 'Library',
            subtitle: '$total ${total == 1 ? 'item' : 'items'} · ${state.noteCount} with notes',
            trailing: GeoIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => context.read<TabCubit>().go(AppTab.settings),
            ),
          ),
          Expanded(
            child: total == 0
                ? _NoCaptures(onOpenCamera: () => context.read<TabCubit>().go(AppTab.capture))
                : CustomScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                        sliver: SliverToBoxAdapter(
                          child: GeoSearchField(
                            controller: _search,
                            hint: 'Search places, notes, dates',
                            onChanged: cubit.setQuery,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: Space.s4)),
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                          child: Row(
                            children: [
                              for (final f in LibraryFilter.values) ...[
                                if (f != LibraryFilter.values.first) const SizedBox(width: Space.s2),
                                GeoChip(
                                  label: f.label,
                                  selected: state.filter == f,
                                  onTap: () => cubit.setFilter(f),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: Space.s4)),
                      ..._grid(context, state),
                      const SliverToBoxAdapter(child: SizedBox(height: Space.s8)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _grid(BuildContext context, LibraryState state) {
    final groups = state.groups;
    if (groups.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: GeoEmptyState(
            icon: Icons.search_rounded,
            title: 'Nothing here',
            message: 'Try another filter or search term.',
            action: GeoButton(
              label: 'Clear filters',
              variant: GeoButtonVariant.secondary,
              size: GeoButtonSize.sm,
              onPressed: () {
                _search.clear();
                context.read<LibraryCubit>()
                  ..setQuery('')
                  ..setFilter(LibraryFilter.all);
              },
            ),
          ),
        ),
      ];
    }
    return [
      for (final (i, group) in groups.indexed) ...[
        if (i > 0) const SliverToBoxAdapter(child: SizedBox(height: Space.s4)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
          sliver: SliverToBoxAdapter(child: _DateHead(group: group)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
          sliver: SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                ),
                itemCount: group.items.length,
                itemBuilder: (context, j) => _Tile(capture: group.items[j]),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}

class _DateHead extends StatelessWidget {
  final DayGroup group;
  const _DateHead({required this.group});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final n = group.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s1, 0, Space.s1, Space.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(group.label,
                style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w600, color: g.text)),
          ),
          Text('$n ${n == 1 ? 'item' : 'items'}', style: TextStyle(fontSize: TextSize.xs, color: g.text3)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Capture capture;
  const _Tile({required this.capture});

  @override
  Widget build(BuildContext context) {
    // Overlays sit on top of photos, so they use fixed scrim colours rather
    // than theme tokens (same as the mock's `.flag` / `.dur`).
    const shadow = [Shadow(color: Color(0xB3000000), blurRadius: 3, offset: Offset(0, 1))];
    return Semantics(
      button: true,
      label: '${CaptureFormat.place(capture)}, ${CaptureFormat.when(capture.takenAt)}',
      child: GestureDetector(
        onTap: () => CaptureDetailScreen.open(context, capture.id),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CaptureThumb(capture: capture),
            if (capture.hasNote)
              const Positioned(top: 5, right: 5, child: _Flag(icon: Icons.edit_outlined)),
            if (capture.isVideo)
              Positioned(
                left: 5,
                bottom: 5,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white, shadows: shadow),
                    const SizedBox(width: 2),
                    Text(
                      CaptureFormat.duration(capture.videoDuration),
                      style: monoStyle(size: 10, color: Colors.white).copyWith(shadows: shadow),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  final IconData icon;
  const _Flag({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Space.s5,
      height: Space.s5,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

class _NoCaptures extends StatelessWidget {
  final VoidCallback onOpenCamera;
  const _NoCaptures({required this.onOpenCamera});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Space.s5),
      child: GeoEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No captures yet',
        message: 'Photos and videos you take with Geotag show up here, with their place and notes.',
        action: GeoButton(label: 'Open camera', icon: Icons.photo_camera_outlined, onPressed: onOpenCamera),
      ),
    );
  }
}
