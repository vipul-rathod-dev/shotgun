import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/pdf/customization_pdf_generator_alt.dart';

import 'sub_pages/color_goods/color_goods_table_page.dart';

class ColorProcessSection extends StatefulWidget {
  final List products; // ← coming from parent
  final String companyId;
  final Map order;
  final String orderId;

  const ColorProcessSection({
    super.key,
    required this.products,
    required this.companyId,
    required this.order,
    required this.orderId,
  });

  @override
  State<ColorProcessSection> createState() => _ColorProcessSectionState();
}

class _ColorProcessSectionState extends State<ColorProcessSection> {
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance
        .collection("companies")
        .doc(widget.companyId)
        .collection("orders")
        .doc(widget.orderId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: orderRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orderData = snapshot.data!.data() ?? {};
        final orderProducts = (orderData["products"] is List)
            ? List<Map<String, dynamic>>.from(orderData["products"])
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Color Process",
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            ...widget.products.map((p) {
              final productId = p["productId"];
              final productName = p["productName"] ?? "Unnamed Product";

              // --- Focus & Temple Qty from parent ---
              final focusMap = (p["focusBaseMaterialQuantities"] is Map)
                  ? Map<String, dynamic>.from(
                      p["focusBaseMaterialQuantities"])
                  : {};
              final templeMap = (p["templeBaseMaterialQuantities"] is Map)
                  ? Map<String, dynamic>.from(
                      p["templeBaseMaterialQuantities"])
                  : {};

              final int focusQty =
                  focusMap.values.fold(0, (a, b) => a + _toInt(b));
              final int templeQty =
                  templeMap.values.fold(0, (a, b) => a + _toInt(b));

              // --- Total Quantity from ORDER DATABASE ---
              final orderProduct = orderProducts.firstWhere(
                (op) => op["productId"] == productId,
                orElse: () => {"quantity": 0},
              );
              final int totalQty = _toInt(orderProduct["quantity"]);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.color_lens,
                      size: 32, color: Colors.deepPurple),
                  title: Text(productName,
                      style: GoogleFonts.poppins(fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Focus Qty: $focusQty",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        "Temple Qty: $templeQty",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        "Total Qty (Order): $totalQty",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final generator = CustomizationPdfGeneratorAlt();
                  await generator.generateAndShareAltPdf(widget.order as Map<String, dynamic>, widget.products);
                },
                label: Text("Share Color Customization PDF"),
                icon: const Icon(Icons.picture_as_pdf)
              )
            ),

            const SizedBox(height: 16),

            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ColorGoodsTablePage(
                        companyId: widget.companyId,
                        orderId: widget.orderId,
                        products: widget.products,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.table_chart),
                label: Text(
                  "Update Color Goods",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
