import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/design.dart';
import '../utils/api_config.dart';
import 'login.dart';

/// Pantalla que reemplaza al antiguo botón "Gestionar miembros": permite a
/// cualquier admin del equipo agregar nuevos miembros por correo, sacar del
/// grupo a quien seleccione, y ascender/quitar admins. Un equipo puede
/// tener más de un admin, y cualquiera de ellos puede hacer todas estas
/// acciones, incluyendo poner o quitar a otros admins.
class ManageMembers extends StatefulWidget {
  ManageMembers({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.currentUserEmail,
    required List<String> admins,
    required List<String> members,
    Map<String, String>? memberNames,
  })  : admins = List<String>.from(admins),
        members = List<String>.from(members),
        memberNames = Map<String, String>.from(memberNames ?? const {});

  final String teamId;
  final String teamName;
  // Correo de quien tiene esta pantalla abierta: se usa para saber si una
  // acción de "quitar admin" es sobre uno mismo (y así, tras confirmarla,
  // salir de la pantalla porque se pierden los permisos de admin).
  final String currentUserEmail;
  final List<String> admins;
  final List<String> members;
  // Nombre de perfil por correo (en minúsculas), para mostrar a cada
  // miembro por su nombre en vez de su correo. Viene de teamDetail.dart,
  // que a su vez lo arma con `memberNames` del backend.
  final Map<String, String> memberNames;

  @override
  State<ManageMembers> createState() => _ManageMembersState();
}

