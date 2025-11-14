// utils/color_parser.dart
import 'package:flutter/material.dart';

class ColorParser {
  static Color? parse(String colorLabel) {
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
}
