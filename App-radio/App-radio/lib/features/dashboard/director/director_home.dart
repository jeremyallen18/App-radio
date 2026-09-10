import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/create_company_card.dart';
import 'package:doliv_social/models/company.dart';
import 'package:doliv_social/services/company_service.dart';
import 'package:doliv_social/shared/home/announcements_board.dart';

/// Pantalla de inicio del director.
///
/// Si todavía no existe la empresa (primer arranque), muestra un recuadro
/// para crearla; en cuanto existe, cede el paso al tablero de anuncios
/// internos ([AnnouncementsBoard]), igual que para el resto de roles.
class DirectorHome extends StatefulWidget {
  const DirectorHome({super.key});

  @override
  State<DirectorHome> createState() => _DirectorHomeState();
}

class _DirectorHomeState extends State<DirectorHome> {
  bool _loading = true;
  String? _error;
  Company? _company;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final company = await CompanyApi.fetch();
      if (!mounted) return;
      setState(() {
        _company = company;
        _loading = false;
      });
    } on CompanyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_company == null) {
      return CreateCompanyCard(
        onCreated: (company) => setState(() => _company = company),
      );
    }
    return const AnnouncementsBoard();
  }
}
