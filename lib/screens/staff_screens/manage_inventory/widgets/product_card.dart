import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onAddInventory;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.doc,
    required this.onAddInventory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed';
    final category = data['category'] ?? 'Unknown';
    final price = data['price'];

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('inventory')
          .where('productId', isEqualTo: doc.id)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        int quantity = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final inventory = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          quantity = inventory['quantity'] ?? 0;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(
              category.toLowerCase() == 'raw'
                  ? Icons.settings_input_component
                  : Icons.done_all,
              color: Colors.lightBlue,
              size: 32,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: $category'),
                if (category == 'Finished' && price != null)
                  Text('Price: ₹$price'),
                Text('Quantity: $quantity'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
            onTap: onAddInventory,
          ),
        );
      },
    );
  }
}
