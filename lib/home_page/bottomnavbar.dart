import 'package:flutter/material.dart';
import 'package:doliv_social/home_page/progress.dart';
import 'package:doliv_social/home_page/profile.dart';
import '../design/tokens/breakpoints.dart';
import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../screens/dashboard.dart';
import '../screens/role_dashboard_router.dart';

// ignore_for_file: prefer_const_constructors

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

const List<_NavDestination> _destinations = [
  _NavDestination(icon: Icons.pie_chart_outline, selectedIcon: Icons.pie_chart, label: 'Progreso'),
  _NavDestination(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Tablero'),
  _NavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Inicio'),
  _NavDestination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil'),
];

class _NavDestination {
  const _NavDestination({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _BottomNavBarState extends State<BottomNavBar> {
  int currentPageIndex = 2;
  bool _isDesktopSidebarVisible = true;

  // IndexedStack en vez de indexar una lista: cada pestaña se construye una
  // sola vez y mantiene su estado (scroll, datos ya cargados) al cambiar de
  // pestaña, en vez de recrearse desde cero cada vez.
  static const List<Widget> _pages = [
    ProgressChart(),
    dashb_mem(),
    RoleDashboardRouter(),
    Profile(),
  ];

  void _onSelect(int index) => setState(() => currentPageIndex = index);

  void hideSidebar() => setState(() => _isDesktopSidebarVisible = false);

  void showSidebar() => setState(() => _isDesktopSidebarVisible = true);

  void toggleSidebar() => setState(() => _isDesktopSidebarVisible = !_isDesktopSidebarVisible);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = AppBreakpoints.isDesktop(context);
    final Widget content = IndexedStack(index: currentPageIndex, children: _pages);

    // En escritorio, con espacio de sobra a los lados y el mouse como
    // entrada principal, una barra lateral fija se siente como una app de
    // escritorio de verdad — en vez de una barra inferior de teléfono
    // estirada en medio de una ventana ancha.
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

    final NavigationBar navBar = NavigationBar(
      onDestinationSelected: _onSelect,
      selectedIndex: currentPageIndex,
      destinations: [
        for (final d in _destinations)
          NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
      ],
    );

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
        // Sin backgroundColor/color de ícono propios: hereda de
        // navigationBarTheme (AppTheme.dark) — fondo azul oscuro de marca e
        // íconos claros, igual que el resto de la app.
        child: navBar,
      ),
      body: content,
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
