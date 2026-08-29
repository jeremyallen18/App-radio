import 'dart:convert';

import 'package:doliv_social/Utils/Routes.dart';
import 'package:doliv_social/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../design/design.dart';
import '../models/models.dart';
import '../screens/directory/colleague_directory_screen.dart';
import '../screens/teamDetail.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';

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
    final token = await secureStorage.readSecureData(key);

    Future<int?> count(String path, String field) async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/$path'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
        if (response.statusCode != 200) return null;
        final List<dynamic> list = jsonDecode(response.body)[field] ?? [];
        return list.length;
      } catch (_) {
        return null;
      }
    }

    Future<List<dynamic>> teams() async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/team/showTeams'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
        if (response.statusCode != 200) return [];
        return jsonDecode(response.body)['teams'] ?? [];
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      Session.fetchCurrentUser(token ?? ''),
      count('team/incompleteTasks', 'incompleteTasks'),
      count('team/completedTasks', 'completedTasks'),
      teams(),
    ]);

    if (!mounted) return;
    setState(() {
      _profile = results[0] as UserProfile?;
      _pendingCount = results[1] as int?;
      _completedCount = results[2] as int?;
      _teams = results[3] as List<dynamic>;
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
      final token = await secureStorage.readSecureData(key);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kBaseUrl/user/photo'),
      );
      request.headers['Authorization'] = token ?? '';
      request.files.add(await http.MultipartFile.fromPath('photo', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _profile = UserProfile.fromJson(json));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      } else {
        String message = 'No se pudo actualizar la foto';
        try {
          message = (jsonDecode(response.body)['error'] as String?) ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al subir la foto'),
          backgroundColor: Colors.red,
        ),
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
    secureStorage.deleteSecureData(key);
    secureStorage.deleteSecureData(rememberMeKey);
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
        _ProfileHero(
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
                _MetaRow(
                  icon: Icons.apartment_outlined,
                  text: profile.department != null
                      ? '${profile.department!.name} · Radio Doliv'
                      : 'Radio Doliv',
                ),
              const SizedBox(height: AppSpacing.sm),
              if (profile != null)
                _MetaRow(
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
                    child: _StatItem(
                      value: _pendingCount?.toString() ?? '—',
                      label: 'Pendientes',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: _completedCount?.toString() ?? '—',
                      label: 'Completadas',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
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
            _TabButton(
              label: 'Equipos',
              selected: _tab == _ProfileTab.equipos,
              onTap: () => setState(() => _tab = _ProfileTab.equipos),
            ),
            _TabButton(
              label: 'Mi área',
              selected: _tab == _ProfileTab.area,
              onTap: () => setState(() => _tab = _ProfileTab.area),
            ),
            _TabButton(
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
        return _TeamsList(teams: _teams);
      case _ProfileTab.area:
        return _AreaCard(
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

/// Banda de marca a todo lo ancho con la foto superpuesta, a la manera de
/// una cabecera de perfil de X: sin tarjeta, sin bordes — la pantalla misma
/// es el encabezado.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.headline,
    required this.photoUrl,
    required this.avatarSeed,
    required this.onEditPhoto,
    required this.uploadingPhoto,
  });

  final String name;
  final String headline;
  final String? photoUrl;
  final String avatarSeed;
  final VoidCallback onEditPhoto;
  final bool uploadingPhoto;

  static const double _bandHeight = 120;
  static const double _avatarRadius = 44;
  static const double _ringWidth = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: _bandHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandBlue, AppColors.brandNavy],
                ),
              ),
            ),
            // El avatar se coloca con `Padding` (no `Positioned`) para que el
            // `Stack` crezca y contenga la parte que sobresale de la banda; si
            // no, el nombre de abajo se montaría encima de la foto.
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                top: _bandHeight - _avatarRadius - _ringWidth,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(_ringWidth),
                    decoration: const BoxDecoration(
                      color: AppColors.bgBase,
                      shape: BoxShape.circle,
                    ),
                    child: IdentityAvatar(
                      id: avatarSeed,
                      label: name,
                      radius: _avatarRadius,
                      photoUrl: photoUrl,
                    ),
                  ),
                  if (uploadingPhoto)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(_ringWidth),
                        decoration: BoxDecoration(
                          color: AppColors.bgBase.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: AppColors.bgBase,
                      shape: const CircleBorder(
                        side: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: uploadingPhoto ? null : onEditPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: AppColors.accentStrong,
                            semanticLabel: 'Cambiar foto de perfil',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                headline,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Pestaña estilo X: subrayado de acento sobre el texto activo, resto
/// silenciado. Reparte el ancho en partes iguales entre las tres pestañas.
class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamsList extends StatelessWidget {
  const _TeamsList({required this.teams});

  final List<dynamic> teams;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const AppCard(
        child: Text(
          'Todavía no perteneces a ningún equipo.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < teams.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _TeamRow(team: Map<String, dynamic>.from(teams[i])),
        ],
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team});

  final Map<String, dynamic> team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => t_detail(team: team)),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              team['teamName']?.toString() ?? 'Equipo',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Tarjeta del departamento propio y puerta de entrada al directorio. Es el
/// único lugar de la app donde se busca gente, así que la acción va visible
/// en la tarjeta y no escondida en la lista de "Cuenta".
class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.department, required this.onOpenDirectory});

  final DepartmentInfo? department;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    final dept = department;
    final String description = dept?.description ?? '';

    return AppCard(
      onTap: onOpenDirectory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dept?.name ?? 'Sin departamento asignado',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dept == null
                ? 'Aun así puedes buscar a cualquier persona de Radio Doliv.'
                : description.isNotEmpty
                    ? description
                    : (dept.employeeCount == 1
                        ? '1 persona en el área'
                        : '${dept.employeeCount} personas en el área'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.person_search_outlined, size: 18, color: AppColors.accentStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dept == null ? 'Buscar compañeros' : 'Ver y buscar compañeros de mi área',
                  style: const TextStyle(
                    color: AppColors.accentStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}
