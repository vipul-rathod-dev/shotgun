import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shotgun/screens/admin_screens/order_page/models/order_pdf_data.dart';
import 'package:shotgun/utils/pdf_generator.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No date';
    return DateFormat.yMMMd().format(timestamp.toDate());
  }

  Future<void> _sharePdf(OrderPdfData orderData) async {
    // 🔹 Generate PDF bytes using your existing PdfGenerator utility
    final pdfBytes = await PdfGenerator.generateOrderPdf(orderData);

    // 🔹 Share PDF file using the printing package
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'Order_${orderData.customerName}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: Colors.lightBlue,
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
          final products = data['products'] as List<dynamic>? ?? [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Customer: ${data['customerName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 16)),
                Text('Order Date: ${formatDate(data['orderDate'])}',
                    style: const TextStyle(
                        fontSize: 16, color: Colors.blueGrey)),
                Text('Shipping Date: ${formatDate(data['shippingDate'])}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                const Text('Products:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (products.isEmpty)
                  const Text('No products found in this order.'),
                ...products.map((product) {
                  final name = product['productName'] ?? 'Unnamed Product';
                  final qty = product['quantity'] ?? 0;
                  final customizations =
                      product['customizations'] as List<dynamic>? ?? [];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name (Qty: $qty)',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (customizations.isEmpty)
                            const Text('No customizations added.',
                                style: TextStyle(color: Colors.grey)),
                          if (customizations.isNotEmpty)
                            Table(
                              border: TableBorder.all(color: Colors.grey),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(1),
                              },
                              children: [
                                const TableRow(
                                  decoration:
                                      BoxDecoration(color: Color(0xFFE0E0E0)),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Focus Color',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Focus Qty',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Temple Color',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Temple Qty',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                ...customizations.map((c) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(c['focusColor'] ?? ''),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text('${c['focusQty'] ?? 0}'),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(c['templeColor'] ?? ''),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text('${c['templeQty'] ?? 0}'),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final orderData = OrderPdfData.fromMap(data);
          return FloatingActionButton.extended(
            onPressed: () => _sharePdf(orderData),
            label: const Text('Share PDF'),
            icon: const Icon(Icons.share),
            backgroundColor: Colors.lightBlue,
          );
        },
      ),
    );
  }
}
