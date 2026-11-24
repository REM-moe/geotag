import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../data/capture.dart';

/// Opens external map apps for a capture's coordinates.
abstract final class MapsLauncher {
  /// Shows the spot in the platform maps app. Returns false if nothing
  /// could be opened.
  static Future<bool> open(Capture c) async {
    if (!c.hasLocation) return false;
    final lat = c.latitude!, lng = c.longitude!;
    final label = Uri.encodeComponent(c.place ?? 'Geotag photo');
    final candidates = <Uri>[
      if (Platform.isAndroid) Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)'),
      if (Platform.isIOS) Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$label'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    ];
    return _tryAll(candidates);
  }

  /// Opens turn-by-turn directions to the spot.
  static Future<bool> directions(Capture c) async {
    if (!c.hasLocation) return false;
    final lat = c.latitude!, lng = c.longitude!;
    final candidates = <Uri>[
      if (Platform.isAndroid) Uri.parse('google.navigation:q=$lat,$lng'),
      if (Platform.isIOS) Uri.parse('https://maps.apple.com/?daddr=$lat,$lng'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    ];
    return _tryAll(candidates);
  }

  static Future<bool> _tryAll(List<Uri> uris) async {
    for (final u in uris) {
      try {
        if (await launchUrl(u, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {}
    }
    return false;
  }
}
