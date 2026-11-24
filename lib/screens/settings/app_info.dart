/// Static app metadata shown in Settings › About.
abstract final class AppInfo {
  /// Keep in sync with `version:` in pubspec.yaml.
  static const version = '2.0.0';

  static const privacyPolicyUrl = 'https://hellosalvia.com/geotag/privacy';
}

/// SharedPreferences keys owned by Settings.
abstract final class SettingsKeys {
  static const saveOriginal = 'settings.saveOriginal';
  static const haptics = 'settings.haptics';
}
