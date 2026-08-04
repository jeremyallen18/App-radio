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
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
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
      body: [
        Container(
          alignment: Alignment.center,
          child: ProgressChart(),
        ),
        Container(
            // color: Colors.blue,
            alignment: Alignment.center,
            child:dashb_mem()
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
      ][currentPageIndex],
    );
  }
}