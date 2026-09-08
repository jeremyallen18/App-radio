import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/shared/chat/chatHistory.dart';
import 'package:doliv_social/shared/widgets/app_menu_sections.dart';

export 'package:doliv_social/shared/widgets/app_menu_sections.dart'
    show AppMenuEntry, AppMenuSection;

/// Menú hamburguesa de la app. Aloja **todas** las secciones que antes vivían
/// en el cuerpo de cada dashboard (asistencia, calendario, tareas, equipos,
/// administración…), para dejar la pantalla de inicio libre y dedicada a los
/// anuncios internos de la empresa.
///
/// Es autosuficiente: carga el perfil del usuario y arma las secciones según
/// su rol (ver [appMenuSectionsForRole]), así que cualquier pantalla puede
/// usarlo con `const AppMenuDrawer()`.
///
/// Se abre desde el botón de menú de [MyAppBar] (visible cuando la pantalla
/// pasa `drawer:` a [AppScaffold]) o desde un botón propio de la pantalla.
class AppMenuDrawer extends StatefulWidget {
  const AppMenuDrawer({super.key});

  @override
  State<AppMenuDrawer> createState() => _AppMenuDrawerState();
}

class _AppMenuDrawerState extends State<AppMenuDrawer> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token?.toString() ?? '');
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openChat() {
    Navigator.of(context)
      ..pop() // cierra el drawer
      ..push(MaterialPageRoute(builder: (_) => const ChatScreenfetch()));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _entryTile(AppMenuEntry entry) {
    final bool active = entry.enabled && entry.onTap != null;
    return ListTile(
      leading: Icon(
        entry.icon,
        color: active ? AppColors.accent : AppColors.textMuted,
      ),
      title: Text(
        entry.title,
        style: TextStyle(
          color: active ? AppColors.textPrimary : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: entry.subtitle != null
          ? Text(
              entry.subtitle!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          : null,
      trailing: entry.trailingLabel != null
          ? Text(
              entry.trailingLabel!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            )
          : (active
              ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
              : null),
      enabled: active,
      onTap: active
          ? () {
              Navigator.of(context).pop(); // cierra el drawer
              entry.onTap!();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final departmentName = profile?.department?.name;
    final sections = profile == null
        ? const <AppMenuSection>[]
        : appMenuSectionsForRole(
            profile,
            onPushScreen: _push,
            onPushNamed: (routeName) =>
                Navigator.pushNamed(context, routeName),
          );

    return Drawer(
      backgroundColor: AppColors.bgBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menú',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile == null
                        ? 'Cargando...'
                        : (departmentName != null
                            ? '${profile.name} · $departmentName'
                            : profile.name),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  _sectionTitle('Comunicación'),
                  ListTile(
                    leading: const Icon(Icons.chat_outlined,
                        color: AppColors.accent),
                    title: const Text(
                      'Chat del departamento',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Chat general de la empresa',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    trailing: profile != null
                        ? const Icon(Icons.chevron_right,
                            color: AppColors.textMuted)
                        : null,
                    enabled: profile != null,
                    onTap: _openChat,
                  ),
                  for (final section in sections) ...[
                    _sectionTitle(section.title),
                    for (final entry in section.entries) _entryTile(entry),
                  ],
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Radio Doliv',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
