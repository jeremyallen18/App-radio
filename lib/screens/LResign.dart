import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';
import '../design/design.dart';

class Resign extends StatefulWidget {
  Resign({super.key, required this.teamId});
  String? teamId;
  @override
  State<Resign> createState() => _ResignState();
}

class _ResignState extends State<Resign> {
  final _removeFormKey = GlobalKey<FormState>();
  final _assignFormKey = GlobalKey<FormState>();
  TextEditingController MEmailController = TextEditingController();
  TextEditingController EmailController = TextEditingController();
  bool _removing = false;
  bool _assigning = false;

  String? _requiredEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Indica un correo';
    if (!value.contains('@')) return 'Ese correo no parece válido';
    return null;
  }

  Future<void> removeApi(String? teamId) async {
    if (!(_removeFormKey.currentState?.validate() ?? false)) return;

    setState(() => _removing = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/team/deleteMember/$teamId';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
        },
        body: ({
          "memberEmail": MEmailController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Miembro eliminado")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo eliminar el miembro (${response.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de red al eliminar el miembro")),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> resignApi(String? teamId) async {
    if (!(_assignFormKey.currentState?.validate() ?? false)) return;

    setState(() => _assigning = true);
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/team/leaderResign/$teamId';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Authorization': storedValue,
        },
        body: ({
          "Correo": EmailController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nuevo líder asignado")),
        );
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo asignar el nuevo líder (${response.statusCode})")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de red al asignar el nuevo líder")),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Gestionar miembros'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Eliminar un miembro'),
          AppCard(
            child: Form(
              key: _removeFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: MEmailController,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                    hintText: "Correo del miembro a eliminar",
                    textInputType: TextInputType.emailAddress,
                    validator: _requiredEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _removing ? 'Eliminando…' : 'Eliminar miembro',
                    loading: _removing,
                    onPressed: _removing ? null : () => removeApi(widget.teamId),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Asignar nuevo líder'),
          AppCard(
            child: Form(
              key: _assignFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'La persona que indiques pasará a ser la líder de este equipo.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: EmailController,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                    hintText: "Correo del nuevo líder",
                    textInputType: TextInputType.emailAddress,
                    validator: _requiredEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _assigning ? 'Asignando…' : 'Asignar como líder',
                    loading: _assigning,
                    onPressed: _assigning ? null : () => resignApi(widget.teamId),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
