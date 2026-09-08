import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/company.dart';
import 'package:doliv_social/services/company_service.dart';

/// Recuadro para que el director cree la empresa (solo existe una). Se usa
/// dondequiera que haga falta una empresa y todavía no exista: la pantalla de
/// inicio ([DirectorHome]) y la administración de áreas ([TeamAdminScreen]).
///
/// Llama a [onCreated] con la empresa recién creada; el contenedor decide qué
/// mostrar a continuación.
class CreateCompanyCard extends StatefulWidget {
  const CreateCompanyCard({super.key, required this.onCreated});

  final ValueChanged<Company> onCreated;

  @override
  State<CreateCompanyCard> createState() => _CreateCompanyCardState();
}

class _CreateCompanyCardState extends State<CreateCompanyCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final company = await CompanyApi.create(
        name: _nameCtrl.text,
        description: _descCtrl.text,
      );
      if (!mounted) return;
      widget.onCreated(company);
    } on CompanyException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.add_business_outlined,
                  size: 40,
                  color: AppColors.accent,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Crea tu empresa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Todavía no has configurado tu empresa. Créala para empezar '
                  'a organizar áreas, personas y anuncios internos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _nameCtrl,
                  prefixIcon: const Icon(Icons.apartment_outlined),
                  hintText: 'Nombre de la empresa',
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Escribe el nombre de la empresa'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _descCtrl,
                  hintText: 'Descripción (opcional)',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Crear empresa',
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
