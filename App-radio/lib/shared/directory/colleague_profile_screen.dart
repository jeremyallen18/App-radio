import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/profile_service.dart';
import 'package:doliv_social/shared/chat/chat.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/shared/directory/directory_api.dart';

/// Ficha de un compañero: quién es, en qué área está y en qué equipos
/// participa. Es de solo lectura — desde aquí no se edita a nadie.
///
/// Si quien navega hasta aquí ya tenía la fila del directorio ([preview]),
/// el encabezado se pinta de inmediato con esos datos y solo el detalle
/// (equipos, antigüedad) espera a la respuesta del servidor.
class ColleagueProfileScreen extends StatefulWidget {
  const ColleagueProfileScreen({
    super.key,
    required this.colleagueId,
    this.preview,
    this.viewerIsDirector = false,
  });

  final String colleagueId;
  final UserProfile? preview;

  /// Si quien mira es el director general: habilita editar el número de
  /// control de esta persona (para corregir inconsistencias). El resto lo ve
  /// en solo lectura.
  final bool viewerIsDirector;

  @override
  State<ColleagueProfileScreen> createState() => _ColleagueProfileScreenState();
}

class _ColleagueProfileScreenState extends State<ColleagueProfileScreen> {
  ColleagueProfile? _profile;
  bool _loading = true;
  String? _error;
  String? _appVersion;