class _ManageMembersState extends State<ManageMembers> {
  late List<String> _members;
  // Se guarda aparte de widget.admins (que no cambia durante la vida de
  // este widget) para poder reflejar al instante un ascenso/baja de admin
  // hecho desde esta misma pantalla, sin esperar a reabrirla.
  late List<String> _admins;
  final Set<String> _selected = {};
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _adding = false;
  bool _removing = false;
  String? _updatingAdminFor;
  // Se refresca en segundo plano al abrir la pantalla (ver
  // _refreshMembersFromServer): la lista que llega por parámetro puede
  // haber quedado desactualizada si el equipo cambió mientras el usuario
  // estaba en otra pantalla.
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Se muestran todos los usuarios del equipo, admins incluidos: esta
    // lista es el listado completo de "Miembros del equipo", no solo los
    // que se pueden sacar. Los admins se identifican con una insignia y no
    // son seleccionables para "sacar del grupo": para eso primero hay que
    // quitarles el rol de admin, con el botón junto a cada miembro.
    //
    // Se parte de widget.members para que la pantalla no arranque vacía,
    // pero apenas se monta se pide la versión más reciente al backend
    // (_refreshMembersFromServer): si el equipo se abrió desde una lista
    // que no se había recargado en un rato (p. ej. el tab de Equipos),
    // esto evita mostrar un listado incompleto o desactualizado.
    _members = List<String>.from(widget.members);
    _admins = List<String>.from(widget.admins);
    _refreshMembersFromServer();
  }

  bool _isAdmin(String email) =>
      _admins.any((a) => a.toLowerCase() == email.toLowerCase());

  // Nombre de perfil a mostrar para un correo: usa widget.memberNames si lo
  // tiene (viene del backend) y, si no, cae de vuelta a la parte del correo
  // antes de la @ (igual que antes de tener nombres de perfil).
  String _displayName(String email) {
    final resolved = widget.memberNames[email.toLowerCase()];
    if (resolved != null && resolved.trim().isNotEmpty) return resolved.trim();
    return email.contains('@') ? email.substring(0, email.indexOf('@')) : email;
  }

  bool _isSelf(String email) =>
      email.toLowerCase() == widget.currentUserEmail.toLowerCase();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa un correo';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) return 'Correo no válido';
    return null;
  }

  /// Trae la lista de miembros y admins directamente del backend (misma
  /// fuente que usa el resto de la app: GET /team/showTeams) y la usa como
  /// fuente de verdad. Así "Miembros del equipo" siempre queda igual a lo
  /// que hay realmente en la base de datos, sin depender de qué tan fresca
  /// haya llegado la lista pasada por parámetro. Si el backend todavía no
  /// manda `admins` (versión previa a este cambio), se usa `leaderEmail`
  /// como admin único para no romper equipos existentes.
  Future<void> _refreshMembersFromServer({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _refreshing = true);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.get(
        Uri.parse('$kBaseUrl/team/showTeams'),
        headers: <String, String>{'Authorization': storedValue ?? ''},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> teams = jsonDecode(response.body)['teams'] ?? [];
        for (final t in teams) {
          final team = Map<String, dynamic>.from(t as Map);
          if (team['_id']?.toString() == widget.teamId) {
            final fresh = List<String>.from(
              (team['teamMembers'] as List?)?.map((m) => m.toString()) ??
                  const [],
            );
            final freshAdmins = (team['admins'] as List?)
                ?.map((a) => a.toString())
                .where((a) => a.isNotEmpty)
                .toList();
            final leaderEmail = team['leaderEmail']?.toString();
            setState(() {
              _members = fresh;
              _admins = (freshAdmins != null && freshAdmins.isNotEmpty)
                  ? freshAdmins
                  : (leaderEmail != null && leaderEmail.isNotEmpty
                      ? [leaderEmail]
                      : _admins);
              // Deselecciona a cualquiera que ya no esté en la lista
              // actualizada (por si se sacó desde otro lado mientras
              // tanto).
              _selected.retainWhere(fresh.contains);
            });
            break;
          }
        }
      }
    } catch (_) {
      // Sin conexión: se sigue mostrando la lista que ya se tenía en
      // pantalla en lugar de bloquear la pantalla con un error.
    } finally {
      if (mounted && showSpinner) setState(() => _refreshing = false);
    }
  }

  Future<void> _addMember() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();

    if (_members.any((m) => m.toLowerCase() == email.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa persona ya pertenece al equipo')),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/addMember/${widget.teamId}'),
        headers: <String, String>{
          'Authorization': storedValue ?? '',
          'Content-Type': 'application/json',
        },
        body: json.encode({"memberEmail": email}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _members.add(email);
          _emailController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$email agregado al equipo')),
        );
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esa persona ya pertenece al equipo')),
        );
        // El backend ya lo tiene como miembro pero la pantalla no lo
        // reflejaba: se refresca para que la lista quede consistente.
        _refreshMembersFromServer(showSpinner: false);
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo un admin del equipo puede agregar miembros'),
          ),
        );
      } else if (response.statusCode == 404) {
        // El equipo ya no existe (se borró, o el id con el que se abrió
        // esta pantalla quedó obsoleto). No tiene sentido seguir
        // intentando desde acá.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este equipo ya no existe. Volviendo atrás…'),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agregar (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al agregar el miembro')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;

    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Sacar del grupo',
      message: _selected.length == 1
          ? 'Se eliminará a "${_selected.first}" del equipo.'
          : 'Se eliminará a ${_selected.length} miembros del equipo.',
      confirmLabel: 'Sacar',
      danger: true,
    );
    if (confirmed != true) return;

    setState(() => _removing = true);
    final storedValue = await secureStorage.readSecureData(key);
    final toRemove = List<String>.from(_selected);
    // Se cuenta como "quitado" tanto lo que el backend borró ahora mismo
    // como lo que ya no estaba (404 "Member not found"): en ambos casos el
    // resultado que le importa al usuario -esa persona ya no está en el
    // equipo- es el mismo, así que no tiene sentido mostrarlo como error.
    final List<String> removedOk = [];
    int otherErrors = 0;
    bool forbidden = false;

    for (final email in toRemove) {
      try {
        final response = await http.post(
          Uri.parse('$kBaseUrl/team/deleteMember/${widget.teamId}'),
          headers: <String, String>{
            'Authorization': storedValue ?? '',
            'Content-Type': 'application/json',
          },
          body: json.encode({"memberEmail": email}),
        );
        if (response.statusCode == 200 || response.statusCode == 404) {
          removedOk.add(email);
        } else if (response.statusCode == 403) {
          forbidden = true;
        } else {
          otherErrors++;
        }
      } catch (_) {
        otherErrors++;
      }
    }

    if (!mounted) return;
    setState(() {
      _members.removeWhere((m) => removedOk.contains(m));
      _selected.removeWhere((m) => removedOk.contains(m));
      _removing = false;
    });

    final String message;
    if (forbidden) {
      message = 'Solo un admin del equipo puede sacar miembros';
    } else if (otherErrors == 0) {
      message = '${removedOk.length} miembro(s) eliminado(s)';
    } else {
      message =
          '${removedOk.length} eliminado(s), $otherErrors no se pudieron eliminar';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    // Por si algo cambió del lado del servidor que la app todavía no sabe
    // (por ejemplo, alguien más gestionando el mismo equipo a la vez).
    _refreshMembersFromServer(showSpinner: false);
  }

  // Asciende a un miembro del equipo a admin. Cualquier admin actual puede
  // hacerlo, y a diferencia de la vieja "transferencia de liderazgo", esto
  // no le quita el rol a quien lo hace: el equipo simplemente pasa a tener
  // un admin más. El backend (POST /team/addAdmin/{teamId}) debe agregar
  // el correo a la lista de admins del equipo.
  Future<void> _promoteToAdmin(String email) async {
    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Hacer admin',
      message: '"$email" podrá gestionar miembros, tareas y otros admins '
          'del equipo, igual que tú.',
      confirmLabel: 'Hacer admin',
    );
    if (confirmed != true) return;

    setState(() => _updatingAdminFor = email);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/addAdmin/${widget.teamId}'),
        headers: <String, String>{
          'Authorization': storedValue ?? '',
          'Content-Type': 'application/json',
        },
        body: json.encode({"memberEmail": email}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          if (!_isAdmin(email)) _admins.add(email);
          _selected.remove(email);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$email" ahora es admin del equipo')),
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo un admin del equipo puede agregar otros admins')),
        );
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esa persona ya no pertenece al equipo')),
        );
        _refreshMembersFromServer(showSpinner: false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo hacer admin (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al hacer admin')),
      );
    } finally {
      if (mounted) setState(() => _updatingAdminFor = null);
    }
  }

  // Quita el rol de admin a alguien (puede ser uno mismo). El backend
  // (POST /team/removeAdmin/{teamId}) debe rechazar la operación con 400 si
  // esa persona es el único admin del equipo, para que nunca quede un
  // equipo sin ningún admin.
  Future<void> _demoteAdmin(String email) async {
    final removingSelf = _isSelf(email);
    final bool? confirmed = await showAppConfirmDialog(
      context,
      title: 'Quitar admin',
      message: removingSelf
          ? 'Dejarás de ser admin de este equipo. Podrás seguir siendo '
              'miembro normal, pero perderás acceso a esta pantalla.'
          : '"$email" dejará de ser admin y pasará a ser miembro normal '
              'del equipo.',
      confirmLabel: 'Quitar admin',
      danger: removingSelf,
    );
    if (confirmed != true) return;

    setState(() => _updatingAdminFor = email);
    try {
      final storedValue = await secureStorage.readSecureData(key);
      final response = await http.post(
        Uri.parse('$kBaseUrl/team/removeAdmin/${widget.teamId}'),
        headers: <String, String>{
          'Authorization': storedValue ?? '',
          'Content-Type': 'application/json',
        },
        body: json.encode({"memberEmail": email}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _admins.removeWhere((a) => a.toLowerCase() == email.toLowerCase());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$email" ya no es admin del equipo')),
        );
        // Si te quitaste el rol a ti mismo, ya no tienes permiso para
        // seguir gestionando el equipo desde aquí.
        if (removingSelf) Navigator.pop(context);
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo un admin del equipo puede quitar admins')),
        );
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El equipo debe tener al menos un admin; asciende a otro miembro primero'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo quitar el admin (${response.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al quitar el admin')),
      );
    } finally {
      if (mounted) setState(() => _updatingAdminFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  'Miembros de "${widget.teamName}"',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ---- Agregar miembro por correo ----
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar miembro',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _emailController,
                          hintText: 'correo@gmail.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          textInputType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _adding ? null : _addMember,
                          child: _adding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add_alt_1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Miembros del equipo (${_members.length})',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _members.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Todavía no hay más miembros',
                    message: 'Agrega a alguien por su correo para empezar.',
                  )
                : RefreshIndicator(
                    onRefresh: _refreshMembersFromServer,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final email = _members[index];
                        final isAdmin = _isAdmin(email);
                        final selected = _selected.contains(email);
                        final busy = _updatingAdminFor == email;
                        // Un equipo nunca puede quedarse sin admins: si esta
                        // persona es el único admin, su botón de "quitar
                        // admin" se deshabilita (debe ascender a otro
                        // miembro primero).
                        final canDemote = !(_admins.length <= 1 && isAdmin);

                        // Los admins se muestran en la lista (son parte del
                        // equipo) pero no son seleccionables para "sacar del
                        // grupo": para eso primero hay que quitarles el rol
                        // de admin, con el botón de escudo junto a su
                        // nombre.
                        if (isAdmin) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.shield, color: AppColors.accent),
                              // Los admins se muestran con su nombre en negrita y en
                              // el color de acento, para que resalten más que un
                              // miembro normal (ver el título sin admin más abajo).
                              title: Text(
                                _displayName(email),
                                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    icon: busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Icon(
                                            Icons.remove_moderator_outlined,
                                            color: canDemote ? AppColors.error : AppColors.textMuted,
                                          ),
                                    tooltip: canDemote
                                        ? 'Quitar admin'
                                        : 'Es el único admin: asciende a otro miembro primero',
                                    onPressed: (_updatingAdminFor != null || !canDemote)
                                        ? null
                                        : () => _demoteAdmin(email),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppColors.error : AppColors.surfaceBorder,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: selected,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.error,
                            checkColor: AppColors.textPrimary,
                            title: Text(
                              _displayName(email),
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            secondary: IconButton(
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.add_moderator_outlined, color: AppColors.accent),
                              tooltip: 'Hacer admin',
                              onPressed: _updatingAdminFor != null
                                  ? null
                                  : () => _promoteToAdmin(email),
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selected.add(email);
                                } else {
                                  _selected.remove(email);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selected.isEmpty || _removing) ? null : _removeSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
              ),
              icon: _removing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                    )
                  : const Icon(Icons.person_remove_outlined),
              label: Text(
                _selected.isEmpty
                    ? 'Sacar del grupo'
                    : 'Sacar del grupo (${_selected.length})',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
