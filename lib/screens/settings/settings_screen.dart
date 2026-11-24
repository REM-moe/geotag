import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../cubits/permission_cubit.dart';
import '../../shell/tab_cubit.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/ui.dart';
import '../library/captures_builder.dart';
import 'app_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  bool _saveOriginal = false;
  bool _haptics = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _saveOriginal = p.getBool(SettingsKeys.saveOriginal) ?? false;
        _haptics = p.getBool(SettingsKeys.haptics) ?? true;
      });
    });
  }

  void _setSaveOriginal(bool v) {
    setState(() => _saveOriginal = v);
    _prefs?.setBool(SettingsKeys.saveOriginal, v);
  }

  void _setHaptics(bool v) {
    setState(() => _haptics = v);
    _prefs?.setBool(SettingsKeys.haptics, v);
  }

  Future<void> _openPrivacy() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(AppInfo.privacyPolicyUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) showGeoToast(context, 'Couldn\'t open the browser', success: false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.geo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GeoPageHeader(title: 'Settings', subtitle: 'Permissions are asked only when needed'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s8),
            children: [
              const GeoSectionLabel('Permissions'),
              const _PermissionsGroup(),
              const SizedBox(height: Space.s4),
              const GeoSectionLabel('Storage'),
              CapturesBuilder(
                builder: (context, items) => GeoListGroup(children: [
                  GeoListRow(
                    icon: Icons.smartphone_outlined,
                    title: 'Saved on this phone',
                    subtitle: 'Photos also go to your Gallery app',
                    trailing: Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: monoStyle(size: TextSize.xs, color: g.text2),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: Space.s4),
              const GeoSectionLabel('Capture'),
              GeoListGroup(children: [
                GeoListRow(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Default stamp',
                  subtitle: 'Choose a stamp on the camera screen',
                  chevron: true,
                  onTap: () => context.read<TabCubit>().go(AppTab.capture),
                ),
                GeoListRow(
                  icon: Icons.photo_outlined,
                  title: 'Also save original',
                  subtitle: 'Keep an unstamped copy',
                  trailing: GeoSwitch(value: _saveOriginal, onChanged: _setSaveOriginal),
                  onTap: () => _setSaveOriginal(!_saveOriginal),
                ),
                GeoListRow(
                  icon: Icons.music_note_outlined,
                  title: 'Shutter sound & haptics',
                  trailing: GeoSwitch(value: _haptics, onChanged: _setHaptics),
                  onTap: () => _setHaptics(!_haptics),
                ),
              ]),
              const SizedBox(height: Space.s4),
              const GeoSectionLabel('About'),
              GeoListGroup(children: [
                GeoListRow(title: 'Privacy policy', chevron: true, onTap: _openPrivacy),
                GeoListRow(
                  title: 'Version',
                  trailing: Text(AppInfo.version, style: monoStyle(size: TextSize.xs, color: g.text2)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionsGroup extends StatelessWidget {
  const _PermissionsGroup();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<PermissionCubit>().state;
    final cubit = context.read<PermissionCubit>();

    final String locationSub;
    if (!s.location.isGranted) {
      locationSub = 'Photos save without place';
    } else if (!s.locationServiceEnabled) {
      locationSub = 'Allowed · GPS is off';
    } else if (!s.preciseLocation) {
      locationSub = 'Approximate · while using app';
    } else {
      locationSub = 'Precise · while using app';
    }

    Widget locationTrailing;
    VoidCallback? locationTap;
    if (s.location.isGranted && !s.locationServiceEnabled) {
      locationTrailing = const GeoBadge.warning('GPS off');
      locationTap = cubit.openLocationSettings;
    } else if (s.location.isGranted && !s.preciseLocation) {
      locationTrailing = const GeoBadge.warning('Approximate');
      locationTap = cubit.openSettings;
    } else {
      locationTrailing = _permTrailing(s.location, cubit.ensureLocation, s.loaded);
    }

    return GeoListGroup(children: [
      GeoListRow(
        icon: Icons.photo_camera_outlined,
        title: 'Camera',
        subtitle: 'Needed to take photos',
        trailing: _permTrailing(s.camera, cubit.ensureCamera, s.loaded),
      ),
      GeoListRow(
        icon: Icons.location_on_outlined,
        title: 'Location',
        subtitle: locationSub,
        trailing: locationTrailing,
        onTap: locationTap,
      ),
      GeoListRow(
        icon: Icons.mic_none_rounded,
        title: 'Microphone',
        subtitle: 'Only for video sound',
        trailing: _permTrailing(s.microphone, cubit.ensureMicrophone, s.loaded),
      ),
      GeoListRow(
        icon: Icons.photo_library_outlined,
        title: 'Save to Photos',
        subtitle: Platform.isIOS ? 'Add-only access, asked on first save' : 'No access needed on Android 10+',
        trailing: const GeoBadge.positive('Not required'),
      ),
    ]);
  }

  Widget _permTrailing(PermStatus status, Future<bool> Function() ensure, bool loaded) {
    if (!loaded) return const SizedBox.shrink();
    if (status.isGranted) return const GeoBadge.positive('Allowed');
    return GeoButton(
      label: status.needsSettings ? 'Open Settings' : 'Allow',
      variant: GeoButtonVariant.secondary,
      size: GeoButtonSize.sm,
      onPressed: ensure,
    );
  }
}
