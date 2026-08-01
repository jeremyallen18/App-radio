import 'package:flutter/material.dart';
import 'package:brl_task4/home_page/home_page_home.dart';
import 'package:brl_task4/home_page/progress.dart';
import 'package:brl_task4/home_page/profile.dart';
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
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(255, 78, 102, 158),
              blurRadius: 10,
            ),
          ],
        ),
        child: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          backgroundColor: Color.fromARGB(255, 247, 247, 247),
          // indicatorColor:  Color.fromARGB(255, 56, 72, 108),
          selectedIndex: currentPageIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.pie_chart,
                color: Color.fromARGB(255, 56, 72, 108),
              ),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.calendar_month,
                color: Color.fromARGB(255, 56, 72, 108),
              ),
              label: 'Tablero',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.home,
                color: Color.fromARGB(255, 56, 72, 108),
              ),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_rounded,
                color: Color.fromARGB(255, 56, 72, 108),
              ),
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