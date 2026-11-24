import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's Light / Dark / System theme preference.
class ThemeCubit extends Cubit<ThemeMode> {
  static const _key = 'settings.themeMode';

  ThemeCubit() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == 'light') emit(ThemeMode.light);
      if (raw == 'dark') emit(ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}
