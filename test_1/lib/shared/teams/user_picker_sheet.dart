import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';

/// Hoja para elegir una persona. `people` fija la lista (p.ej. miembros de un
/// departamento); si es null, busca en toda la empresa.
Future<UserProfile?> pickPerson(
  BuildContext context, {
  String title = 'Elegir persona',
  List<UserProfile>? people,
}) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _UserPickerSheet(title: title, fixed: people),
  );
}

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({required this.title, this.fixed});
  final String title;
  final List<UserProfile>? fixed;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _search = TextEditingController();
  List<UserProfile> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.fixed != null) {
      _results = widget.fixed!;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await TeamApi.allPeople(query: _search.text);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixed = widget.fixed;
    final list = fixed == null
        ? _results
        : _results
            .where((u) => u.name.toLowerCase().contains(_search.text.trim().toLowerCase()) ||
                u.email.toLowerCase().contains(_search.text.trim().toLowerCase()))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _search,
            hintText: 'Buscar por nombre o correo',
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) {
              if (fixed == null) {
                _load();
              } else {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 320,
            child: Builder(
              builder: (context) {
                if (_loading) return const LoadingState();
                if (_error != null) return ErrorState(message: _error!, onRetry: _load);
                if (list.isEmpty) {
                  return const EmptyState(title: 'Nadie coincide con la búsqueda');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.surfaceBorder, height: 1),
                  itemBuilder: (_, i) {
                    final u = list[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IdentityAvatar(id: u.name),
                      title: Text(u.name, style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text('${u.email}  ·  ${u.role.label}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      onTap: () => Navigator.pop(context, u),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
