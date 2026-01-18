import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DemoProcessSection extends StatelessWidget {
  final List products;

  const DemoProcessSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Demo Process",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...products.map((p) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.video_label, size: 32),
              title: Text(p["productName"]),
              subtitle: const Text("Demo required before packing"),
            ),
          );
        }),
      ],
    );
  }
}
