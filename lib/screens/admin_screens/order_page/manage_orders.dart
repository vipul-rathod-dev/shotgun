import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final orderId = data['orderNumber'];
              // final status = data['status'] ?? 'Pending';
              final customer = data['customerName'] ?? 'Unknown';
              final date = (data['orderDate'] as Timestamp?)?.toDate();
              // final createdAt = (data['timestamp'] as Timestamp?)?.toDate();

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
                      if (date != null)
                        Text("Date: ${date}"),
                      // Text("Status: $status"),
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