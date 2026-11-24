import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../cubits/permission_cubit.dart';
import '../../data/capture.dart';
import '../../shell/tab_cubit.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../detail/capture_detail_screen.dart';
import '../library/capture_format.dart';
import '../library/capture_thumb.dart';
import '../library/captures_builder.dart';

enum _NotesTab { recent, nearby }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  _NotesTab _tab = _NotesTab.recent;
  Position? _position;
  bool _locating = false;

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    Position? p;
    try {
      p = await Geolocator.getLastKnownPosition();
      p ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _position = p ?? _position;
      _locating = false;
    });
  }

  void _selectTab(_NotesTab t) {
    setState(() => _tab = t);
    if (t == _NotesTab.nearby && context.read<PermissionCubit>().state.locationUsable) _locate();
  }

  double? _distanceTo(Capture c) {
    final p = _position;
    if (p == null || !c.hasLocation) return null;
    return Geolocator.distanceBetween(p.latitude, p.longitude, c.latitude!, c.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final perms = context.watch<PermissionCubit>().state;
    return BlocListener<PermissionCubit, PermissionState>(
      listenWhen: (a, b) => !a.locationUsable && b.locationUsable,
      listener: (_, _) {
        if (_tab == _NotesTab.nearby) _locate();
      },
      child: CapturesBuilder(builder: (context, items) {
        final notes = items.where((c) => c.hasNote).toList()
          ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
        final areas = notes.map((c) => CaptureFormat.place(c)).toSet().length;

        final nearby = _tab == _NotesTab.nearby;
        final canSort = nearby && perms.locationUsable && _position != null;
        final distances = <String, double?>{for (final c in notes) c.id: canSort ? _distanceTo(c) : null};
        final list = [...notes];
        if (canSort) {
          list.sort((a, b) {
            final da = distances[a.id], db = distances[b.id];
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GeoPageHeader(
              title: 'Notes',
              subtitle: '${notes.length} ${notes.length == 1 ? 'note' : 'notes'} across $areas '
                  '${areas == 1 ? 'place' : 'places'}',
              trailing: GeoButton(
                label: 'New',
                icon: Icons.add_rounded,
                size: GeoButtonSize.sm,
                onPressed: () => context.read<TabCubit>().go(AppTab.capture),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s8),
                children: [
                  GeoSegmented<_NotesTab>(
                    segments: const [
                      GeoSegment(_NotesTab.recent, 'Recent'),
                      GeoSegment(_NotesTab.nearby, 'Nearby'),
                    ],
                    selected: _tab,
                    onChanged: _selectTab,
                  ),
                  if (nearby && !perms.locationUsable) ...[
                    const SizedBox(height: Space.s4),
                    _LocationNeeded(perms: perms),
                  ] else if (nearby && _position == null && !_locating) ...[
                    const SizedBox(height: Space.s4),
                    GeoAlert(
                      icon: Icons.location_searching_rounded,
                      title: 'Couldn\'t find your position',
                      body: 'Showing most recent notes instead.',
                      action: GeoButton(
                        label: 'Retry',
                        variant: GeoButtonVariant.secondary,
                        size: GeoButtonSize.sm,
                        onPressed: _locate,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.s4),
                  if (notes.isEmpty)
                    const GeoEmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'No notes yet',
                      message: 'Add a note while shooting or from any photo.',
                    )
                  else
                    GeoListGroup(children: [
                      for (final c in list)
                        _NoteTile(
                          capture: c,
                          badge: canSort
                              ? (distances[c.id] == null ? 'No location' : CaptureFormat.distance(distances[c.id]!))
                              : CaptureFormat.dayLabel(c.takenAt),
                        ),
                    ]),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _LocationNeeded extends StatelessWidget {
  final PermissionState perms;
  const _LocationNeeded({required this.perms});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PermissionCubit>();
    final gpsOff = perms.location.isGranted && !perms.locationServiceEnabled;
    final String title, body, cta;
    if (gpsOff) {
      title = 'Location services are off';
      body = 'Turn on location to sort notes by distance from you.';
      cta = 'Turn on';
    } else {
      title = 'Location needed for Nearby';
      body = 'Allow location to sort notes by distance from you.';
      cta = perms.location.needsSettings ? 'Open Settings' : 'Allow';
    }
    return GeoAlert(
      icon: Icons.location_on_outlined,
      title: title,
      body: body,
      action: GeoButton(
        label: cta,
        variant: GeoButtonVariant.secondary,
        size: GeoButtonSize.sm,
        onPressed: () => gpsOff ? cubit.openLocationSettings() : cubit.ensureLocation(),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Capture capture;
  final String badge;
  const _NoteTile({required this.capture, required this.badge});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final c = capture;
    return InkWell(
      onTap: () => CaptureDetailScreen.open(context, c.id),
      hoverColor: g.surface,
      child: Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: g.text2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    CaptureFormat.place(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSize.sm, fontWeight: FontWeight.w600, color: g.text),
                  ),
                ),
                const SizedBox(width: Space.s2),
                GeoBadge(badge),
              ],
            ),
            const SizedBox(height: Space.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.note,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSize.md, color: g.text),
                  ),
                ),
                const SizedBox(width: Space.s3),
                CaptureThumb(capture: c, size: 40, radius: Radii.sm, decodeWidth: 80),
              ],
            ),
            const SizedBox(height: Space.s2),
            Text(
              c.hasLocation ? CaptureFormat.coords(c) : CaptureFormat.when(c.takenAt),
              style: monoStyle(size: TextSize.xs, color: g.text3),
            ),
          ],
        ),
      ),
    );
  }
}
