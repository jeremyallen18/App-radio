import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/Routes.dart';
import '../design/design.dart';
import 'login.dart';
import '../utils/api_config.dart';

/// Pantalla de renuncia de un miembro. Al confirmar, la persona sale del
/// equipo y los admins reciben una notificación automática avisando que
/// salió del grupo. Un admin también puede usar esta pantalla para
/// abandonar el equipo, siempre que no sea el único admin (esa validación
/// se hace antes de llegar aquí y también la vuelve a aplicar el backend).
class Mresign extends StatefulWidget {
  Mresign({super.key, required this.teamId});
  String? teamId;

  @override
  State<Mresign> createState() => _MresignState();
}

class _MresignState extends State<Mresign> {
  bool _loading = false;

  Future<void> _confirmAndResign() async {
    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: '¿Seguro que quieres abandonar el grupo?',
      message: 'Solo tú saldrás de este equipo; los demás integrantes '
          'seguirán en el grupo. Los admins recibirán una notificación. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Abandonar grupo',
      danger: true,
    );
    if (confirmed != true) return;
    await _resignApi();
  }

  Future<void> _resignApi() async {
    setState(() => _loading = true);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/resign/${widget.teamId}'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saliste del equipo')),
        );
        Navigator.pushNamedAndRemoveUntil(context, MyRoutes.BottomNavBar, (route) => false);
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eres el único admin del equipo; asciende a otro miembro antes de salir'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la renuncia (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al renunciar')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.logout, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                "Abandonar equipo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Al confirmar, saldrás de este equipo. Los admins recibirán una notificación avisando que saliste del grupo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _confirmAndResign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                        )
                      : const Icon(Icons.logout),
                  label: const Text("Renunciar al equipo"),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: Text("Cancelar", style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
