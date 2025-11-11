import 'package:flutter/material.dart';

class ColorProcessPage extends StatelessWidget {
  final String companyId;
  final String orderId;
  final Map<String, dynamic> orderData;

  const ColorProcessPage({
    super.key,
    required this.companyId,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Raw Process Step',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Order ID: $orderId'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Start Color Process'),
                onPressed: () {
                  // Example: Move order status forward (Firestore update here)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Moving to Color Process...')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
