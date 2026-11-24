import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../cubits/permission_cubit.dart';
import '../screens/camera_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'tab_cubit.dart';

/// Root scaffold: 5 tabs. Capture tab is always-dark camera chrome; the rest
/// follow the system theme. The camera is only mounted while its tab is
/// selected so the hardware is released elsewhere.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final perms = context.read<PermissionCubit>();
    perms.refresh();
    Geolocator.getServiceStatusStream().listen(
      (s) => perms.setLocationServiceEnabled(s == ServiceStatus.enabled),
      onError: (_) {},
    );
    _checkPlayUpdate();
  }

  Future<void> _checkPlayUpdate() async {
    final ready = await UpdateService.checkFlexibleUpdate();
    if (!ready || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Update downloaded and ready to install'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Restart',
          onPressed: UpdateService.completeUpdate,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Returning from system Settings must update permission UI immediately.
    if (s == AppLifecycleState.resumed) context.read<PermissionCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<TabCubit>().state;
    final onCamera = tab == AppTab.capture;

    Widget body;
    switch (tab) {
      case AppTab.capture:
        body = const CameraScreen();
      case AppTab.library:
        body = const LibraryScreen();
      case AppTab.map:
        body = const MapScreen();
      case AppTab.notes:
        body = const NotesScreen();
      case AppTab.settings:
        body = const SettingsScreen();
    }

    final shell = Scaffold(
      body: body,
      bottomNavigationBar: _TabBar(current: tab, dark: onCamera),
    );

    final overlay = onCamera || Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: onCamera ? Theme(data: buildTheme(Brightness.dark), child: shell) : shell,
    );
  }
}

class _TabBar extends StatelessWidget {
  final AppTab current;
  final bool dark;
  const _TabBar({required this.current, required this.dark});

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    final bg = dark ? Colors.black : g.bg;
    final border = dark ? const Color(0xFF1C1C1E) : g.border;
    final on = dark ? Colors.white : g.text;
    final off = dark ? const Color(0xFF6B6B70) : g.text3;

    Widget item(AppTab t, IconData icon, String label) {
      final sel = t == current;
      return Expanded(
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<TabCubit>().go(t);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: sel ? on : off),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sel ? on : off)),
            ],
          ),
        ),
      );
    }

    final captureSel = current == AppTab.capture;
    return Container(
      decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: InkResponse(
                  onTap: () => context.read<TabCubit>().go(AppTab.capture),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: captureSel ? on : off, width: 2),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: captureSel ? on : off),
                      ),
                    ),
                  ),
                ),
              ),
              item(AppTab.library, Icons.photo_library_outlined, 'Library'),
              item(AppTab.map, Icons.map_outlined, 'Map'),
              item(AppTab.notes, Icons.edit_note_rounded, 'Notes'),
              item(AppTab.settings, Icons.tune_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
