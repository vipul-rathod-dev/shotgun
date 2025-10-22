import 'package:flutter/material.dart';

/// A helper class for mapping order status to a color.
/// Use this anywhere you need to visually represent order progress.
class StatusColor {
  static Color fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'received':
        return Colors.blue.shade800;
      case 'raw process':
        return Colors.orangeAccent;
      case 'color process':
        return Colors.deepOrange;
      case 'quality check':
        return Colors.amber;
      case 'fitting process':
        return Colors.teal;
      case 'demo process':
        return Colors.indigo;
      case 'packing':
        return Colors.purple;
      case 'shipping':
        return Colors.green;

      default:
        return Colors.black54;
    }
  }
}
