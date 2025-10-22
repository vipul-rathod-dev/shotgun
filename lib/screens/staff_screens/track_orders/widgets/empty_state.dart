import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Text(
        'No orders found 📦',
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
