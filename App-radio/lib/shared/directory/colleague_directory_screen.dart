import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/directory/colleague_profile_screen.dart';
import 'package:doliv_social/shared/directory/directory_api.dart';

/// Directorio interno: busca compañeros por nombre, correo, puesto o número
/// de control y abre la ficha de cualquiera de ellos.
///
/// Arranca acotado al área del propio usuario — que es a quien más se busca —
/// y desde ahí se puede abrir a otra área o a toda la empresa con los chips
/// de arriba. La búsqueda la resuelve el backend (`GET /user/directory`), no
/// un filtro local, para que encuentre también a quien no cabía en la
/// primera pantalla.
class ColleagueDirectoryScreen extends StatefulWidget {
  const ColleagueDirectoryScreen({super.key, this.me, this.initialScope});

  /// Perfil del usuario actual, si quien navega hasta aquí ya lo tenía
  /// cargado. Se usa para marcar su propia fila con "Tú"; si no se pasa, la
  /// pantalla lo pide por su cuenta.
  final UserProfile? me;

  /// Área con la que abrir. Por defecto, la del usuario.
  final DirectoryScope? initialScope;

  @override
  State<ColleagueDirectoryScreen> createState() =>
      _ColleagueDirectoryScreenState();
}

class _ColleagueDirectoryScreenState extends State<ColleagueDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late DirectoryScope _scope = widget.initialScope ?? const MyAreaScope();
  UserProfile? _me;
  List<UserProfile> _colleagues = [];
  List<DepartmentInfo> _departments = [];
  String? _myDepartmentId;
  bool _loading = true;
  String? _error;

  /// Impide apilar dos fichas por un doble toque en la misma fila.
  bool _opening = false;

  /// Distingue "cargando la pantalla" de "reconsultando por un cambio de
  /// búsqueda": lo segundo no debe reemplazar la lista por un spinner de
  /// pantalla completa mientras se escribe.
  bool _refining = false;

  @override
  void initState() {
    super.initState();
    _me = widget.me;
    _myDepartmentId = widget.me?.department?.id;
    _load();
    if (_me == null) _loadMe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (!mounted || profile == null) return;
    setState(() => _me = profile);
  }

  Future<void> _load() async {
    setState(() {
      if (_colleagues.isEmpty) _loading = true;
      _refining = true;
      _error = null;
    });
    try {
      final page = await DirectoryApi.search(
        scope: _scope,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _colleagues = page.colleagues;
        _departments = page.departments;
        _myDepartmentId = page.myDepartmentId ?? _myDepartmentId;
        _loading = false;
        _refining = false;
      });
    } on DirectoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _refining = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    // Un tercio de segundo de espera: suficiente para no lanzar una consulta
    // por tecla y poco como para que la lista no se sienta atrasada.
    _debounce = Timer(const Duration(milliseconds: 350), _load);
    setState(() {}); // refresca el botón de limpiar
  }

  void _selectScope(DirectoryScope scope) {
    if (scope.value == _scope.value) return;
    setState(() => _scope = scope);
    _load();
  }

  void _openProfile(UserProfile colleague) {
    if (_opening) return;
    _opening = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ColleagueProfileScreen(
              colleagueId: colleague.id,
              preview: colleague,
              viewerIsDirector: _me?.role == AppRole.director,
            ),
          ),
        )
        .then((_) => _opening = false);
  }

  /// Nombre del área que se está viendo, para el contador de resultados.
  String get _scopeLabel {
    final scope = _scope;
    if (scope is CompanyScope) return 'toda la empresa';
    final String? id =
        scope is DepartmentScope ? scope.departmentId : _myDepartmentId;
    if (id == null) return 'toda la empresa';
    for (final d in _departments) {
      if (d.id == id) return d.name;
    }
    return 'tu área';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: const Text('Directorio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppTextField(
              controller: _searchController,
              hintText: 'Buscar por nombre, puesto, correo o n.º de control',
              onChanged: _onQueryChanged,
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMuted),
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
          _ScopeChips(
            scope: _scope,
            departments: _departments,
            myDepartmentId: _myDepartmentId,
            onSelect: _selectScope,
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    if (_colleagues.isEmpty) {
      final String typed = _searchController.text.trim();
      final bool canWiden = _scope is! CompanyScope;
      return EmptyState(
        icon: typed.isEmpty
            ? Icons.groups_outlined
            : Icons.person_search_outlined,
        title: typed.isEmpty ? 'Todavía no hay nadie aquí' : 'Sin resultados',
        message: typed.isEmpty
            ? 'Cuando se asignen personas a esta área aparecerán en el directorio.'
            : 'Nadie en $_scopeLabel coincide con lo que buscaste.',
        action: canWiden
            ? OutlinedButton(
                onPressed: () => _selectScope(const CompanyScope()),
                child: const Text('Buscar en toda la empresa'),
              )
            : null,
      );
    }

    final String count = _colleagues.length == 1
        ? '1 persona en $_scopeLabel'
        : '${_colleagues.length} personas en $_scopeLabel';

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: _colleagues.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) return _resultCount(count);

          final colleague = _colleagues[index - 1];
          final bool isMe = colleague.id == _me?.id;
          return AppFadeIn.staggered(
            index: index - 1,
            child: PersonCard(
              name: colleague.name,
              headline: colleague.headline,
              subtitle: colleague.department?.name,
              photoUrl: colleague.photoUrl,
              avatarSeed: colleague.email,
              badge: isMe
                  ? const AppBadge(label: 'Tú', variant: AppBadgeVariant.info)
                  : colleague.leadsOwnDepartment
                      ? const AppBadge(label: 'Responsable')
                      : null,
              onTap: () => _openProfile(colleague),
            ),
          );
        },
      ),
    );
  }

  Widget _resultCount(String count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          // Mientras se reconsulta, un indicador discreto aquí en vez de
          // vaciar la lista: se sigue viendo el resultado anterior.
          if (_refining)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// Fila de áreas por las que se puede filtrar: la propia primero, después
/// toda la empresa y luego el resto de los departamentos.
class _ScopeChips extends StatelessWidget {
  const _ScopeChips({
    required this.scope,
    required this.departments,
    required this.myDepartmentId,
    required this.onSelect,
  });

  final DirectoryScope scope;
  final List<DepartmentInfo> departments;
  final String? myDepartmentId;
  final ValueChanged<DirectoryScope> onSelect;

  bool _isSelectedDepartment(String id) {
    final current = scope;
    return current is DepartmentScope && current.departmentId == id;
  }

  @override
  Widget build(BuildContext context) {
    DepartmentInfo? mine;
    for (final d in departments) {
      if (d.id == myDepartmentId) mine = d;
    }

    final chips = <Widget>[
      // Sin departamento asignado no hay "mi área" que ofrecer: el backend
      // ya devuelve toda la empresa en ese caso, así que el chip sobra.
      if (myDepartmentId != null)
        AppFilterChip(
          label: mine != null ? 'Mi área: ${mine.name}' : 'Mi área',
          count: mine?.employeeCount,
          selected:
              scope is MyAreaScope || _isSelectedDepartment(myDepartmentId!),
          onTap: () => onSelect(const MyAreaScope()),
        ),
      AppFilterChip(
        label: 'Toda la empresa',
        selected: scope is CompanyScope,
        onTap: () => onSelect(const CompanyScope()),
      ),
      for (final d in departments)
        if (d.id != myDepartmentId)
          AppFilterChip(
            label: d.name,
            count: d.employeeCount,
            selected: _isSelectedDepartment(d.id),
            onTap: () => onSelect(DepartmentScope(d.id)),
          ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}
