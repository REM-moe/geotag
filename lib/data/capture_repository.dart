import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'capture.dart';

/// Local-first store for the in-app Library.
///
/// Layout (inside app documents dir, no storage permission needed),
///   captures/index.json        — list of [Capture] json, newest first
///   captures/ID.jpg or .mp4    — stamped media
///   captures/ID_thumb.jpg      — thumbnail
///
/// Single instance, created in `main.dart` and provided via
/// `RepositoryProvider<CaptureRepository>`.
class CaptureRepository {
  CaptureRepository._(this._dir);

  final Directory _dir;
  final _controller = StreamController<List<Capture>>.broadcast();
  List<Capture> _items = const [];
  Future<void> _writeQueue = Future.value();

  static Future<CaptureRepository> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/captures');
    if (!await dir.exists()) await dir.create(recursive: true);
    final repo = CaptureRepository._(dir);
    await repo._load();
    return repo;
  }

  Directory get directory => _dir;
  File get _index => File('${_dir.path}/index.json');

  /// Current snapshot, newest first.
  List<Capture> get items => _items;

  /// Emits the full list on every change. Listen and combine with [items]
  /// for the initial value.
  Stream<List<Capture>> get changes => _controller.stream;

  Capture? byId(String id) {
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Generates a new id and the destination paths for a capture's files.
  ({String id, String mediaPath, String thumbPath}) allocate(CaptureKind kind) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ext = kind == CaptureKind.video ? 'mp4' : 'jpg';
    return (
      id: id,
      mediaPath: '${_dir.path}/$id.$ext',
      thumbPath: '${_dir.path}/${id}_thumb.jpg',
    );
  }

  Future<void> add(Capture c) async {
    _items = [c, ..._items];
    _emit();
    await _persist();
  }

  Future<void> updateNote(String id, String note) async {
    _items = [for (final c in _items) c.id == id ? c.copyWith(note: note.trim()) : c];
    _emit();
    await _persist();
  }

  Future<void> delete(String id) async {
    final c = byId(id);
    if (c == null) return;
    _items = _items.where((e) => e.id != id).toList();
    _emit();
    await _persist();
    for (final p in [c.filePath, c.thumbPath]) {
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    try {
      if (!await _index.exists()) return;
      final raw = jsonDecode(await _index.readAsString()) as List<dynamic>;
      _items = raw
          .map((e) => Capture.fromJson(e as Map<String, dynamic>))
          .where((c) => File(c.filePath).existsSync())
          .toList();
    } catch (_) {
      _items = const [];
    }
  }

  void _emit() => _controller.add(List.unmodifiable(_items));

  Future<void> _persist() {
    _writeQueue = _writeQueue.then((_) async {
      final tmp = File('${_index.path}.tmp');
      await tmp.writeAsString(jsonEncode(_items.map((c) => c.toJson()).toList()));
      await tmp.rename(_index.path);
    }).catchError((_) {});
    return _writeQueue;
  }

  Future<void> dispose() => _controller.close();
}
