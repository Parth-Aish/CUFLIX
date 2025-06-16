// lib/screens/nav_screen.dart

import 'package:flutter/material.dart';
import 'package:cuflix/screens/home_screen.dart';
import 'package:cuflix/screens/request_screen.dart';
import 'package:cuflix/screens/search_screen.dart'; // ADD THIS IMPORT

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const RequestScreen(),
    const SearchScreen(), // REPLACE THE PLACEHOLDER WITH ACTUAL SEARCH SCREEN
  ];

  final Map<String, IconData> _icons = const {
    'Home': Icons.home,
    'Request Dvd': Icons.queue_play_next,
    'Search': Icons.search,
  };

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        items: _icons
            .map((title, icon) => MapEntry(
                  title,
                  BottomNavigationBarItem(
                    icon: Icon(icon, size: 30.0),
                    label: title,
                  ),
                ))
            .values
            .toList(),
        currentIndex: _currentIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11.0,
        unselectedFontSize: 11.0,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
