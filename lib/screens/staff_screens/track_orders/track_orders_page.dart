import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/screens/staff_screens/track_orders/controllers/track_orders_controller.dart';
import 'package:shotgun/screens/staff_screens/track_orders/widgets/empty_state.dart';
import 'package:shotgun/screens/staff_screens/track_orders/widgets/order_tile.dart';

class TrackOrdersPage extends StatelessWidget {
  const TrackOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TrackOrdersController();

    return Scaffold(
      backgroundColor: controller.backgroundColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Track Orders',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState();
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;

              return OrderTile(
                orderId: orderId,
                data: data,
                isDark: controller.isDarkMode(context),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/order-details',
                  arguments: orderId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
