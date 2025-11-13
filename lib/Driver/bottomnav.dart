import 'package:flutter/material.dart';
import 'package:recycleapp/Driver/home.dart';
import 'package:recycleapp/Driver/points.dart';
import 'package:recycleapp/Driver/profile.dart';
import 'package:recycleapp/Driver/DispostalGuide.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int currentTabIndex = 0;

  final List<Widget> pages = [Home(), Points(), DisposalGuide(), Profile()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTabIndex,
        onTap: (index) {
          setState(() {
            currentTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 28),
            activeIcon: Icon(Icons.home, size: 30, color: Colors.green),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined, size: 28),
            activeIcon: Icon(
              Icons.point_of_sale,
              size: 30,
              color: Colors.green,
            ),
            label: 'Points',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.recycling_outlined, size: 28),
            activeIcon: Icon(Icons.recycling, size: 30, color: Colors.green),
            label: 'Guide',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            activeIcon: Icon(Icons.person, size: 30, color: Colors.green),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
