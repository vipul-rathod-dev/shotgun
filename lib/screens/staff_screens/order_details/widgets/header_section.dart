import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeaderSection extends StatelessWidget {
  final String customerName;
  final String status;
  final Color color;
  final Color textColor;

  const HeaderSection({
    super.key,
    required this.customerName,
    required this.status,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  'Status: $status',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
