import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubits/permission_cubit.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocBuilder<PermissionCubit, PermissionState>(
          builder: (context, s) {
            final cubit = context.read<PermissionCubit>();
            final needsSettings = s.camera == PermStatus.permanentlyDenied ||
                s.location == PermStatus.permanentlyDenied;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: 0.25),
                              scheme.tertiary.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                      Icon(Icons.center_focus_strong_outlined,
                          size: 70, color: scheme.primary),
                      Positioned(
                        bottom: 18,
                        right: 22,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on,
                              size: 22, color: scheme.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Geotag',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Burn live location, address, and time onto every shot.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  _PermRow(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    status: s.camera,
                  ),
                  const SizedBox(height: 10),
                  _PermRow(
                    icon: Icons.location_searching,
                    label: 'Precise location',
                    status: s.location,
                  ),
                  const SizedBox(height: 10),
                  _PermRow(
                    icon: Icons.mic_none_outlined,
                    label: 'Microphone (video)',
                    status: s.microphone,
                  ),
                  const Spacer(flex: 3),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: s.checking
                        ? null
                        : () => needsSettings ? cubit.openSettingsPage() : cubit.requestAll(),
                    icon: s.checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Icon(needsSettings ? Icons.settings : Icons.lock_open),
                    label: Text(needsSettings ? 'Open Settings' : 'Grant access'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You can change these later in system settings.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final PermStatus status;

  const _PermRow({required this.icon, required this.label, required this.status});

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case PermStatus.granted:
        return scheme.primary;
      case PermStatus.permanentlyDenied:
        return scheme.error;
      case PermStatus.denied:
        return scheme.onSurfaceVariant;
      case PermStatus.unknown:
        return scheme.outlineVariant;
    }
  }

  String _statusText() {
    switch (status) {
      case PermStatus.granted:
        return 'Granted';
      case PermStatus.permanentlyDenied:
        return 'Blocked';
      case PermStatus.denied:
        return 'Needed';
      case PermStatus.unknown:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusText(),
              style: TextStyle(
                color: _statusColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
