// widgets/order_header.dart
import 'package:flutter/material.dart';
// keep your existing timeline import route (project-specific)
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/order_timeline.dart';

import '../../controllers/order_details_controller.dart';
import 'order_status_badge.dart';

class OrderHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final String status;

  const OrderHeader({super.key, required this.data, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB3E5FC), Color(0xFF80DEEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar / icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Colors.indigo.shade400,
                    Colors.blue.shade300,
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['customerName'] ?? 'Unknown Customer'}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order ID: ${data['orderNumber']}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // status badge
                        OrderStatusBadge(status: data['orderStatus'] as String?),
                        const SizedBox(width: 12),
                        // Dates summary
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              OrderDetailsController().formatDate(data['orderDate']),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade800),
                            )
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Timeline (custom widget)
          OrderTimeline(
            status: status,
            orderType: data['orderType'] ?? 'Customized Order',
          ),
        ],
      ),
    );
  }
}
