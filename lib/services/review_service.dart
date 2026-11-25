import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-blocking Google Play / App Store In-App Review helper.
///
/// Counts successful captures and gently requests the native review sheet
/// once the user has saved their 3rd geotagged photo/video (and at most once
/// every 90 days thereafter). Silent no-op on debug builds or unsupported
/// devices; Google Play enforces its own rate-limiting quota on top.
class ReviewService {
  static const _kCaptureCount = 'review_capture_count';
  static const _kLastPromptMs = 'review_last_prompt_ms';
  static const _minCaptures = 3;
  static const _cooldown = Duration(days: 90);

  static Future<void> recordCaptureAndMaybePrompt() async {
    if (!(Platform.isAndroid || Platform.isIOS) || !kReleaseMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kCaptureCount) ?? 0) + 1;
      await prefs.setInt(_kCaptureCount, count);
      if (count < _minCaptures) return;

      final lastMs = prefs.getInt(_kLastPromptMs);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastMs != null && now - lastMs < _cooldown.inMilliseconds) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await prefs.setInt(_kLastPromptMs, now);
      await review.requestReview();
    } catch (_) {
      // Expected on sideloaded / non-Play devices.
    }
  }
}
