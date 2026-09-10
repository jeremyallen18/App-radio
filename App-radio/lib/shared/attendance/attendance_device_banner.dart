import 'package:flutter/material.dart';

import 'package:doliv_social/models/attendance.dart';

/// Aviso sobre el estado del dispositivo encima de los botones de fichaje.
/// No renderiza nada cuando el dispositivo es de confianza.
class AttendanceDeviceBanner extends StatelessWidget {
  const AttendanceDeviceBanner({
    super.key,
    required this.state,
    required this.onRequest,
  });

  final AttendanceDeviceState state;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (state) {
      case AttendanceDeviceState.trusted:
        return const SizedBox.shrink();

      case AttendanceDeviceState.none:
        return _box(
          context,
          icon: Icons.link,
          color: scheme.surfaceContainerHighest,
          child: Text(
            'Este dispositivo se vinculará a tu cuenta la primera vez que fiches.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

      case AttendanceDeviceState.pending:
        return _box(
          context,
          icon: Icons.hourglass_top,
          color: scheme.secondaryContainer,
          child: Text(
            'Esperando que el director autorice este dispositivo. No podrás fichar hasta entonces.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

      case AttendanceDeviceState.unknown:
        return _box(
          context,
          icon: Icons.gpp_maybe,
          color: scheme.errorContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este dispositivo no está autorizado para registrar tu asistencia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onRequest,
                child: const Text('Solicitar autorización del dispositivo'),
              ),
            ],
          ),
        );
    }
  }

  Widget _box(BuildContext context,
      {required IconData icon, required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
