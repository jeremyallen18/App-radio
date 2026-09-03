import 'package:doliv_social/core/Routes.dart';
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
import 'package:doliv_social/core/audio/radio_player.dart';

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
  List<dynamic> _teams = [];
  bool _loading = true;
  bool _uploadingPhoto = false;
  _ProfileTab _tab = _ProfileTab.equipos;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final overview = await ProfileApi.fetchOverview();
    if (!mounted) return;
    setState(() {
      _profile = overview.profile;
      _pendingCount = overview.pendingCount;
      _completedCount = overview.completedCount;
      _teams = overview.teams;
      _loading = false;
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

  void _openDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ColleagueDirectoryScreen(me: _profile),
      ),
    );
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
    await secureStorage.deleteSecureData(key);
    await secureStorage.deleteSecureData(rememberMeKey);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, MyRoutes.LoginRoutes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    // Esta pantalla es una pestaña de `BottomNavBar`, no un `AppScaffold`:
    // el área segura y el centrado en escritorio los tiene que poner ella.
    return SafeArea(
      child: DesktopCenter(
        child: RefreshIndicator(onRefresh: _load, child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ProfileHero(
          name: profile?.name ?? 'Mi perfil',
          headline: profile?.headline ?? 'Cargando tu información…',
          photoUrl: profile?.photoUrl,
          avatarSeed: profile?.email ?? profile?.name ?? '?',
          onEditPhoto: _editProfilePhoto,
          uploadingPhoto: _uploadingPhoto,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile != null)
                ProfileMetaRow(
                  icon: Icons.apartment_outlined,
                  text: profile.department != null
                      ? '${profile.department!.name} · Radio Doliv'
                      : 'Radio Doliv',
                ),
              const SizedBox(height: AppSpacing.sm),
              if (profile != null)
                ProfileMetaRow(
                  icon: Icons.mail_outline,
                  text: profile.email,
                  trailing: IconButton(
                    onPressed: _copyEmail,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    color: AppColors.accentStrong,
                    tooltip: 'Copiar correo',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              if (profile != null) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppBadge(label: profile.role.label, variant: AppBadgeVariant.info),
                    if (profile.department != null)
                      AppBadge(label: profile.department!.name),
                    if (profile.leadsOwnDepartment)
                      const AppBadge(
                        label: 'Responsable del área',
                        variant: AppBadgeVariant.success,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Tres columnas de igual ancho: así no se desbordan en pantallas
              // estrechas ni con el texto a mayor escala.
              Row(
                children: [
                  Expanded(
                    child: ProfileStatItem(
                      value: _pendingCount?.toString() ?? '—',
                      label: 'Pendientes',
                    ),
                  ),
                  Expanded(
                    child: ProfileStatItem(
                      value: _completedCount?.toString() ?? '—',
                      label: 'Completadas',
                    ),
                  ),
                  Expanded(
                    child: ProfileStatItem(
                      value: _teams.length.toString(),
                      label: 'Equipos',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceBorder),
        Row(
          children: [
            ProfileTabButton(
              label: 'Equipos',
              selected: _tab == _ProfileTab.equipos,
              onTap: () => setState(() => _tab = _ProfileTab.equipos),
            ),
            ProfileTabButton(
              label: 'Mi área',
              selected: _tab == _ProfileTab.area,
              onTap: () => setState(() => _tab = _ProfileTab.area),
            ),
            ProfileTabButton(
              label: 'Cuenta',
              selected: _tab == _ProfileTab.cuenta,
              onTap: () => setState(() => _tab = _ProfileTab.cuenta),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
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
                  _accountRow('Editar foto de perfil', Icons.edit_square, _editProfilePhoto),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
                  _accountRow('Seguridad', Icons.security, () => _comingSoon('Seguridad')),
                  const Divider(height: 1, color: AppColors.surfaceBorder),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 10),
                    Text(
                      "Cerrar sesión",
                      style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(fontSize: 15.0, color: AppColors.textPrimary),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_outlined, size: 16.0, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
