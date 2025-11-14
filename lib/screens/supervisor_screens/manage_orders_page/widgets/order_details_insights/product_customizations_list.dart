// widgets/product_customizations_list.dart
import 'package:flutter/material.dart';
import 'color_chip.dart';

class ProductCustomizationsList extends StatelessWidget {
  final List<dynamic> customizations;
  final num perModelOrderQty;

  const ProductCustomizationsList({
    super.key,
    required this.customizations,
    required this.perModelOrderQty,
  });

  @override
  Widget build(BuildContext context) {
    if (customizations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: customizations.map<Widget>((c) {
        final focusColor = (c['focusColor'] ?? '').toString().trim();
        final templeColor = (c['templeColor'] ?? '').toString().trim();
        final focusQty = ((c['focusQty'] ?? 0) as num) * perModelOrderQty;
        final templeQty = ((c['templeQty'] ?? 0) as num) * perModelOrderQty;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ColorChip(label: focusColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(focusColor.isEmpty ? '—' : focusColor, style: const TextStyle(fontSize: 13))),
                    Text(focusQty.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    ColorChip(label: templeColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(templeColor.isEmpty ? '—' : templeColor, style: const TextStyle(fontSize: 13))),
                    Text(templeQty.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
