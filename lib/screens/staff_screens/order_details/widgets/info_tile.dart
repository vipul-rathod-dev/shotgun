import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final Color textColor;

  const InfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$title:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
