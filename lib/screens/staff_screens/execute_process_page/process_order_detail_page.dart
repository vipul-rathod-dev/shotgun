// process_order_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'process_order_detail_widgets/color_process_section.dart';
import 'process_order_detail_widgets/demo_process_section.dart';
import 'process_order_detail_widgets/fitting_process_section.dart';
import 'process_order_detail_widgets/packing_process_section.dart';
import 'process_order_detail_widgets/process_header.dart';
import 'process_order_detail_widgets/raw_process_section.dart';
import 'process_order_detail_widgets/shipping_process_section.dart';

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

    final path = widget.taskPath.split("/");
    companyId = path[1];
    orderId = path[3];

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
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text("Order not found"));

          final order = snap.data!.data()!;
          final orderId = snap.data!.id;
          final List products = order["products"] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔵 HEADER
                ProcessHeader(
                  taskTitle: widget.taskTitle,
                  stage: widget.stage,
                  order: order,
                ),

                const SizedBox(height: 20),

                /// 🔥 STAGE BASED UI
                _buildStageUI(order, products, orderId),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- PROCESS ROUTING ----------------------

  Widget _buildStageUI(Map order, List products, String orderId) {
    switch (widget.stage) {
      case "Raw Process":
        return RawProcessSection(products: products, companyId: companyId, order: order, orderId: orderId);

      case "Color Process":
        return ColorProcessSection(products: products, companyId: companyId, order: order, orderId: orderId);

      case "Fitting Process":
        return FittingProcessSection(products: products);

      case "Demo Process":
        return DemoProcessSection(products: products);

      case "Packing Process":
        return PackingProcessSection(
          orderRef: orderRef,
          companyId: companyId,
          products: products,
        );

      case "Shipping Process":
        return ShippingProcessSection(
          order: order,
          products: products,
          orderRef: orderRef,
        );

      default:
        return const Text("Unknown Stage");
    }
  }
}
