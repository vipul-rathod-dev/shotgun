import 'package:flutter/material.dart';

import '../models/fab_menu_item_model.dart';

class FabMenu extends StatelessWidget {
  final bool isMenuOpen;
  final AnimationController animationController;
  final VoidCallback toggleMenu;
  final List<FabMenuItem> items;
  final Color fabColor;

  const FabMenu({
    super.key,
    required this.isMenuOpen,
    required this.animationController,
    required this.toggleMenu,
    required this.items,
    this.fabColor = const Color(0xFF1565C0),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (isMenuOpen)
          GestureDetector(
            onTap: toggleMenu,
            child: Container(
              color: Colors.black54.withOpacity(0.4),
              width: double.infinity,
              height: double.infinity,
            ),
          ),

        // Dynamically render each menu item
        ...List.generate(items.length, (index) {
          final item = items[index];

          // auto-stack vertically if no custom position set
          final double bottomPos = item.bottom != 80
              ? item.bottom
              : 80 + (index * 60.0);

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            bottom: isMenuOpen ? bottomPos : 80,
            right: item.right,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isMenuOpen ? 1 : 0,
              child: _buildFabMenuButton(
                icon: item.icon,
                label: item.label,
                onTap: () {
                  toggleMenu();
                  item.onTap();
                },
              ),
            ),
          );
        }),

        // Main FAB toggle
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: fabColor,
            onPressed: toggleMenu,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: animationController,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFabMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
