import 'package:intl/intl.dart';

import '../../data/capture.dart';

/// Formatting helpers shared by Library, Map, Notes and Detail.
abstract final class CaptureFormat {
  /// "Today", "Yesterday", "24 Nov" or "24 Nov 2025" (other years).
  static String dayLabel(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (t.year == n.year) return DateFormat('d MMM').format(t);
    return DateFormat('d MMM y').format(t);
  }

  static String time(DateTime t) => DateFormat('HH:mm').format(t);

  /// "Today · 09:12"
  static String when(DateTime t) => '${dayLabel(t)} · ${time(t)}';

  /// Searchable date strings: "24 Nov", "November 24 2025", "2025-11-24".
  static String searchableDate(DateTime t) =>
      '${dayLabel(t)} ${DateFormat('d MMM MMMM y').format(t)} ${DateFormat('yyyy-MM-dd').format(t)}';

  static String place(Capture c) {
    final p = c.place?.trim();
    if (p != null && p.isNotEmpty) return p;
    if (c.hasLocation) return 'Unnamed place';
    return 'No location';
  }

  /// "46.6943° N, 12.0858° E" or "—".
  static String coords(Capture c) {
    if (!c.hasLocation) return '—';
    return '${_lat(c.latitude!)}, ${_lng(c.longitude!)}';
  }

  static String _lat(double v) => '${v.abs().toStringAsFixed(4)}° ${v >= 0 ? 'N' : 'S'}';
  static String _lng(double v) => '${v.abs().toStringAsFixed(4)}° ${v >= 0 ? 'E' : 'W'}';

  static String altitude(Capture c) =>
      c.altitudeMetres == null ? '—' : '${c.altitudeMetres!.round()} m';

  static String heading(Capture c) {
    final h = c.headingDegrees;
    if (h == null) return '—';
    final norm = (h % 360 + 360) % 360;
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return '${norm.round()}° ${dirs[((norm + 22.5) ~/ 45) % 8]}';
  }

  static String accuracy(Capture c) =>
      c.accuracyMetres == null ? '—' : '±${c.accuracyMetres!.round()} m';

  /// "0:24", "12:05", "1:02:03".
  static String duration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  static String type(Capture c) {
    if (!c.isVideo) return 'Photo';
    final d = duration(c.videoDuration);
    return d.isEmpty ? 'Video' : 'Video · $d';
  }

  /// "120 m" / "1.4 km" / "32 km".
  static String distance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    final km = metres / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }
}
