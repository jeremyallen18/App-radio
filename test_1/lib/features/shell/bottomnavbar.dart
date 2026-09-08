import 'package:flutter/material.dart';
import 'package:doliv_social/shared/home/profile.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/design/tokens/breakpoints.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/glass_panel.dart';
import 'package:doliv_social/design/components/state_views.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/shared/board/dashboard.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/shared/auth/verify_email_banner.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';

// ignore_for_file: prefer_const_constructors

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

const List<_NavDestination> _destinations = [
  _NavDestination(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart, label: 'Progreso'),
  _NavDestination(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist_rtl, label: 'Tablero'),
  _NavDestination(icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Directorio'),
  _NavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil'),
];

class _NavDestination {
  const _NavDestination({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _BottomNavBarState extends State<BottomNavBar> {
  int currentPageIndex = 1;
  bool _isDesktopSidebarVisible = true;

  final PageController _pageController = PageController(initialPage: 1);

  // Escritorio (IndexedStack): cada página trae su propia MyAppBar.
  static const List<Widget> _pages = [
    ProgressChart(),
    dashb_mem(),
    _DirectoryTab(),
    Profile(),
  ];

  // Móvil (PageView): las 3 primeras pestañas van "embebidas" (sin su propia
  // MyAppBar ni menú); el shell pinta una MyAppBar fija arriba del PageView.
  // Perfil trae su propio encabezado.
  static const List<Widget> _mobilePages = [
    ProgressChart(embedded: true),
    dashb_mem(embedded: true),
    _DirectoryTab(),
    Profile(),
  ];

  // La barra superior fija solo se muestra en las pestañas distintas a Perfil.
  static const int _profileIndex = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSelect(int index) {
    setState(() => currentPageIndex = index);
    if (_pageController.hasClients) {
      final current = _pageController.page?.round() ?? currentPageIndex;
      if ((index - current).abs() > 1) {
        _pageController.jumpToPage(index);
      } else {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onPageChanged(int index) {
    if (index == currentPageIndex) return;
    setState(() => currentPageIndex = index);
  }

  void hideSidebar() => setState(() => _isDesktopSidebarVisible = false);

  void showSidebar() => setState(() => _isDesktopSidebarVisible = true);

  void toggleSidebar() => setState(() => _isDesktopSidebarVisible = !_isDesktopSidebarVisible);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = AppBreakpoints.isDesktop(context);
    final Widget content = Column(
      children: [
        const VerifyEmailBanner(),
        Expanded(
          child: IndexedStack(index: currentPageIndex, children: _pages),
        ),
      ],
    );

    final Widget mobileContent = Column(
      children: [
        const VerifyEmailBanner(),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const ClampingScrollPhysics(),
            children: [
              for (final page in _mobilePages) _KeepAlivePage(child: page),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            if (_isDesktopSidebarVisible) ...[
              NavigationRail(
                extended: true,
                minExtendedWidth: AppBreakpoints.sidebarWidth,
                selectedIndex: currentPageIndex,
                onDestinationSelected: _onSelect,
                labelType: NavigationRailLabelType.none,
                leading: _DesktopSidebarHeader(onHide: hideSidebar),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, color: AppColors.surfaceBorder),
            ],
            Expanded(
              child: Stack(
                children: [
                  content,
                  if (!_isDesktopSidebarVisible)
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: _SidebarToggleButton(
                        icon: Icons.menu_open_rounded,
                        tooltip: 'Mostrar barra lateral',
                        onPressed: showSidebar,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: currentPageIndex == _profileIndex ? null : const MyAppBar(),
      drawer: const AppMenuDrawer(),
      drawerEnableOpenDragGesture: false,
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: currentPageIndex,
        onSelect: _onSelect,
      ),
      body: mobileContent,
    );
  }
}

/// Pestaña "Directorio": `ColleagueDirectoryScreen` necesita el `UserProfile`
/// del usuario para filtrar por su área y marcar su propia ficha. Aquí se
/// carga una vez y se muestra `LoadingState` mientras llega.
class _DirectoryTab extends StatefulWidget {
  const _DirectoryTab();

  @override
  State<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends State<_DirectoryTab> {
  late Future<UserProfile?> _meFuture;

  @override
  void initState() {
    super.initState();
    _meFuture = _loadMe();
  }

  Future<UserProfile?> _loadMe() async {
    final token = await secureStorage.readSecureData(key);
    return Session.fetchCurrentUser((token as String?) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _meFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: AppColors.bgBase,
            child: LoadingState(),
          );
        }
        return ColleagueDirectoryScreen(me: snapshot.data);
      },
    );
  }
}

/// Mantiene viva su [child] aunque el [PageView] la saque de pantalla.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Barra inferior flotante: un panel de vidrio separado de los bordes.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
        ),
        child: GlassPanel(
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: 4,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 22,
                      color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                    ),
                  Expanded(
                    child: _NavCell(
                      data: _destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? AppColors.textPrimary : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? data.selectedIcon : data.icon, size: 22, color: fg),
            const SizedBox(height: 3),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: selected ? 18 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebarHeader extends StatelessWidget {
  const _DesktopSidebarHeader({required this.onHide});

  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppRailLogo(),
        _SidebarToggleButton(
          icon: Icons.keyboard_double_arrow_left_rounded,
          tooltip: 'Ocultar barra lateral',
          onPressed: onHide,
        ),
      ],
    );
  }
}

class _AppRailLogo extends StatelessWidget {
  const _AppRailLogo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.32),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Image.asset(
          'assets/logo/logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Doliv Social',
        ),
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.accentStrong,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          fixedSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
      ),
    );
  }
}
