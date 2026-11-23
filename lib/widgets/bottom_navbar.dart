import 'package:flutter/material.dart';

import 'unread_messages_badge.dart';

class BottomNavbar extends StatelessWidget {
  const BottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

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
            final NavigationItem item = _items[index];
            final bool isSelected = selectedIndex == index;
            final Color color = isSelected ? _activeColor : _inactiveColor;

            Widget icon = Icon(
              isSelected ? item.activeIcon : item.icon,
              color: color,
              size: 24,
            );

            if (index == 4) {
              icon = UnreadMessagesBadge(
                top: -7,
                right: -10,
                child: icon,
              );
            }

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
                      icon,
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
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
  const NavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
