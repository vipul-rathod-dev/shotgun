import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'order_process_transactions.dart';

class OrderProcessesDashboard extends StatelessWidget {
  final String orderId;
  final User currentUser;

  const OrderProcessesDashboard({
    super.key,
    required this.orderId,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final processes = [
      {'title': 'Raw Process', 'type': 'raw_material'},
      {'title': 'Color Process', 'type': 'color'},
      {'title': 'Quality Check', 'type': 'quality_check'},
      {'title': 'Fitting Process', 'type': 'fitting'},
      {'title': 'Demo Process', 'type': 'demo'},
      {'title': 'Packing Process', 'type': 'packing'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId - Processes'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: processes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) {
            final p = processes[i];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _openProcess(context, p),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title']!, style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                            onPressed: () => _openProcess(context, p),
                            child: const Text('Open'),
                          ),
                        ),
                      ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openProcess(BuildContext context, Map<String, String> process) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderProcessTransactionsPage(
          orderId: orderId,
          processType: process['type']!,
          processTitle: process['title']!,
          currentUser: currentUser,
        ),
      ),
    );
  }

}
