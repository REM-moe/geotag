import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/templates.dart';

/// Persisted stamp configuration (template, surface, visible fields).
class TemplateCubit extends Cubit<StampConfig> {
  static const _kTemplate = 'geotag.stamp.template';
  static const _kSurface = 'geotag.stamp.surface';
  static const _kMap = 'geotag.stamp.map';
  static const _kCoords = 'geotag.stamp.coords';
  static const _kAlt = 'geotag.stamp.altHeading';

  TemplateCubit() : super(const StampConfig()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
          values.firstWhere((v) => v.name == name, orElse: () => fallback);
      if (isClosed) return;
      emit(StampConfig(
        template: pick(TemplateId.values, p.getString(_kTemplate), state.template),
        surface: pick(StampSurface.values, p.getString(_kSurface), state.surface),
        showMap: p.getBool(_kMap) ?? state.showMap,
        showCoords: p.getBool(_kCoords) ?? state.showCoords,
        showAltHeading: p.getBool(_kAlt) ?? state.showAltHeading,
      ));
    } catch (_) {/* defaults already emitted */}
  }

  Future<void> _save(StampConfig c) async {
    emit(c);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kTemplate, c.template.name);
      await p.setString(_kSurface, c.surface.name);
      await p.setBool(_kMap, c.showMap);
      await p.setBool(_kCoords, c.showCoords);
      await p.setBool(_kAlt, c.showAltHeading);
    } catch (_) {}
  }

  Future<void> select(TemplateId id) => _save(state.copyWith(template: id));
  Future<void> setSurface(StampSurface s) => _save(state.copyWith(surface: s));
  Future<void> toggleMap() => _save(state.copyWith(showMap: !state.showMap));
  Future<void> toggleCoords() => _save(state.copyWith(showCoords: !state.showCoords));
  Future<void> toggleAltHeading() => _save(state.copyWith(showAltHeading: !state.showAltHeading));
}
