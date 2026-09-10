import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/core/api_config.dart';

/// Cubre la app con [OfflineView] cuando el backend no responde. Sondea con el
/// mismo `http` de la app (no un plugin de conectividad) para probar salida real
/// a `kBaseUrl`.
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with WidgetsBindingObserver {
  bool _offline = false;
  bool _checking = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    // Solo reintenta mientras está offline.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_offline) _check();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    if (mounted) setState(() {});

    bool offline;
    try {
      final response = await http
          .get(Uri.parse('$kBaseUrl/'))
          .timeout(const Duration(seconds: 4));
      offline = response.statusCode >= 500;
    } catch (_) {
      offline = true;
    }

    _checking = false;
    if (mounted) setState(() => _offline = offline);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_offline)
          Positioned.fill(
            child: OfflineView(onRetry: _check, retrying: _checking),
          ),
      ],
    );
  }
}
