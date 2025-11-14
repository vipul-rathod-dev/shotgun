// widgets/order_stats_card.dart
import 'package:flutter/material.dart';

class OrderStatsCard extends StatelessWidget {
  final Map<String, int> totals;
  const OrderStatsCard({super.key, required this.totals});

  Widget _statItem({required String title, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.indigo.shade300,
              Colors.blue.shade200,
            ]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statItem(title: 'Products', value: '${totals['totalProducts']}', icon: Icons.widgets),
            _statItem(title: 'Quantity', value: '${totals['totalQty']}', icon: Icons.format_list_numbered),
            _statItem(title: 'Focus Qty', value: '${totals['totalFocus']}', icon: Icons.color_lens),
            _statItem(title: 'Temple Qty', value: '${totals['totalTemple']}', icon: Icons.straighten),
          ],
        ),
      ),
    );
  }
}
