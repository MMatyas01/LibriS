import 'package:flutter/material.dart';

import '../widgets/bottom_navbar.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  
  // Nem lehet const, mert a HomeScreen most már kap egy függvényt
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Inicializáljuk a listát az initState-ben
    _screens = [
      HomeScreen(
        onNavigateToTab: _onItemSelected, // Átadjuk a fülváltó függvényt
      ),
      const _PlaceholderScreen(title: 'My Library'),
      const _PlaceholderScreen(title: 'Discover'),
      const _PlaceholderScreen(title: 'Community'),
      const _PlaceholderScreen(title: 'Profile'),
    ];
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavbar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}