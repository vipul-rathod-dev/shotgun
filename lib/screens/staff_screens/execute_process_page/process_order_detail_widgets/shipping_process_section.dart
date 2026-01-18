import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShippingProcessSection extends StatelessWidget {
  final Map order;
  final List products;
  final DocumentReference orderRef;

  const ShippingProcessSection({
    super.key,
    required this.order,
    required this.products,
    required this.orderRef,
  });

  @override
  Widget build(BuildContext context) {
    final packed = order["productsPacked"] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Shipping Process",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        ...products.map((p) {
          final id = p["productId"];
          final requiredQty = p["quantity"];
          final packedQty = packed[id]?["packed"] ?? 0;
          final remaining = requiredQty - packedQty;

          return Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping, size: 32),
              title: Text(p["productName"]),
              subtitle: Text(
                "Required: $requiredQty • Packed: $packedQty • Remaining: $remaining",
              ),
            ),
          );
        }),

        const SizedBox(height: 20),

        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            onPressed: () async {
              await orderRef.update({
                "orderStatus": "Shipped",
                "shippingTimestamp": FieldValue.serverTimestamp(),
              });
            },
            child: const Text("Mark as Shipped"),
          ),
        ),
      ],
    );
  }
}
