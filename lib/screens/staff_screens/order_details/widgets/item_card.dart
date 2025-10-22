import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'customization_table.dart';

class ItemCard extends StatelessWidget {
  final String itemName;
  final int qty;
  final double price;
  final List customizations;
  final Color statusColor;
  final bool isDark;

  const ItemCard({
    super.key,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.customizations,
    required this.statusColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$qty pcs',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (customizations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300, thickness: 0.8),
            const SizedBox(height: 8),
            Text(
              'Color Customizations',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 6),
            CustomizationTable(
              customizations: customizations,
              statusColor: statusColor,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}
