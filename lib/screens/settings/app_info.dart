/// Static app metadata shown in Settings › About.
abstract final class AppInfo {
  /// Keep in sync with `version:` in pubspec.yaml.
  static const version = '0.1.0';

  /// Placeholder until the hosted policy page is live.
  static const privacyPolicyUrl = 'https://melamphic.com/geotag/privacy';
}

/// SharedPreferences keys owned by Settings.
abstract final class SettingsKeys {
  static const saveOriginal = 'settings.saveOriginal';
  static const haptics = 'settings.haptics';
}
