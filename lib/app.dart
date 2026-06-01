import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cubits/camera_cubit.dart';
import 'cubits/location_overlay_cubit.dart';
import 'cubits/permission_cubit.dart';
import 'cubits/template_cubit.dart';
import 'screens/camera_screen.dart';
import 'screens/permission_screen.dart';

class GeotagApp extends StatelessWidget {
  const GeotagApp({super.key});

  static const _seed = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    // Cubits are hoisted ABOVE MaterialApp so pushed routes (e.g. the template
    // picker) can still find them — providers placed in `home:` are scoped to
    // that route only and pushed Navigator routes can't see them.
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PermissionCubit()..refresh()),
        BlocProvider(create: (_) => CameraCubit()),
        BlocProvider(create: (_) => LocationOverlayCubit()),
        BlocProvider(create: (_) => TemplateCubit()),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final light = lightDynamic ?? ColorScheme.fromSeed(seedColor: _seed);
          final dark = darkDynamic ??
              ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);

          return MaterialApp(
            title: 'Geotag: GPS Map Camera',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.system,
            theme: _build(light),
            darkTheme: _build(dark),
            home: const _Root(),
          );
        },
      ),
    );
  }

  ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.poppinsTextTheme(base.primaryTextTheme),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.poppins(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionCubit, PermissionState>(
      builder: (context, s) {
        if (s.cameraAndLocationReady) return const CameraScreen();
        return const PermissionScreen();
      },
    );
  }
}
