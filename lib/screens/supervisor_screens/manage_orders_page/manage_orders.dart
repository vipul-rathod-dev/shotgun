import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/order_card.dart';

class ManageOrdersPage extends StatefulWidget {
  const ManageOrdersPage({super.key});

  @override
  State<ManageOrdersPage> createState() => _ManageOrdersPageState();
}

class _ManageOrdersPageState extends State<ManageOrdersPage> {
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyId = prefs.getString('cachedCompanyId');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.lightBlue,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/supervisor/orders/new'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "New Order",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .collection('orders')
            .orderBy('orderNumber', descending: true)
            .snapshots(),
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

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              return OrderCard(
                orderId: orders[index].id,
                orderData: data,
              );
            },
          );
        },
      ),
    );
  }
}
