// order_details_insights_page.dart
// Main screen (minimal) - uses controller + widgets + pdf modules

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/order_details_controller.dart';
import '../../pdf/customization_pdf_generator_alt.dart';
import '../../pdf/order_pdf_generator.dart';
import 'order_header.dart';
import 'order_stats_card.dart';
import 'product_card.dart';

class OrderDetailsInsightsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsInsightsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsInsightsPage> createState() =>
      _OrderDetailsInsightsPageState();
}

class _OrderDetailsInsightsPageState extends State<OrderDetailsInsightsPage> with SingleTickerProviderStateMixin {
  final OrderDetailsController controller = OrderDetailsController();

  @override
  void initState() {
    super.initState();
    controller.loadCompanyId();
  }

  @override
  void didUpdateWidget(covariant OrderDetailsInsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.resetPreviousStep();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.companyId,
      builder: (context, companyId, _) {
        if (companyId == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final orderStream = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('orders')
            .doc(widget.orderId)
            .snapshots();

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text('Order Insights'),
            backgroundColor: Colors.indigo,
            elevation: 0,
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: orderStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Order not found.'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final products = (data['products'] as List<dynamic>?) ?? [];

              final totals = controller.computeTotals(products);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OrderHeader(
                    data: data,
                    status: data['orderStatus'] ?? 'Received',
                  ),
                  const SizedBox(height: 16),
                  OrderStatsCard(totals: totals),
                  const SizedBox(height: 16),
                  const Text(
                    'Product Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (products.isEmpty)
                    const Text('No products in this order.')
                  else
                    ...products.map((p) => ProductCard(
                          product: p,
                          orderData: data,
                        )),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final company = controller.companyId.value;
              if (company == null) return;
              final doc = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(company)
                  .collection('orders')
                  .doc(widget.orderId)
                  .get();

              if (!doc.exists) return;
              final data = doc.data() as Map<String, dynamic>;
              final products = (data['products'] as List<dynamic>?) ?? [];

              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                        title: const Text('Share Full Order Insights PDF'),
                        onTap: () async {
                          Navigator.pop(context);
                          final generator = OrderPdfGenerator();
                          await generator.generateAndSharePDF(data, products);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.palette_outlined, color: Colors.deepOrange),
                        title: const Text('Share Product Customizations PDF'),
                        onTap: () async {
                          Navigator.pop(context);
                          // final generator = CustomizationPdfGenerator();
                          final generator = CustomizationPdfGeneratorAlt();
                          await generator.generateAndShareAltPdf(data, products);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Share PDF'),
            backgroundColor: Colors.indigo,
          ),
        );
      },
    );
  }
}
