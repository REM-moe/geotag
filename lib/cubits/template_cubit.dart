import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/templates.dart';

class TemplateCubit extends Cubit<TemplateId> {
  static const _key = 'geotag.template';

  TemplateCubit() : super(TemplateId.classic) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      if (name == null) return;
      final found = TemplateId.values.firstWhere(
        (t) => t.name == name,
        orElse: () => TemplateId.classic,
      );
      emit(found);
    } catch (_) {/* defaults already emitted */}
  }

  Future<void> select(TemplateId id) async {
    emit(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, id.name);
    } catch (_) {}
  }
}
