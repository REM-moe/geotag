import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/settings/app_info.dart';

/// User preferences that affect capture, read from Settings' keys.
/// Call [reload] when the Capture tab mounts (Settings lives on another tab).
abstract final class CapturePrefs {
  static bool haptics = true;
  static bool saveOriginal = false;

  static Future<void> reload() async {
    try {
      final p = await SharedPreferences.getInstance();
      haptics = p.getBool(SettingsKeys.haptics) ?? true;
      saveOriginal = p.getBool(SettingsKeys.saveOriginal) ?? false;
    } catch (_) {}
  }
}

/// Haptics that respect the Settings toggle.
abstract final class Haptics {
  static void selection() {
    if (CapturePrefs.haptics) HapticFeedback.selectionClick();
  }

  static void shutter() {
    if (CapturePrefs.haptics) HapticFeedback.mediumImpact();
  }

  static void light() {
    if (CapturePrefs.haptics) HapticFeedback.lightImpact();
  }
}
