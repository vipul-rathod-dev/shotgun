// widgets/order_status_badge.dart
import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  final String? status;
  const OrderStatusBadge({super.key, this.status});

  Color _statusToBadgeColor(String? status) {
    if (status == null) return Colors.grey.shade600;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return Colors.teal.shade700;
    if (s.contains('packing')) return Colors.orange.shade700;
    if (s.contains('demo')) return Colors.purple.shade600;
    if (s.contains('fitting')) return Colors.indigo.shade600;
    if (s.contains('quality')) return Colors.blue.shade600;
    if (s.contains('color')) return Colors.pink.shade400;
    if (s.contains('raw')) return Colors.amber.shade700;
    if (s.contains('received')) return Colors.green.shade600;

    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final label = (status ?? 'Unknown').toUpperCase();
    final color = _statusToBadgeColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
