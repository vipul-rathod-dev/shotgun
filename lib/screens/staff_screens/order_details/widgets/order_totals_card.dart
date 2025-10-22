import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTotalsCard extends StatelessWidget {
  final int totalProducts;
  final int totalQuantity;
  final Color statusColor;

  const OrderTotalsCard({
    super.key,
    required this.totalProducts,
    required this.totalQuantity,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.9), Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRichStat(Icons.inventory_2, 'Products', '$totalProducts', Colors.lime),
          _buildRichStat(Icons.numbers, 'Quantity', '$totalQuantity', Colors.lime),
        ],
      ),
    );
  }

  Widget _buildRichStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
