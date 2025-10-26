import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shotgun/screens/staff_screens/track_orders/utils/order_status_color.dart';

class OrderTile extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback onTap;

  const OrderTile({
    super.key,
    required this.orderId,
    required this.data,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customerName = data['customerName'] ?? 'Unknown';
    print(data['orderStatus']);
    final status = data['orderStatus'] ?? 'N/A';
    final total = (data['totalAmount'] ?? 0.0) as num;
    final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
    final color = status.toString().toLowerCase().statusColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.receipt_long, color: color),
        ),
        title: Text(
          customerName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Status: $status\nTotal: ₹${total.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              orderDate != null
                  ? DateFormat('dd MMM').format(orderDate)
                  : '--',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade500),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
