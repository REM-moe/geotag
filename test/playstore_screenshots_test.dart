import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/cubits/permission_cubit.dart';
import 'package:geotag/cubits/template_cubit.dart';
import 'package:geotag/data/capture.dart';
import 'package:geotag/data/capture_repository.dart';
import 'package:geotag/screens/camera/stamp_studio_sheet.dart';
import 'package:geotag/screens/library/library_screen.dart';
import 'package:geotag/screens/notes/notes_screen.dart';
import 'package:geotag/screens/settings/settings_screen.dart';
import 'package:geotag/shell/tab_cubit.dart';
import 'package:geotag/templates/templates.dart';
import 'package:geotag/theme/app_theme.dart';
import 'package:geotag/theme/theme_cubit.dart';
import 'package:geotag/theme/tokens.dart';
import 'package:geotag/widgets/glass.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String dir;
  _FakePathProvider(this.dir);
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
}

class _RealPermCubit extends PermissionCubit {
  _RealPermCubit() : super() {
    emit(const PermissionState(
      camera: PermStatus.granted,
      microphone: PermStatus.granted,
      location: PermStatus.granted,
      locationServiceEnabled: true,
      preciseLocation: true,
    ));
  }
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!await file.exists()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late CaptureRepository repo;
  final demoFiles = <File>[];

