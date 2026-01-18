import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProcessHeader extends StatelessWidget {
  final String taskTitle;
  final String stage;
  final Map order;

  const ProcessHeader({
    super.key,
    required this.taskTitle,
    required this.stage,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(taskTitle,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        Text("Current Stage: $stage",
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),

        _row("Order Number", order["orderNumber"]),
        _row("Brand", order["brandName"]),
        _row("Order Type", order["orderType"]),
        _row("Order Status", order["orderStatus"]),
        _row("Customer", "${order["customerName"]} | ${order["customerPhone"]}"),
      ],
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(value.toString(), style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }
}
