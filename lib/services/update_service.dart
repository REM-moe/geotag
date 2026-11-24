import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Non-blocking Google Play In-App Update helper (Android release builds only).
///
/// Downloads flexible updates in the background and returns `true` when an
/// update is ready to install so the UI can offer a one-tap restart.
/// Silent no-op on iOS, debug builds, and non-Play installs.
class UpdateService {
  static Future<bool> checkFlexibleUpdate() async {
    if (!Platform.isAndroid || !kReleaseMode) return false;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (!info.flexibleUpdateAllowed) return false;
      final result = await InAppUpdate.startFlexibleUpdate();
      return result == AppUpdateResult.success;
    } catch (_) {
      // Expected on sideloaded / non-Play devices or offline.
      return false;
    }
  }

  static Future<void> completeUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }
}