  setUpAll(() async {
    kUseLocalTestFonts = true;
    SharedPreferences.setMockInitialValues({});

    // Load real fonts so goldens render crisp typography & icons (not Ahem boxes).
    const figtree = '/tmp/geotag_fonts/Figtree.ttf';
    const mono = '/tmp/geotag_fonts/JetBrainsMono.ttf';
    const matIcons = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

    for (final f in ['Figtree', 'Figtree_regular', 'Figtree_500', 'Figtree_600', 'Figtree_700', 'Roboto']) {
      await _loadFont(f, figtree);
    }
    for (final f in ['JetBrainsMono', 'JetBrainsMono_regular', 'JetBrainsMono_500', 'JetBrainsMono_600']) {
      await _loadFont(f, mono);
    }
    await _loadFont('MaterialIcons', matIcons);

    tmpDir = await Directory.systemTemp.createTemp('geotag_playstore_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
    repo = await CaptureRepository.open();

    final now = DateTime(2026, 11, 24, 9, 41);
    final samples = [
      ('lake.jpg', 'Lago di Braies', 'South Tyrol, Italy', 46.6943, 12.0858, 1496.0, 312.0, now, 'Boat rental opens 8:30 — shoot before the crowds.'),
      ('peak.jpg', 'Seceda Ridge', 'Val Gardena, Italy', 46.6008, 11.7230, 2519.0, 48.0, now.subtract(const Duration(hours: 1)), 'Ridge trail starts 200 m east of the lift.'),
      ('hills.jpg', 'Alpe di Siusi', 'South Tyrol, Italy', 46.5402, 11.6229, 1844.0, 96.0, now.subtract(const Duration(hours: 2)), 'Sunrise point — park at Compatsch, 20 min walk.'),
      ('city.jpg', 'Bolzano Centre', 'South Tyrol, Italy', 46.4983, 11.3548, 262.0, 12.0, now.subtract(const Duration(days: 1)), 'Site visit #2 — facade lighting checked.'),
      ('lake.jpg', 'Passo Giau', 'Belluno, Italy', 46.4828, 12.0539, 2236.0, 64.0, now.subtract(const Duration(days: 1, hours: 3)), ''),
      ('peak.jpg', 'Tre Cime Overlook', 'Dolomites, Italy', 46.6187, 12.3028, 2454.0, 140.0, now.subtract(const Duration(days: 1, hours: 5)), ''),
    ];

    for (final s in samples) {
      final src = File('/tmp/geotag_demo_photos/${s.$1}');
      final alloc = repo.allocate(CaptureKind.photo);
      final mediaFile = await src.copy(alloc.mediaPath);
      final thumbFile = await src.copy(alloc.thumbPath);
      demoFiles.addAll([src, mediaFile, thumbFile]);
      await repo.add(Capture(
        id: alloc.id,
        kind: CaptureKind.photo,
        filePath: alloc.mediaPath,
        thumbPath: alloc.thumbPath,
        takenAt: s.$8,
        latitude: s.$4,
        longitude: s.$5,
        altitudeMetres: s.$6,
        headingDegrees: s.$7,
        accuracyMetres: 4.0,
        place: s.$2,
        address: s.$3,
        note: s.$9,
      ));
    }
  });

  tearDownAll(() async {
    await repo.dispose();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  Widget wrapProviders(Widget child, {Brightness brightness = Brightness.light, StampConfig? stamp}) {
    final tpl = TemplateCubit();
    if (stamp != null) tpl.emit(stamp);
    final themeCubit = ThemeCubit();
    themeCubit.emit(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);

    return RepositoryProvider.value(
      value: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<PermissionCubit>(create: (_) => _RealPermCubit()),
          BlocProvider(create: (_) => TabCubit()),
          BlocProvider<TemplateCubit>.value(value: tpl),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(brightness),
          home: child,
        ),
      ),
    );
  }

  Future<void> renderPoster(
    WidgetTester tester, {
    required String filename,
    required String headline,
    required String subtitle,
    required bool darkBackdrop,
    required Widget phoneScreen,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final bg = darkBackdrop ? const Color(0xFF0B0B0C) : const Color(0xFFF4F4F5);
    final fg = darkBackdrop ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
    final sub = darkBackdrop ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);

    // Pre-decode all demo FileImages into PaintingBinding.imageCache inside
    // runAsync BEFORE mounting the real screen so Image.file paints on frame 1.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(SizedBox));
      for (final f in demoFiles) {
        if (await f.exists()) {
          final base = FileImage(f);
          await precacheImage(base, ctx);
          await precacheImage(ResizeImage(base, width: 320), ctx);
          await precacheImage(ResizeImage(base, width: 120), ctx);
          await precacheImage(ResizeImage(base, width: 160), ctx);
        }
      }
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: Container(
            width: 540,
            height: 960,
            color: bg,
            padding: const EdgeInsets.fromLTRB(36, 56, 36, 0),
            child: Column(
              children: [
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    color: fg,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: sub,
                    height: 1.35,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 36),
                Expanded(
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161618),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(46)),
                      border: Border.all(
                        color: darkBackdrop ? const Color(0xFF2E2E32) : const Color(0xFFD4D4D8),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                      child: MediaQuery(
                        data: const MediaQueryData(
                          size: Size(380, 760),
                          padding: EdgeInsets.only(top: 18, bottom: 16),
                          devicePixelRatio: 2.0,
                        ),
                        child: phoneScreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('../playstore-assets/$filename'),
    );
  }

  Widget mockCameraPhone({required bool showStudio, required StampConfig config}) {
    final sampleData = StampData(
      hasLocation: true,
      place: 'Lago di Braies',
      area: 'South Tyrol, Italy',
      latitude: 46.6943,
      longitude: 12.0858,
      altitude: 1496,
      heading: 312,
      time: DateTime(2026, 11, 24, 9, 41),
      note: showStudio ? '' : 'Boat rental opens 8:30 — shoot early.',
    );

    return wrapProviders(
      brightness: Brightness.dark,
      stamp: config,
      Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File('/tmp/geotag_demo_photos/lake.jpg'), fit: BoxFit.cover),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 26,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Glass(
                        borderRadius: BorderRadius.circular(999),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.flash_off_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Glass(
                        borderRadius: BorderRadius.circular(999),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.grid_3x3_rounded, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                  Glass(
                    borderRadius: BorderRadius.circular(999),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.dashboard_customize_outlined, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (!showStudio)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StampView(config: config, data: sampleData, liveMap: false),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File('/tmp/geotag_demo_photos/peak.jpg'),
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          ),
                        ),
                        Glass(
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.cameraswitch_outlined, size: 22, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (showStudio) ...[
              Positioned(
                left: 16,
                right: 16,
                bottom: 342,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Glass(
                      borderRadius: BorderRadius.circular(999),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 6,
                            height: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF30D158)),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text('Live preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        boxShadow: const [BoxShadow(color: Color(0xFF4C8DFF), spreadRadius: 2)],
                      ),
                      child: StampView(config: config, data: sampleData, liveMap: false),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: GeoColors.dark.bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                    border: Border(top: BorderSide(color: GeoColors.dark.border)),
                  ),
                  child: const StampStudioSheet(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  testWidgets('1. Camera screen (real StampView)', (tester) async {
    await renderPoster(
      tester,
      filename: 'screenshot-1-camera.png',
      headline: 'Stamp every shot.',
      subtitle: 'Live GPS coordinates, altitude & satellite mini map.',
      darkBackdrop: false,
      phoneScreen: mockCameraPhone(showStudio: false, config: const StampConfig()),
    );
  });

  testWidgets('2. Live Stamp Studio (real StampStudioSheet)', (tester) async {
    await renderPoster(
      tester,
      filename: 'screenshot-2-stamps.png',
      headline: 'Live Stamp Studio.',
      subtitle: 'Switch layouts & styles right over your viewfinder.',
      darkBackdrop: true,
      phoneScreen: mockCameraPhone(
        showStudio: true,
        config: const StampConfig(template: TemplateId.survey),
      ),
    );
  });

  testWidgets('3. Library screen (real LibraryScreen light)', (tester) async {
    await renderPoster(
      tester,
      filename: 'screenshot-3-library.png',
      headline: 'Built-in photo vault.',
      subtitle: 'Search by place, filter notes & browse by date.',
      darkBackdrop: false,
      phoneScreen: wrapProviders(const Scaffold(body: LibraryScreen()), brightness: Brightness.light),
    );
  });

  testWidgets('4. Notes screen (real NotesScreen light)', (tester) async {
    await renderPoster(
      tester,
      filename: 'screenshot-4-notes.png',
      headline: 'Location-based notes.',
      subtitle: 'Remember details tied to every exact spot.',
      darkBackdrop: false,
      phoneScreen: wrapProviders(const Scaffold(body: NotesScreen()), brightness: Brightness.light),
    );
  });

  testWidgets('5. Settings & Dark Theme (real SettingsScreen dark)', (tester) async {
    await renderPoster(
      tester,
      filename: 'screenshot-5-settings.png',
      headline: 'Zero permission nagging.',
      subtitle: 'Light & Dark themes. Permissions only when needed.',
      darkBackdrop: true,
      phoneScreen: wrapProviders(const Scaffold(body: SettingsScreen()), brightness: Brightness.dark),
    );
  });
}
