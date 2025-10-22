import 'package:flutter/material.dart';

class InventorySearchBar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final TextEditingController? controller;
  final String hintText;

  const InventorySearchBar({
    super.key,
    required this.onSearch,
    this.controller,
    this.hintText = 'Search Products',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: onSearch,
      ),
    );
  }
}
