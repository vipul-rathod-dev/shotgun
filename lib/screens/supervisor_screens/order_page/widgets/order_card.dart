import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/add_orders_page.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/order_details_insights_page.dart';
import '../helpers/status_color.dart'; // ✅ new import

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final id = orderData['orderNumber'] ?? 'N/A';
    final customer = orderData['customerName'] ?? 'Unknown';
    final Timestamp? timestamp = orderData['orderDate'];
    final date = timestamp != null
        ? DateFormat.yMMMd().format(timestamp.toDate())
        : 'No date';
    final status = orderData['orderStatus'] ?? 'Yet to Start';
    final color = StatusColor.fromStatus(status); // ✅ centralized logic

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.blue),
        title: Text("Order #$id"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: $customer"),
            Text("Date: $date"),
            Row(
              children: [
                const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'View',
              icon: const Icon(Icons.visibility, color: Colors.blue),
              onPressed: () => Navigator.push(
                context,
                // MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: orderId)),
                MaterialPageRoute(builder: (_) => OrderDetailsInsightsPage(orderId: orderId)),
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddOrdersPage(
                      isEditMode: true,
                      orderId: orderId,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Order'),
                    content: const Text('Are you sure you want to delete this order?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .delete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
