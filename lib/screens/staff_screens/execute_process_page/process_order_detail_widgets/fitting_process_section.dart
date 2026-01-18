import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FittingProcessSection extends StatelessWidget {
  final List products;

  const FittingProcessSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Fitting Process",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...products.map((p) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.handyman, size: 32),
              title: Text(p["productName"]),
              subtitle: Text("Prepare ${p["quantity"]} units"),
            ),
          );
        }),
      ],
    );
  }
}
