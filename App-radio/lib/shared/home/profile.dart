import 'package:doliv_social/core/routes.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/profile_service.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/shared/home/profile_hero.dart';
import 'package:doliv_social/shared/home/profile_widgets.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/features/dashboard/director/team_admin_screen.dart';
import 'package:doliv_social/features/dashboard/settings/account_settings_screen.dart';
import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/core/push/push_service.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

enum _ProfileTab { equipos, area, cuenta }

class _ProfileState extends State<Profile> {
  UserProfile? _profile;
  int? _pendingCount;
  int? _completedCount;
  // Solo director: nº de áreas y de colaboradores de toda la organización.
  int? _areasCount;
  int? _collabCount;
  List<dynamic> _teams = [];
  bool _loading = true;
  bool _uploadingPhoto = false;
  _ProfileTab _tab = _ProfileTab.equipos;
  final ImagePicker _picker = ImagePicker();

  /// El director no participa en equipos: se le oculta esa sección del perfil.
  bool get _isDirector => _profile?.role == AppRole.director;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final overview = await ProfileApi.fetchOverview();
    if (!mounted) return;

    // El director ve contadores de toda la organización (áreas, colaboradores
    // y totales de tareas de la empresa) en lugar de los suyos de equipo.
    DirectorOrgStats? org;
    if (overview.profile?.role == AppRole.director) {
      org = await ProfileApi.fetchDirectorOrg();
      if (!mounted) return;
    }

