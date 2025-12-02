// process_order_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../assigned_task_page/task_detail_page.dart';

class ProcessOrderDetailPage extends StatefulWidget {
  final String taskPath;
  final String taskTitle;
  final String stage;

  const ProcessOrderDetailPage({
    super.key,
    required this.taskPath,
    required this.taskTitle,
    required this.stage,
  });

  @override
  State<ProcessOrderDetailPage> createState() => _ProcessOrderDetailPageState();
}

class _ProcessOrderDetailPageState extends State<ProcessOrderDetailPage> {
  late final String companyId;
  late final String orderId;
  late final DocumentReference<Map<String, dynamic>> orderRef;

  @override
  void initState() {
    super.initState();

    final segments = widget.taskPath.split("/");
    companyId = segments[1];
    orderId = segments[3];

    orderRef = FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("orders")
        .doc(orderId);
  }

  // ---------------- MAIN BUILD ----------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Order Details", style: GoogleFonts.poppins()),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text("Order not found"));

          final order = snapshot.data!.data()!;
          final List products = order["products"] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerSection(order),

                const SizedBox(height: 20),

                // 🔥 DYNAMIC UI BASED ON STAGE
                _getProcessUI(order, products),

                const SizedBox(height: 30),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailPage(taskPath: widget.taskPath),
                        ),
                      );
                    },
                    child: const Text("Open Full Task Details"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- HEADER ----------------------

  Widget _headerSection(Map order) {
    final orderNumber = order["orderNumber"] ?? "-";
    final brandName = order["brandName"] ?? "-";
    final orderType = order["orderType"] ?? "-";
    final orderStatus = order["orderStatus"] ?? "-";
    final customerName = order["customerName"] ?? "-";
    final customerPhone = order["customerPhone"] ?? "-";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Task: ${widget.taskTitle}",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),

        const SizedBox(height: 10),

        Text("Current Stage: ${widget.stage}",
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),

        const SizedBox(height: 20),

        _info("Order Number", orderNumber),
        _info("Brand", brandName),
        _info("Order Type", orderType),
        _info("Order Status", orderStatus),
        _info("Customer", "$customerName | $customerPhone"),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }

  // ---------------- PROCESS ROUTING ----------------------

  Widget _getProcessUI(Map order, List products) {
    switch (widget.stage) {
      case "Raw Process":
        return _buildRawUI(products);

      case "Color Process":
        return _buildColorUI(products);

      case "Fitting Process":
        return _buildFittingUI(products);

      case "Demo Process":
        return _buildDemoUI(products);

      case "Packing Process":
        return _buildPackingUI(order, products);

      case "Shipping Process":
        return _buildShippingUI(order, products);

      default:
        return const Text("Unknown Process Stage");
    }
  }

  // ---------------- RAW PROCESS ----------------------

  Widget _buildRawUI(List products) {
    return _stageSection(
      title: "Raw Process",
      child: Column(
        children: products.map((p) {
          return _simpleStageCard(
            icon: Icons.precision_manufacturing,
            title: p["productName"],
            subtitle: "Model: ${p["modelGender"]}",
          );
        }).toList(),
      ),
    );
  }

  // ---------------- COLOR PROCESS ----------------------

  Widget _buildColorUI(List products) {
    return _stageSection(
      title: "Color Process",
      child: Column(
        children: products.map((p) {
          return _simpleStageCard(
            icon: Icons.color_lens,
            title: p["productName"],
            subtitle: "Quantity: ${p["quantity"]}",
          );
        }).toList(),
      ),
    );
  }

  // ---------------- FITTING PROCESS ----------------------

  Widget _buildFittingUI(List products) {
    return _stageSection(
      title: "Fitting Process",
      child: Column(
        children: products.map((p) {
          return _simpleStageCard(
            icon: Icons.handyman,
            title: p["productName"],
            subtitle: "Prepare ${p["quantity"]} units",
          );
        }).toList(),
      ),
    );
  }

  // ---------------- DEMO PROCESS ----------------------

  Widget _buildDemoUI(List products) {
    return _stageSection(
      title: "Demo Process",
      child: Column(
        children: products.map((p) {
          return _simpleStageCard(
            icon: Icons.video_label,
            title: p["productName"],
            subtitle: "Demo required before packing",
          );
        }).toList(),
      ),
    );
  }

  // ---------------- PACKING PROCESS ----------------------

  Widget _buildPackingUI(Map order, List products) {
    return _stageSection(
      title: "Packing Process",
      child: SizedBox(
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final p = products[index];

            return _packingCard(order, p);
          },
        ),
      ),
    );
  }

  Widget _packingCard(Map order, Map p) {
    final qty = p["quantity"] ?? 0;
    final name = p["productName"] ?? "Product";
    final gender = p["modelGender"] ?? "-";

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),

          Text("Gender: $gender"),
          Text("Qty Required: $qty"),

          const SizedBox(height: 6),

          // Inventory Viewer
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("companies")
                .doc(companyId)
                .collection("inventory")
                .doc(p["productId"])
                .snapshots(),
            builder: (c, inv) {
              if (!inv.hasData) return const Text("Inventory: ...");

              final stock = inv.data!.data()?["availableQuantity"] ?? 0;
              return Text("Inventory: $stock");
            },
          ),

          const SizedBox(height: 10),

          // Packed qty
          SizedBox(
            height: 36,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("Qty Packed"),
              onChanged: (v) => p["packedInput"] = int.tryParse(v) ?? 0,
            ),
          ),

          const SizedBox(height: 10),

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
          )
        ],
      ),
    );
  }

  // ---------------- SHIPPING PROCESS ----------------------

  Widget _buildShippingUI(Map order, List products) {
    final packedMap = order["productsPacked"] ?? {};

    return _stageSection(
      title: "Shipping Process",
      child: Column(
        children: [
          ...products.map((p) {
            final id = p["productId"];
            final requiredQty = p["quantity"] ?? 0;
            final packedQty = packedMap[id]?["packed"] ?? 0;
            final remaining = requiredQty - packedQty;

            return _simpleStageCard(
              icon: Icons.local_shipping,
              title: p["productName"],
              subtitle:
                  "Required: $requiredQty • Packed: $packedQty • Remaining: $remaining",
            );
          }),

          const SizedBox(height: 20),

          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
      ),
    );
  }

  // ---------------- REUSABLE WIDGETS ----------------------

  Widget _stageSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _simpleStageCard({required IconData icon, required String title, required String subtitle}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade200,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}
