import 'package:flutter/material.dart';

class FabMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double bottom;
  final double right;

  const FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bottom = 80,
    this.right = 16,
  });
}