  /// Bloquea taps repetidos (o taps mientras la transición corre) para que
  /// no se apilen dos rutas por una sola acción del usuario.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _load();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await DirectoryApi.profile(widget.colleagueId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on DirectoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado')),
    );
  }

  Future<void> _shareProfile(UserProfile user) async {
    final lines = [
      user.name,
      user.headline,
      if (user.department != null) user.department!.name,
      user.email,
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _composeEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encontramos una app de correo instalada')),
      );
    }
  }

  void _openArea(DepartmentInfo department) {
    if (_navigating) return;
    _navigating = true;
    // `pushReplacement`, no `push`: al entrar al área desde una ficha, el
    // directorio del área SUSTITUYE a esta ficha en la pila. Sin esto,
    // directorio -> ficha -> área -> ficha -> área... crece sin límite
    // (cada salto recrea la pantalla y vuelve a pedir datos), que es la
    // causa del bucle de navegación / consumo de RAM. Con la sustitución la
    // pila se queda en "directorio de origen" + "pantalla actual", y el
    // botón atrás sigue llevando al directorio desde el que se empezó.
    Navigator.of(context)
        .pushReplacement(
          MaterialPageRoute(
            builder: (_) => ColleagueDirectoryScreen(
              initialScope: DepartmentScope(department.id),
            ),
          ),
        )
        .then((_) => _navigating = false);
  }

  /// Entero de la secuencia a partir de `SPPRD-0000042` (→ 42), o null.
  static int? _controlSeq(String? controlNumber) {
    final cn = (controlNumber ?? '').trim();
    if (!cn.startsWith('SPPRD-')) return null;
    return int.tryParse(cn.substring(6));
  }

  Future<void> _editControlNumber(UserProfile user) async {
    final number = await showDialog<int>(
      context: context,
      builder: (_) => _ControlNumberDialog(
        initial: _controlSeq(user.controlNumber),
        personName: user.name,
      ),
    );
    if (number == null || !mounted) return;
    try {
      await ProfileApi.updateControlNumber(user.id, number);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de control actualizado')),
      );
      _load();
    } on ProfileException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile?.user ?? widget.preview;

    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (user != null && widget.viewerIsDirector)
            IconButton(
              onPressed: () => _editControlNumber(user),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar número de control',
            ),
          if (user != null)
            IconButton(
              onPressed: () => _shareProfile(user),
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir perfil',
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (user == null) {
            if (_loading) return const LoadingState();
            return ErrorState(
              message: _error ?? 'No pudimos cargar este perfil.',
              onRetry: _load,
            );
          }

          final teams = _profile?.teams ?? const [];

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                ProfileHeader(
                  name: user.name,
                  headline: user.headline,
                  photoUrl: user.photoUrl,
                  avatarSeed: user.email,
                  badges: [
                    AppBadge(
                        label: user.role.label, variant: AppBadgeVariant.info),
                    if (user.department != null)
                      AppBadge(label: user.department!.name),
                    if (user.leadsOwnDepartment)
                      const AppBadge(
                        label: 'Responsable del área',
                        variant: AppBadgeVariant.success,
                      ),
                  ],
                  footer: _ContactCard(
                    email: user.email,
                    onCopyEmail: () => _copyEmail(user.email),
                    controlNumberLabel: user.controlNumberLabel,
                    controlSeq: _controlSeq(user.controlNumber),
                    onEditControlNumber: widget.viewerIsDirector
                        ? () => _editControlNumber(user)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SendMessageButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerEmail: user.email,
                        peerName: user.name,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SecondaryActionsRow(
                  onShare: () => _shareProfile(user),
                  onEmail: () => _composeEmail(user.email),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_error != null) ...[
                  ErrorState(message: _error!, onRetry: _load),
                  const SizedBox(height: AppSpacing.xl),
                ],
                SectionHeader(
                  title: 'Su área',
                  action: Text(
                    user.department?.name ?? 'Sin asignación',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (user.department == null)
                  const _EmptyCard(
                    icon: Icons.layers_outlined,
                    title: 'Todavía no pertenece a ningún departamento.',
                    message:
                        'Su adscripción la asigna dirección desde el área '
                        'correspondiente.',
                  )
                else
                  _AreaCard(
                    department: user.department!,
                    onTap: () => _openArea(user.department!),
                  ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Equipos',
                  action: Text(
                    teams.isEmpty
                        ? 'Sin equipos activos'
                        : teams.length == 1
                            ? '1 equipo'
                            : '${teams.length} equipos',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_profile == null)
                  _EmptyCard(
                    icon: Icons.groups_2_outlined,
                    title: _loading
                        ? 'Cargando equipos…'
                        : 'No pudimos cargar sus equipos.',
                  )
                else if (teams.isEmpty)
                  const _EmptyCard(
                    icon: Icons.groups_2_outlined,
                    title: 'Todavía no participa en ningún equipo.',
                    message: 'Se une a grupos de trabajo, comités o canales '
                        'de colaboración activa.',
                  )
                else
                  _TeamsSection(profile: _profile, loading: _loading),
                const SizedBox(height: AppSpacing.xl),
                _VerifiedCard(
                  joinedAt: _profile?.joinedAt,
                  verified: user.emailVerified,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'Perfil corporativo centralizado'
                    '${_appVersion != null ? ' • Radio Doliv v$_appVersion' : ''}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const List<String> _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _formatMonthYear(DateTime date) =>
    '${_months[date.month - 1]} de ${date.year}';

/// Tarjeta de contacto de la ficha: correo y credencial corporativos, cada
/// uno con su etiqueta en mayúsculas y un botón de copiar.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.email,
    required this.onCopyEmail,
    required this.controlNumberLabel,
    required this.controlSeq,
    this.onEditControlNumber,
  });

  final String email;
  final VoidCallback onCopyEmail;
  final String controlNumberLabel;
  final int? controlSeq;
  final VoidCallback? onEditControlNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          _row(
            icon: Icons.mail_outline,
            label: 'CORREO CORPORATIVO',
            value: email,
            onCopy: onCopyEmail,
          ),
          Divider(height: 1, color: AppColors.surfaceBorder),
          _row(
            icon: Icons.badge_outlined,
            label: 'CREDENCIAL CORPORATIVA',
            value: controlNumberLabel,
            trailing: controlSeq != null
                ? Text(
                    'Titular #$controlSeq',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  )
                : null,
            onCopy: onEditControlNumber == null
                ? () async {
                    await Clipboard.setData(
                        ClipboardData(text: controlNumberLabel));
                  }
                : null,
            onEdit: onEditControlNumber,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    VoidCallback? onCopy,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      trailing,
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.accentStrong,
              tooltip: 'Editar número de control',
              visualDensity: VisualDensity.compact,
            )
          else if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: AppColors.accentStrong,
              tooltip: 'Copiar',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Fila de acciones secundarias bajo "Enviar mensaje": compartir la ficha o
/// redactar un correo directo a esta persona.
class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow({required this.onShare, required this.onEmail});

  final VoidCallback onShare;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Compartir perfil'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEmail,
            icon: const Icon(Icons.email_outlined, size: 16),
            label: const Text('Redactar email'),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de estado vacío: ícono en un cuadrado redondeado, título y mensaje
/// opcional. Solo lectura — desde la ficha de un compañero no se asignan
/// áreas ni equipos a otra persona.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de cierre con el sello corporativo: desde cuándo está en Radio
/// Doliv y si su correo está verificado.
class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.joinedAt, required this.verified});

  final DateTime? joinedAt;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.podcasts, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En Radio Doliv',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (joinedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Desde ${_formatMonthYear(joinedAt!)}',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (verified)
            const AppBadge(label: '✓ Verificado', variant: AppBadgeVariant.success),
        ],
      ),
    );
  }
}

