import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/account_service.dart';
import 'package:doliv_social/services/company_service.dart';

/// Pantalla de "Configuración" del perfil: botones para editar el nombre de la
/// empresa (solo director), el nombre de usuario, y para cambiar el correo o
/// la contraseña. Todo se apoya en `/user/account/*` y `/company/update`.
///
/// Devuelve `true` al cerrarse si algo cambió, para que el perfil se recargue.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late UserProfile _profile;
  String? _companyName;
  bool _loadingCompany = false;
  bool _busy = false;
  bool _changed = false;

  bool get _isDirector => _profile.role == AppRole.director;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    if (_isDirector) _loadCompany();
  }

  Future<void> _loadCompany() async {
    setState(() => _loadingCompany = true);
    try {
      final c = await CompanyApi.fetch();
      if (!mounted) return;
      setState(() => _companyName = c?.name);
    } on CompanyException {
      // Sin bloqueo: la fila mostrará "—" y el usuario puede reintentar.
    } finally {
      if (mounted) setState(() => _loadingCompany = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
    } on AccountException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- acciones -----------------------------------------------------------

  Future<void> _editCompanyName() async {
    final name = await _singleFieldDialog(
      title: 'Nombre de la empresa',
      label: 'Nombre',
      initial: _companyName ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      final c = await AccountApi.updateCompanyName(name);
      if (mounted) setState(() => _companyName = c.name);
      _snack('Nombre de la empresa actualizado.');
    });
  }

  Future<void> _editUserName() async {
    final name = await _singleFieldDialog(
      title: 'Nombre de usuario',
      label: 'Tu nombre',
      initial: _profile.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      final p = await AccountApi.updateName(name);
      if (mounted) setState(() => _profile = p);
      _snack('Nombre actualizado.');
    });
  }

  Future<void> _changeEmail() async {
    final result = await showDialog<({String password, String email})>(
      context: context,
      builder: (_) => const _EmailChangeDialog(),
    );
    if (result == null) return;
    await _run(() async {
      final msg = await AccountApi.requestEmailChange(
        current: result.password,
        newEmail: result.email,
      );
      if (mounted) {
        setState(() => _profile = UserProfile(
              id: _profile.id,
              name: _profile.name,
              email: _profile.email,
              role: _profile.role,
              position: _profile.position,
              controlNumber: _profile.controlNumber,
              photoUrl: _profile.photoUrl,
              department: _profile.department,
              emailVerified: _profile.emailVerified,
              ledSubTeams: _profile.ledSubTeams,
              pendingEmail: result.email,
            ));
      }
      _snack(msg);
    });
  }

  Future<void> _cancelEmailChange() async {
    await _run(() async {
      final p = await AccountApi.cancelEmailChange();
      if (mounted) setState(() => _profile = p);
      _snack('Cambio de correo cancelado.');
    });
  }

  Future<void> _changePassword() async {
    final result = await showDialog<({String current, String next, String confirm})>(
      context: context,
      builder: (_) => const _PasswordChangeDialog(),
    );
    if (result == null) return;
    await _run(() async {
      await AccountApi.changePassword(
        current: result.current,
        next: result.next,
        confirm: result.confirm,
      );
      _snack('Contraseña actualizada.');
    });
  }

  // ---- diálogos ---------------------------------------------------------

  Future<String?> _singleFieldDialog({
    required String title,
    required String label,
    required String initial,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: AppTextField(controller: ctrl, hintText: label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _profile.pendingEmail;
    return AppScaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, _changed)),
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_isDirector) ...[
            const _GroupLabel('Empresa'),
            _OptionCard(
              children: [
                _OptionRow(
                  icon: Icons.apartment_outlined,
                  title: 'Nombre de la empresa',
                  value: _loadingCompany ? 'Cargando…' : (_companyName ?? '—'),
                  onTap: _busy ? null : _editCompanyName,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          const _GroupLabel('Tu cuenta'),
          _OptionCard(
            children: [
              _OptionRow(
                icon: Icons.badge_outlined,
                title: 'Nombre de usuario',
                value: _profile.name,
                onTap: _busy ? null : _editUserName,
              ),
              const _RowDivider(),
              _OptionRow(
                icon: Icons.alternate_email,
                title: 'Correo',
                value: _profile.email,
                onTap: _busy ? null : _changeEmail,
              ),
              if (pending != null) ...[
                const _RowDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_bottom,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Pendiente de confirmar: $pending',
                          style: const TextStyle(
                              color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _cancelEmailChange,
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ],
              const _RowDivider(),
              _OptionRow(
                icon: Icons.lock_outline,
                title: 'Contraseña',
                value: '••••••••',
                onTap: _busy ? null : _changePassword,
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.xl),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accentStrong,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: children),
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.surfaceBorder);
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_outlined,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de cambio de correo: contraseña actual + correo nuevo.
class _EmailChangeDialog extends StatefulWidget {
  const _EmailChangeDialog();
  @override
  State<_EmailChangeDialog> createState() => _EmailChangeDialogState();
}

class _EmailChangeDialogState extends State<_EmailChangeDialog> {
  final _pass = TextEditingController();
  final _email = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña actual.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Correo inválido.');
      return;
    }
    Navigator.pop(context, (password: _pass.text, email: email));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar correo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Te enviaremos un enlace al correo nuevo. El cambio se aplica '
            'cuando lo abras.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _pass,
            obscured: true,
            hintText: 'Contraseña actual',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _email,
            textInputType: TextInputType.emailAddress,
            hintText: 'Correo nuevo',
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(onPressed: _submit, child: const Text('Enviar enlace')),
      ],
    );
  }
}

/// Diálogo de cambio de contraseña: actual / nueva / confirmar.
class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();
  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña actual.');
      return;
    }
    if (_next.text.length < 6) {
      setState(() => _error = 'La nueva contraseña necesita al menos 6 caracteres.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'La confirmación no coincide.');
      return;
    }
    Navigator.pop(
      context,
      (current: _current.text, next: _next.text, confirm: _confirm.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _current,
            obscured: true,
            hintText: 'Contraseña actual',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _next,
            obscured: true,
            hintText: 'Nueva contraseña',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _confirm,
            obscured: true,
            hintText: 'Repite la nueva contraseña',
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(onPressed: _submit, child: const Text('Cambiar')),
      ],
    );
  }
}
