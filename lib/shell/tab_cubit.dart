import 'package:flutter_bloc/flutter_bloc.dart';

enum AppTab { capture, library, map, notes, settings }

/// Selected bottom tab. Any screen can switch tabs with
/// `context.read<TabCubit>().go(AppTab.library)`.
class TabCubit extends Cubit<AppTab> {
  TabCubit() : super(AppTab.capture);
  void go(AppTab t) => emit(t);
}
