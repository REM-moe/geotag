import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubits/camera_cubit.dart';
import 'cubits/location_overlay_cubit.dart';
import 'cubits/permission_cubit.dart';
import 'cubits/template_cubit.dart';
import 'data/capture_repository.dart';
import 'shell/app_shell.dart';
import 'shell/tab_cubit.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

class GeotagApp extends StatelessWidget {
  final CaptureRepository captures;
  const GeotagApp({super.key, required this.captures});

  @override
  Widget build(BuildContext context) {
    // Providers sit above MaterialApp so pushed routes can read them.
    return RepositoryProvider.value(
      value: captures,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => PermissionCubit()),
          BlocProvider(create: (_) => TabCubit()),
          BlocProvider(create: (_) => CameraCubit()),
          BlocProvider(create: (_) => LocationOverlayCubit()),
          BlocProvider(create: (_) => TemplateCubit()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            title: 'Geotag: GPS Map Camera',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            // No permission wall: the app always opens straight into the shell.
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}
