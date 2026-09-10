import 'package:flutter/material.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/shared/home/profile.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/glass_panel.dart';
import 'package:doliv_social/design/motion/app_motion.dart';
import 'package:doliv_social/shared/board/dashboard.dart';
import 'package:doliv_social/features/dashboard/role_dashboard_router.dart';
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
  _NavDestination(
      icon: Icons.pie_chart_outline,
      selectedIcon: Icons.pie_chart,
      label: 'Progreso'),
  _NavDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Tablero'),
  _NavDestination(
      icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Inicio'),
  _NavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil'),
];

class _NavDestination {
  const _NavDestination(
      {required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _BottomNavBarState extends State<BottomNavBar> {
  int currentPageIndex = 2;

  // Las pestañas viven en un PageView para poder cambiarlas deslizando el
  // dedo. Cada página se envuelve en [_KeepAlivePage] para que conserve su
  // estado (scroll, datos ya cargados) aunque quede fuera de pantalla.
  final PageController _pageController =
      PageController(initialPage: 2); // = currentPageIndex

  // Las páginas van "embebidas" (sin su propia MyAppBar ni menú); el shell
  // pinta una MyAppBar fija arriba del PageView, así no se desliza al cambiar
  // de pestaña. Perfil trae su propio encabezado.
  static const List<Widget> _pages = [
    ProgressChart(embedded: true),
    DashbMem(embedded: true),
    RoleDashboardRouter(embedded: true),
    Profile(),
  ];

  // La barra superior fija solo se muestra en las 3 primeras pestañas; Perfil
  // (índice 3) usa su propio encabezado, sin MyAppBar.
  static const int _profileIndex = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Toque en la barra: salta a la pestaña. Si el salto es a una vecina, lo
  // anima; si es lejano, salta directo para no construir/animar las pestañas
  // intermedias.
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

  // Deslizar el dedo dentro del PageView: sincroniza la barra inferior.
  void _onPageChanged(int index) {
    if (index == currentPageIndex) return;
    setState(() => currentPageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      // Barra superior fija: no se desliza con el PageView. En Perfil se
      // oculta (esa pestaña trae su propio encabezado).
      appBar: currentPageIndex == _profileIndex ? null : const MyAppBar(),
      drawer: const AppMenuDrawer(),
      // El menú se abre con el botón de la MyAppBar; el gesto de arrastre
      // desde el borde se desactiva para que no compita con el deslizamiento
      // entre pestañas.
      drawerEnableOpenDragGesture: false,
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: currentPageIndex,
        onSelect: _onSelect,
      ),
      body: Column(
        children: [
          // El aviso de "verifica tu correo" va arriba de todo el contenido.
          // Se oculta solo si la cuenta ya está verificada.
          const VerifyEmailBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const ClampingScrollPhysics(),
              children: [
                for (final page in _pages)
                  _KeepAlivePage(
                      child: AppFadeIn(offset: Offset.zero, child: page)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mantiene viva su [child] aunque el [PageView] la saque de pantalla, para
/// que cada pestaña conserve su estado (scroll, datos cargados) al deslizar.
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

/// Barra inferior flotante: un panel de vidrio separado de los bordes. Cada
/// destino es ícono sobre etiqueta; el activo lleva una pastilla azul acento
/// y una barrita corta debajo.
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
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: GlassPanel(
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 4,
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
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              // La clave cambia al seleccionar/deseleccionar, así el tween
              // vuelve a correr y el ícono activo da un pequeño rebote.
              key: ValueKey(selected),
              tween: Tween(begin: selected ? 0.82 : 1.0, end: 1.0),
              duration:
                  context.reduceMotion ? Duration.zero : AppDurations.short,
              curve: AppCurves.emphasized,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                selected ? data.selectedIcon : data.icon,
                size: 22,
                color: fg,
              ),
            ),
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
