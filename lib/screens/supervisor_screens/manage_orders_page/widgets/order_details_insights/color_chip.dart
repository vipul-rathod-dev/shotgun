// widgets/color_chip.dart
import 'package:flutter/material.dart';

class ColorChip extends StatelessWidget {
  final String label;
  const ColorChip({super.key, required this.label});

  Color? _parseColor(String colorLabel) {
    final cleaned = colorLabel.replaceAll('#', '').replaceAll('0x', '');
    if (cleaned.length == 6 || cleaned.length == 8) {
      try {
        final hex = int.parse(cleaned, radix: 16);
        return cleaned.length == 6 ? Color(0xFF000000 | hex) : Color(hex);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseColor(label);
    if (parsed != null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: parsed,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade200,
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '-',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}
