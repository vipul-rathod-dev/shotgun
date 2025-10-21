import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shotgun/screens/admin_screens/order_page/order_details_page.dart';

class ManageOrdersPage extends StatelessWidget {
  const ManageOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.lightBlue,
        actions: [
          TextButton.icon(
            onPressed: () {
              // Navigate to the New Order creation page
              Navigator.pushNamed(context, '/admin/orders/new');
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "New Order",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!.docs;

          Color getStatusColor(String status) {
            switch (status.toLowerCase()) {
              case 'yet to start':
                return Colors.grey;
              case 'in progress':
                return Colors.orange;
              case 'ready to ship':
                return Colors.blue;
              case 'completed':
                return Colors.green;
              default:
                return Colors.black;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final orderId = data['orderNumber'] ?? 'N/A';
              final customer = data['customerName'] ?? 'Unknown';
              final Timestamp? timestamp = data['orderDate'];
              final formattedDate = timestamp != null
                  ? DateFormat.yMMMd().format(timestamp.toDate())
                  : 'No date';

              final status = data['status'] ?? 'Yet to Start';
              final statusColor = getStatusColor(status);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.blue),
                  title: Text("Order #$orderId"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Customer: $customer"),
                      Text("Date: $formattedDate"),
                      Row(
                        children: [
                          const Text(
                            "Status: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsPage(orderId: orders[index].id),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/admin/orders/edit',
                            arguments: orders[index].id,
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
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('orders')
                                .doc(orders[index].id)
                                .delete();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
