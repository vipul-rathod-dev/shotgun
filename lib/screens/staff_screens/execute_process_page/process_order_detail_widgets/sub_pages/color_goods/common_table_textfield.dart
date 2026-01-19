import 'package:flutter/material.dart';

class TableTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const TableTextField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 34,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