/// Diálogo para corregir el número de control (solo director). Devuelve el
/// entero de la secuencia (el backend lo formatea a `SPPRD-0000000`), o
/// `null` si se cancela.
class _ControlNumberDialog extends StatefulWidget {
  const _ControlNumberDialog({required this.initial, required this.personName});

  final int? initial;
  final String personName;

  @override
  State<_ControlNumberDialog> createState() => _ControlNumberDialogState();
}

class _ControlNumberDialogState extends State<_ControlNumberDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _parsed {
    final n = int.tryParse(_ctrl.text.trim());
    return (n != null && n >= 1) ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final n = _parsed;
    final preview = n != null ? 'SPPRD-${n.toString().padLeft(7, '0')}' : '—';
    return AlertDialog(
      title: const Text('Número de control'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Corrige el número de ${widget.personName}. Es único: si ya lo '
            'tiene otra persona, el servidor lo rechaza.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _ctrl,
            hintText: 'Número (p. ej. 42)',
            textInputType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: n == null ? null : () => Navigator.pop(context, n),
          child:
              Text('Guardar', style: TextStyle(color: AppColors.accentStrong)),
        ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.department, required this.onTap});

  final DepartmentInfo department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String description = department.description ?? '';
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apartment_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  department.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            department.employeeCount == 1
                ? '1 persona en el área'
                : '${department.employeeCount} personas en el área',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TeamsSection extends StatelessWidget {
  const _TeamsSection({required this.profile, required this.loading});

  final ColleagueProfile? profile;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return AppCard(
        child: Text(
          loading ? 'Cargando equipos…' : 'No pudimos cargar sus equipos.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final teams = profile!.teams;
    if (teams.isEmpty) {
      return AppCard(
        child: Text(
          'Todavía no participa en ningún equipo.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          for (int i = 0; i < teams.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.surfaceBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.groups_outlined,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      teams[i].name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (teams[i].isLeader)
                    const AppBadge(
                        label: 'Líder', variant: AppBadgeVariant.success),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón "Enviar mensaje" de la ficha del compañero. A diferencia de
/// [AppButton] (barra a lo ancho, para CTA de formulario), este se ajusta a su
/// contenido —ícono + texto— porque es una acción suelta a media pantalla.
class _SendMessageButton extends StatelessWidget {
  const _SendMessageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppPressable(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                gradient: AppColors.buttonGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: AppColors.onBrand, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Enviar mensaje',
                      style: TextStyle(
                        color: AppColors.onBrand,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
