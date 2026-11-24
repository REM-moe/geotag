import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/capture.dart';
import '../../data/capture_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../library/capture_format.dart';
import 'maps_launcher.dart';

/// Full-screen detail for one capture: media, editable note, metadata,
/// open in maps, share and delete.
class CaptureDetailScreen extends StatefulWidget {
  final String captureId;
  const CaptureDetailScreen({super.key, required this.captureId});

  static Future<void> open(BuildContext context, String id) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CaptureDetailScreen(captureId: id)),
      );

  @override
  State<CaptureDetailScreen> createState() => _CaptureDetailScreenState();
}

class _CaptureDetailScreenState extends State<CaptureDetailScreen> {
  late final CaptureRepository _repo = context.read<CaptureRepository>();
  late final TextEditingController _note;
  final _shareKey = GlobalKey();
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: _repo.byId(widget.captureId)?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(Capture c) async {
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(c.filePath, mimeType: c.isVideo ? 'video/mp4' : 'image/jpeg')],
        text: c.hasNote ? c.note : null,
        sharePositionOrigin: _originOf(_shareKey),
      ));
    } catch (_) {
      if (mounted) showGeoToast(context, 'Couldn\'t open share sheet', success: false);
    }
  }

  Future<void> _play(Capture c) async {
    // No in-app player: hand the file to the system, or fall back to share.
    var ok = false;
    try {
      ok = await launchUrl(Uri.file(c.filePath), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) await _share(c);
  }

  Future<void> _saveNote(Capture c) async {
    FocusScope.of(context).unfocus();
    await _repo.updateNote(c.id, _note.text);
    if (mounted) showGeoToast(context, _note.text.trim().isEmpty ? 'Note removed' : 'Note saved');
  }

  Future<void> _openMaps(Capture c) async {
    final ok = await MapsLauncher.open(c);
    if (!ok && mounted) showGeoToast(context, 'No maps app found', success: false);
  }

  Future<void> _delete(Capture c) async {
    final g = context.geo;
    final what = c.isVideo ? 'video' : 'photo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: g.border),
        ),
        title: Text('Delete $what?',
            style: TextStyle(fontSize: TextSize.lg, fontWeight: FontWeight.w600, color: g.text)),
        content: Text(
          'It will be removed from your Geotag library. The copy in your Gallery app is kept.',
          style: TextStyle(fontSize: TextSize.sm, color: g.text2),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
        actions: [
          GeoButton(
            label: 'Cancel',
            variant: GeoButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GeoButton(
            label: 'Delete',
            variant: GeoButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    await _repo.delete(c.id);
    if (!mounted) return;
    showGeoToast(context, '${what[0].toUpperCase()}${what.substring(1)} deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return StreamBuilder<List<Capture>>(
      stream: _repo.changes,
      builder: (context, _) {
        final c = _repo.byId(widget.captureId);
        if (c == null) {
          // Deleted (here or elsewhere) — leave the screen.
          if (!_deleting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
          }
          return Scaffold(backgroundColor: g.bg);
        }
        return Scaffold(
          backgroundColor: g.bg,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                _Header(
                  capture: c,
                  shareKey: _shareKey,
                  onBack: () => Navigator.of(context).maybePop(),
                  onShare: () => _share(c),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + Space.s8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                        child: _Media(capture: c, onPlay: () => _play(c)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(Space.s5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const GeoSectionLabel('Note'),
                            TextField(
                              controller: _note,
                              minLines: 2,
                              maxLines: 6,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(fontSize: TextSize.md, color: g.text),
                              decoration: const InputDecoration(
                                hintText: 'Add a note about this place',
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2 + 2),
                              ),
                            ),
                            const SizedBox(height: Space.s4),
                            const GeoSectionLabel('Details'),
                            GeoDescriptionList(entries: [
                              ('Coordinates', CaptureFormat.coords(c)),
                              ('Altitude', CaptureFormat.altitude(c)),
                              ('Heading', CaptureFormat.heading(c)),
                              ('Accuracy', CaptureFormat.accuracy(c)),
                              if (c.address != null && c.address!.trim().isNotEmpty)
                                ('Address', c.address!.trim()),
                              ('Type', CaptureFormat.type(c)),
                              ('Saved to', 'Gallery · Geotag album'),
                            ]),
                            const SizedBox(height: Space.s4),
                            Row(
                              children: [
                                Expanded(
                                  child: GeoButton(
                                    label: 'Open in Maps',
                                    icon: Icons.map_outlined,
                                    variant: GeoButtonVariant.secondary,
                                    expand: true,
                                    onPressed: c.hasLocation ? () => _openMaps(c) : null,
                                  ),
                                ),
                                const SizedBox(width: Space.s2),
                                Expanded(
                                  child: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _note,
                                    builder: (context, v, _) => GeoButton(
                                      label: 'Save note',
                                      expand: true,
                                      onPressed: v.text.trim() == c.note.trim() ? null : () => _saveNote(c),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.s4),
                            GeoButton(
                              label: c.isVideo ? 'Delete video' : 'Delete photo',
                              variant: GeoButtonVariant.ghost,
                              foreground: g.negative,
                              expand: true,
                              onPressed: _deleting ? null : () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Capture capture;
  final GlobalKey shareKey;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _Header({required this.capture, required this.shareKey, required this.onBack, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s3),
        child: Row(
          children: [
            GeoIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', onPressed: onBack),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Column(
                children: [
                  Text(
                    CaptureFormat.place(capture),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSize.md, fontWeight: FontWeight.w600, color: g.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CaptureFormat.when(capture.takenAt),
                    style: TextStyle(fontSize: TextSize.sm, color: g.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s3),
            GeoIconButton(key: shareKey, icon: Icons.ios_share_rounded, tooltip: 'Share', onPressed: onShare),
          ],
        ),
      ),
    );
  }
}

class _Media extends StatelessWidget {
  final Capture capture;
  final VoidCallback onPlay;
  const _Media({required this.capture, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final path = capture.isVideo ? capture.thumbPath : capture.filePath;
    final placeholder = Center(
      child: Icon(capture.isVideo ? Icons.videocam_outlined : Icons.image_outlined, color: g.text3),
    );
    final image = path == null
        ? placeholder
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: g.surface2, child: image),
            if (!capture.isVideo)
              Positioned.fill(
                child: GestureDetector(onTap: () => _FullScreenPhoto.open(context, capture.filePath)),
              ),
            if (capture.isVideo) ...[
              Center(
                child: Semantics(
                  button: true,
                  label: 'Play video',
                  child: GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
              if (capture.videoDuration != null)
                Positioned(
                  left: Space.s3,
                  bottom: Space.s3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      CaptureFormat.duration(capture.videoDuration),
                      style: monoStyle(size: TextSize.xs, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pinch-zoomable full screen photo viewer.
class _FullScreenPhoto extends StatelessWidget {
  final String path;
  const _FullScreenPhoto({required this.path});

  static void open(BuildContext context, String path) => Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black,
          transitionDuration: Motion.sheet,
          pageBuilder: (_, _, _) => _FullScreenPhoto(path: path),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
