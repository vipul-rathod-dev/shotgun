import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PackingProcessSection extends StatelessWidget {
  final DocumentReference orderRef;
  final String companyId;
  final List products;

  const PackingProcessSection({
    super.key,
    required this.orderRef,
    required this.companyId,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Packing Process",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: products.length,
            itemBuilder: (_, index) => _packingCard(context, products[index]),
          ),
        ),
      ],
    );
  }

  Widget _packingCard(BuildContext context, Map p) {
    final qty = p["quantity"] ?? 0;

    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p["productName"],
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),

          const SizedBox(height: 4),
          Text("Gender: ${p["modelGender"]}"),
          Text("Required Qty: $qty"),

          const SizedBox(height: 6),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("companies")
                .doc(companyId)
                .collection("inventory")
                .doc(p["productId"])
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Text("Inventory: ...");

              final stock = snap.data!.data()?["availableQuantity"] ?? 0;
              return Text("Inventory: $stock");
            },
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 36,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: _input("Qty Packed"),
              onChanged: (v) => p["packedInput"] = int.tryParse(v) ?? 0,
            ),
          ),

          const Spacer(),

          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () async {
                final packedQty = p["packedInput"] ?? 0;

                await orderRef.set({
                  "productsPacked": {
                    p["productId"]: {
                      "required": qty,
                      "packed": packedQty,
                      "timestamp": FieldValue.serverTimestamp(),
                    }
                  }
                }, SetOptions(merge: true));
              },
              child: const Text("Save"),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 3)),
        ],
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      );
}
