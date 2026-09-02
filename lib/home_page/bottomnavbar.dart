import 'package:flutter/material.dart';
import 'package:brl_task4/home_page/home_page_home.dart';
import 'package:brl_task4/home_page/progress.dart';
import 'package:brl_task4/home_page/profile.dart';
import '../design/tokens/colors.dart';
import '../screens/dashboard.dart';

// ignore_for_file: prefer_const_constructors

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int currentPageIndex = 2;

  // PageController: permite deslizar entre "Progreso", "Tablero", "Inicio" y
  // "Perfil" con el dedo, además de seguir pudiendo tocar la barra inferior.
  // Arranca en la página "Inicio" (índice 2), igual que currentPageIndex.
  late final PageController _pageController =
      PageController(initialPage: currentPageIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Al tocar un ítem de la barra inferior: anima el PageView hasta esa
  // página (dispara onPageChanged, que ya actualiza currentPageIndex).
  void _onDestinationSelected(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: NavigationBar(
          onDestinationSelected: _onDestinationSelected,
          selectedIndex: currentPageIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.pie_chart),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month),
              label: 'Tablero',
            ),
            NavigationDestination(
              icon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        // Cada página conserva su propio scroll vertical (listas, etc.);
        // el deslizamiento horizontal del PageView no interfiere con eso.
        onPageChanged: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        children: [
          Container(
            alignment: Alignment.center,
            child: ProgressChart(),
          ),
          Container(
            // color: Colors.blue,
            alignment: Alignment.center,
            child: dashb_mem(),
          ),
          Container(
            // color: Colors.blue,
            alignment: Alignment.center,
            child: HomeNav(),
          ),
          Container(
            // color: Colors.blue,
            alignment: Alignment.center,
            child: Profile(),
          ),
        ],
      ),
    );
  }
}