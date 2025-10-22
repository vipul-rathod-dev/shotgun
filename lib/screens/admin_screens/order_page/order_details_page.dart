import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  Future<void> _editProductQuantity(
      List<dynamic> products, int index, int currentQty) async {
    final TextEditingController controller =
        TextEditingController(text: currentQty.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final enteredQty = int.tryParse(controller.text);
              if (enteredQty != null && enteredQty > 0) {
                Navigator.pop(context, enteredQty);
              } else {
                // Invalid input - could show error here
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );

    if (result != null) {
      products[index]['quantity'] = result;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'products': products});
    }
  }

  Future<void> _deleteProduct(List<dynamic> products, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      products.removeAt(index);
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'products': products});
    }
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

          final orderDoc = snapshot.data!;
          final data = orderDoc.data() as Map<String, dynamic>;

          final customer = data['customerName'] ?? 'Unknown';
          final orderDate = data['orderDate'] as Timestamp?;
          final shippingDate = data['shippingDate'] as Timestamp?;
          final productSelections = data['products'] as List<dynamic>? ?? [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text('Order Summary',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Customer: $customer', style: const TextStyle(fontSize: 16)),
                Text('Order Date: ${formatDate(orderDate)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey)),
                Text('Shipping Date: ${formatDate(shippingDate)}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                const Text('Products:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (productSelections.isEmpty)
                  const Text('No products found in this order.'),
                ...productSelections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  final productName = product['productName'] ?? 'Unnamed Product';
                  final quantity = product['quantity'] ?? 0;

                  final List<dynamic> customizations =
                      product['customizations'] as List<dynamic>? ?? [];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$productName (Qty: $quantity)',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit Quantity',
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _editProductQuantity(productSelections, index, quantity),
                              ),
                              IconButton(
                                tooltip: 'Delete Product',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _deleteProduct(productSelections, index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (customizations.isEmpty)
                            const Text('No customizations added.',
                                style: TextStyle(color: Colors.grey)),
                          if (customizations.isNotEmpty)
                            Table(
                              border: TableBorder.all(color: Colors.grey),
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(1),
                              },
                              children: [
                                TableRow(
                                  decoration:
                                      BoxDecoration(color: Colors.grey.shade300),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Color',
                                          style:
                                              TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Color Qty',
                                          style:
                                              TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Temple',
                                          style:
                                              TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text('Temple Qty',
                                          style:
                                              TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                ...customizations.map((c) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(c['colorName'] ?? ''),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text('${c['colorQty'] ?? 0}'),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(c['templeName'] ?? ''),
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
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}