import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount por enviar' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: SizedBox(
          width: 80,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                backgroundColor: AppColors.primary,
                label: Text('$badgeCount'),
                child: Icon(selected ? selectedIcon : icon, color: color, size: 28),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}