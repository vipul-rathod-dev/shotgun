// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shotgun/screens/staff_screens/order_details/widgets/order_totals_card.dart';
import '../../staff_screens/order_details/utils/status_color.dart';
import '../../staff_screens/order_details/widgets/header_section.dart';
import '../../staff_screens/order_details/widgets/info_tile.dart';
import '../../staff_screens/order_details/widgets/item_card.dart';

class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({super.key});

  Future<void> _handleNextStep(
    BuildContext context,
    String orderId,
    String status,
  ) async {
    // 🧠 Step 1: Ask for confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Move to Next Stage?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to move this order to the next process?',
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: getStatusColor(status),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Move', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // user cancelled

    // 🧠 Step 2: Continue with status update
    final currentStatus = status.toLowerCase();
    const stages = [
      'received',
      'raw process',
      'color process',
      'quality check',
      'fitting process',
      'demo process',
      'packing',
      'shipping'
    ];
    final currentIndex = stages.indexOf(currentStatus);

    if (currentIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown status — cannot update.')),
      );
      return;
    }

    if (currentIndex == stages.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order is already completed ✅')),
      );
      return;
    }

    final nextStatus = stages[currentIndex + 1];
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'orderStatus': nextStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order moved to "$nextStatus" 🚀'),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final orderId = ModalRoute.of(context)?.settings.arguments as String?;
    if (orderId == null) {
      return const Scaffold(
        body: Center(child: Text('Invalid order ID')),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        title: Text(
          'Order Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Order not found 😕',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final customerName = order['customerName'] ?? 'N/A';
          final orderNumber = order['orderNumber'] ?? 'N/A';
          final status = order['orderStatus'] ?? 'N/A';
          final orderDate = (order['orderDate'] as Timestamp?)?.toDate();
          final items = (order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // 🧮 Totals
          final totalProducts = items.length;
          final totalQuantity = items.fold<int>(
            0,
            (sum, item) => sum + ((item['quantity'] ?? 0) as num).toInt(),
          );

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: getStatusColor(status),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Next Step',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _handleNextStep(context, orderId, status),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderSection(
                      customerName: customerName,
                      status: status,
                      color: getStatusColor(status),
                      textColor: textColor,
                    ),
                    const SizedBox(height: 20),

                    InfoTile(title: 'Order ID', value: orderNumber, textColor: textColor),
                    InfoTile(
                      title: 'Order Date',
                      value: orderDate != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(orderDate)
                          : '--',
                      textColor: textColor,
                    ),

                    const SizedBox(height: 25),

                    // 🌈 Enhanced Totals Card
                    OrderTotalsCard(
                      totalProducts: totalProducts,
                      totalQuantity: totalQuantity,
                      statusColor: getStatusColor(status),
                    ),

                    const SizedBox(height: 25),

                    Text(
                      'Items',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (items.isEmpty)
                      Text(
                        'No items listed in this order.',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      )
                    else
                      ...items.map((item) => ItemCard(
                            itemName: item['productName'] ?? 'Item',
                            qty: item['quantity'] ?? 0,
                            price: (item['price'] ?? 0).toDouble(),
                            customizations: (item['customizations'] as List?) ?? [],
                            statusColor: getStatusColor(status),
                            isDark: isDark,
                          )),

                    const SizedBox(height: 30),
                    Center(
                      child: Text(
                        'End of Order Details',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
