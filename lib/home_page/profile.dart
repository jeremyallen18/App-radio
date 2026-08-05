import 'dart:convert';

import 'package:brl_task4/Utils/Routes.dart';
import 'package:brl_task4/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../design/design.dart';
import '../models/models.dart';
import '../screens/teamDetail.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  UserProfile? _profile;
  int? _pendingCount;
  int? _completedCount;
  List<dynamic> _teams = [];
  bool _loading = true;
  bool _uploadingPhoto = false;
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
    Navigator.pushReplacementNamed(context, MyRoutes.LoginRoutes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();

    final profile = _profile;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 56.0,
                      backgroundImage: (profile?.photoUrl != null)
                          ? NetworkImage(profile!.photoUrl!) as ImageProvider
                          : const AssetImage('lib/assets/prof.png'),
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 56.0,
                          backgroundColor: Color(0x88000000),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _uploadingPhoto ? null : _editProfilePhoto,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile?.name ?? '',
                  style: const TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppBadge(label: profile.role.label, variant: AppBadgeVariant.info),
                      if ((profile.position ?? '').isNotEmpty)
                        AppBadge(label: profile.position!, variant: AppBadgeVariant.neutral),
                      if (profile.department != null)
                        AppBadge(label: profile.department!.name, variant: AppBadgeVariant.neutral),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Resumen'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.pending_actions,
                  value: _pendingCount?.toString() ?? '—',
                  label: 'Pendientes',
                  accentColor: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.check_circle_outline,
                  value: _completedCount?.toString() ?? '—',
                  label: 'Completadas',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.groups_outlined,
                  value: _teams.length.toString(),
                  label: 'Equipos',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Mis equipos'),
          if (_teams.isEmpty)
            const Text(
              'Todavía no perteneces a ningún equipo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _teams.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final team = Map<String, dynamic>.from(_teams[index]);
                  return QuickActionChip(
                    icon: Icons.groups,
                    label: team['teamName']?.toString() ?? 'Equipo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => t_detail(team: team)),
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Cuenta'),
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
          TextButton(
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
        ],
      ),
    );
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
