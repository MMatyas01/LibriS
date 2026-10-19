import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const BottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const List<NavigationItem> _items = [
    NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    NavigationItem(
      label: 'My Library',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
    ),
    NavigationItem(
      label: 'Discover',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
    ),
    NavigationItem(
      label: 'Community',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
    ),
    NavigationItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  static const Color _activeColor = Color(0xFF36834B);
  static const Color _inactiveColor = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFEFA),
          border: Border(
            top: BorderSide(
              color: Color(0xFFE5E5E5),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final isSelected = selectedIndex == index;
            final color = isSelected ? _activeColor : _inactiveColor;

            return Expanded(
              child: InkWell(
                onTap: () => onItemSelected(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: color,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
