import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';

/// Panel del director para autorizar el dispositivo de cada empleado y revisar
/// anomalías de vinculación. Solo el director llega aquí (entrada de menú en la
/// sección de asistencia del director).
class AttendanceDevicesScreen extends StatefulWidget {
  const AttendanceDevicesScreen({super.key});

  @override
  State<AttendanceDevicesScreen> createState() => _AttendanceDevicesScreenState();
}

class _AttendanceDevicesScreenState extends State<AttendanceDevicesScreen> {
  late Future<_DevicesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DevicesData> _load() async {
    final requests = await AttendanceApi.adminDeviceRequests();
    final trusted = await AttendanceApi.adminTrustedDevices();
    final anomalies = await AttendanceApi.adminDeviceAnomalies();
    return _DevicesData(requests, trusted, anomalies);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _resolve(DeviceRequestRow row, {required bool approve}) async {
    if (approve) {
      final ok = await showAppConfirmDialog(
        context,
        title: 'Autorizar dispositivo',
        message:
            'Esto reemplazará el dispositivo actual de ${row.employeeName}. '
            'Solo podrá fichar desde el dispositivo nuevo (${row.model ?? row.platform}).',
        confirmLabel: 'Autorizar',
      );
      if (ok != true) return;
    }
    String? note;
    if (!approve) {
      final result = await _askNote();
      if (result == null) return;
      note = result.isEmpty ? null : result;
    }
    try {
      await AttendanceApi.resolveDeviceRequest(row.id, approve: approve, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Dispositivo autorizado.' : 'Solicitud rechazada.'),
      ));
      _reload();
    } on AttendanceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Devuelve el texto (recortado) de la nota, cadena vacía si no se escribió
  /// nada, o `null` si el director canceló el rechazo.
  Future<String?> _askNote() async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Motivo del rechazo (opcional)'),
          content: TextField(controller: ctrl, maxLength: 255, maxLines: 3),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  /// Desvincula el dispositivo de un empleado: su próximo fichaje vinculará el
  /// que use en ese momento (trust-on-first-use).
  Future<void> _resetDevice(TrustedDeviceRow row) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Restablecer dispositivo',
      message: 'Se desvinculará el dispositivo de ${row.employeeName}. '
          'Su próximo registro vinculará el dispositivo que use.',
      confirmLabel: 'Restablecer',
    );
    if (ok != true) return;
    try {
      await AttendanceApi.adminResetEmployeeDevice(row.employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo restablecido.')),
      );
      _reload();
    } on AttendanceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Dispositivos de asistencia'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Solicitudes'),
            Tab(text: 'Dispositivos'),
            Tab(text: 'Anomalías'),
          ]),
        ),
        body: FutureBuilder<_DevicesData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LoadingState();
            }
            if (snap.hasError) {
              return ErrorState(
                message: 'No se pudo cargar. ${snap.error}',
                onRetry: _reload,
              );
            }
            final data = snap.data!;
            return TabBarView(children: [
              _RequestsTab(rows: data.requests, onResolve: _resolve, onRefresh: _reload),
              _TrustedTab(rows: data.trusted, onReset: _resetDevice, onRefresh: _reload),
              _AnomaliesTab(items: data.anomalies),
            ]);
          },
        ),
      ),
    );
  }
}

class _DevicesData {
  const _DevicesData(this.requests, this.trusted, this.anomalies);
  final List<DeviceRequestRow> requests;
  final List<TrustedDeviceRow> trusted;
  final List<DeviceAnomaly> anomalies;
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.rows,
    required this.onResolve,
    required this.onRefresh,
  });

  final List<DeviceRequestRow> rows;
  final void Function(DeviceRequestRow, {required bool approve}) onResolve;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No hay solicitudes pendientes.'));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, i) => DeviceRequestCard(
          row: rows[i],
          onApprove: () => onResolve(rows[i], approve: true),
          onReject: () => onResolve(rows[i], approve: false),
        ),
      ),
    );
  }
}

/// Tarjeta de una solicitud de autorización de dispositivo pendiente.
class DeviceRequestCard extends StatelessWidget {
  const DeviceRequestCard({
    super.key,
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  final DeviceRequestRow row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.employeeName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${row.model ?? 'Dispositivo'} · ${row.osVersion ?? row.platform}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('${row.attempts} intento(s) · última vez ${row.lastSeen}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onReject, child: const Text('Rechazar')),
                const SizedBox(width: 8),
                TextButton(onPressed: onApprove, child: const Text('Aprobar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustedTab extends StatelessWidget {
  const _TrustedTab({
    required this.rows,
    required this.onReset,
    required this.onRefresh,
  });

  final List<TrustedDeviceRow> rows;
  final void Function(TrustedDeviceRow) onReset;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('Ningún empleado tiene un dispositivo vinculado todavía.'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, i) => TrustedDeviceCard(
          row: rows[i],
          onReset: () => onReset(rows[i]),
        ),
      ),
    );
  }
}

/// Tarjeta del dispositivo vinculado de un empleado, con la acción de
/// restablecer (desvincular) que solo puede ejecutar el director.
class TrustedDeviceCard extends StatelessWidget {
  const TrustedDeviceCard({super.key, required this.row, required this.onReset});

  final TrustedDeviceRow row;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final via = row.via == 'director' ? 'aprobado por el director' : 'primer uso';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.employeeName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${row.model ?? 'Dispositivo'} · ${row.osVersion ?? row.platform ?? ''}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Vinculado ${row.enrolledAt} · $via',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onReset, child: const Text('Restablecer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomaliesTab extends StatelessWidget {
  const _AnomaliesTab({required this.items});
  final List<DeviceAnomaly> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sin anomalías en los últimos 30 días.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => AnomalyTile(anomaly: items[i]),
    );
  }
}

/// Fila de una anomalía de dispositivo, con el tipo traducido a español.
class AnomalyTile extends StatelessWidget {
  const AnomalyTile({super.key, required this.anomaly});
  final DeviceAnomaly anomaly;

  static const _labels = {
    'unknown_device_attempt': 'Intento desde dispositivo no autorizado',
    'first_use_after_history': 'Primer uso con historial de otro dispositivo',
    'frequent_device_change': 'Cambios frecuentes de dispositivo',
    'biometric_skipped_streak': 'Verificación por PIN varios días seguidos',
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.report_gmailerrorred_outlined),
      title: Text(_labels[anomaly.type] ?? anomaly.type),
      subtitle: Text('${anomaly.employeeName} · ${anomaly.detail}'),
    );
  }
}