    setState(() {
      _profile = overview.profile;
      _pendingCount = org?.pendingCount ?? overview.pendingCount;
      _completedCount = org?.completedCount ?? overview.completedCount;
      _areasCount = org?.areasCount;
      _collabCount = org?.collaboratorsCount;
      _teams = overview.teams;
      _loading = false;
      // El director no tiene pestaña "Equipos": si era la seleccionada por
      // defecto, se mueve a "Vista general".
      if (_isDirector && _tab == _ProfileTab.equipos) _tab = _ProfileTab.area;
    });
  }

  Future<void> _editProfilePhoto() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final updated = await ProfileApi.uploadPhoto(pickedFile.path);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } on ProfileException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _copyEmail() async {
    final email = _profile?.email;
    if (email == null) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado')),
    );
  }

  Future<void> _copyControlNumber() async {
    final controlNumber = _profile?.controlNumber;
    if (controlNumber == null) return;
    await Clipboard.setData(ClipboardData(text: controlNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número de control copiado')),
    );
  }

  void _openDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ColleagueDirectoryScreen(me: _profile),
      ),
    );
  }

  void _openAreas() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TeamAdminScreen()),
    );
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProgressChart()),
    );
  }

  Future<void> _openAccountSettings() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountSettingsScreen(profile: profile),
      ),
    );
    if (changed == true) _load();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature: próximamente')),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    // Cortar la transmisión en vivo: no debe seguir sonando tras cerrar sesión.
    await RadioPlayer.instance.stop();
    NotificationsController.instance.clear();
    await PushService.instance.disable();
    // Solo se elimina el token: la sesión queda cerrada. El correo y la
    // contraseña guardados con "Recuérdame" se conservan a propósito para que
    // Login vuelva a aparecer precargado.
    await secureStorage.deleteSecureData(key);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, MyRoutes.loginRoutes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: _ProfileSkeleton());
    }

    // Esta pantalla es una pestaña de `BottomNavBar`, no un `AppScaffold`:
    // el área segura la tiene que poner ella.
    return SafeArea(
      child: RefreshIndicator(
          onRefresh: _load, color: AppColors.accent, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final profile = _profile;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ProfileHero(
          name: profile?.name ?? 'Mi perfil',
          roleLabel: profile?.headline ?? 'Cargando tu información…',
          stationLabel: profile?.department != null
              ? '${profile!.department!.name} · Radio Doliv'
              : 'Radio Doliv',
          photoUrl: profile?.photoUrl,
          avatarSeed: profile?.email ?? profile?.name ?? '?',
          onEditPhoto: _editProfilePhoto,
          uploadingPhoto: _uploadingPhoto,
          verified: profile?.emailVerified ?? false,
          statusBadgeLabel: profile?.controlNumber != null
              ? 'SPPRD-ACTIVO'
              : null,
          email: profile?.email ?? '',
          onCopyEmail: _copyEmail,
          controlNumberLabel: profile?.controlNumberLabel ?? 'Sin asignar',
          onCopyControlNumber:
              profile?.controlNumber != null ? _copyControlNumber : null,
          trailingBadge: profile != null && _isDirector
              // El rol y la empresa ya salen bajo el nombre; aquí basta el
              // estado de alcance.
              ? const AppBadge(
                  label: '● Acceso global',
                  variant: AppBadgeVariant.success,
                )
              : null,
          extraBadges: profile != null && !_isDirector
              ? [
                  AppBadge(
                      label: profile.role.label,
                      variant: AppBadgeVariant.info),
                  if (profile.department != null)
                    AppBadge(label: profile.department!.name),
                  if (profile.leadsOwnDepartment)
                    const AppBadge(
                      label: 'Responsable del área',
                      variant: AppBadgeVariant.success,
                    ),
                ]
              : const [],
          stats: [
            ProfileStatItem(
              value: _pendingCount?.toString() ?? '—',
              label: 'Pendientes',
              accentColor: AppColors.warning,
            ),
            ProfileStatItem(
              value: _completedCount?.toString() ?? '—',
              label: 'Completadas',
              accentColor: AppColors.success,
            ),
            if (!_isDirector)
              ProfileStatItem(
                value: _teams.length.toString(),
                label: 'Equipos',
                accentColor: AppColors.accent,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          child: ProfileSegmentedTabs(
            labels: [
              if (!_isDirector) 'Equipos',
              _isDirector ? 'Vista general' : 'Mi área',
              _isDirector ? 'Cuenta y Accesos' : 'Cuenta',
            ],
            selectedIndex: !_isDirector
                ? _ProfileTab.values.indexOf(_tab)
                : _tab == _ProfileTab.area
                    ? 0
                    : 1,
            onChanged: (i) => setState(() {
              if (!_isDirector) {
                _tab = _ProfileTab.values[i];
              } else {
                _tab = i == 0 ? _ProfileTab.area : _ProfileTab.cuenta;
              }
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          child: _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case _ProfileTab.equipos:
        return ProfileTeamsList(teams: _teams);
      case _ProfileTab.area:
        if (_isDirector) {
          return DirectorOverviewTab(
            areasCount: _areasCount,
            collaboratorsCount: _collabCount,
            onOpenAreas: _openAreas,
            onOpenDirectory: _openDirectory,
            onOpenReports: _openReports,
            // "Configuración" = empresa + datos de la cuenta (nombre, correo,
            // contraseña). La gestión de áreas está en el card "Áreas".
            onOpenSettings: _openAccountSettings,
          );
        }
        return ProfileAreaCard(
          department: _profile?.department,
          onOpenDirectory: _openDirectory,
        );
      case _ProfileTab.cuenta:
        return Column(
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _accountRow('Editar foto de perfil', Icons.edit_square,
                      _editProfilePhoto),
                  Divider(height: 1, color: AppColors.surfaceBorder),
                  _accountRow('Seguridad', Icons.security,
                      () => _comingSoon('Seguridad')),
                  Divider(height: 1, color: AppColors.surfaceBorder),
                  _accountRow(
                    'Sugerencias y comentarios',
                    Icons.feedback_outlined,
                    () => _comingSoon('Sugerencias y comentarios'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _confirmLogout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 10),
                    Text(
                      "Cerrar sesión",
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _accountRow(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20.0, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style:
                      TextStyle(fontSize: 15.0, color: AppColors.textPrimary),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios_outlined,
                size: 16.0, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Marcador de posición mientras carga el perfil: reproduce a grandes rasgos
/// la silueta de la pantalla (avatar, nombre, tarjetas) con un barrido suave.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonGroup(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          Center(child: SkeletonBox(width: 96, height: 96, radius: 48)),
          SizedBox(height: AppSpacing.lg),
          Center(child: SkeletonLine(width: 180, height: 18)),
          SizedBox(height: AppSpacing.sm),
          Center(child: SkeletonLine(width: 120)),
          SizedBox(height: AppSpacing.xxl),
          SkeletonBox(height: 72, radius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 72, radius: AppRadius.card),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, radius: AppRadius.card),
        ],
      ),
    );
  }
}
