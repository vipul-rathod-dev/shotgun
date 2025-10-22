import 'package:flutter/material.dart';

class ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final void Function(Map<String, dynamic>) onRemove;

  const ProductList({
    Key? key,
    required this.products,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No products added yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: products.map((item) {
        final quantity = item['quantity'] ?? 0;
        final price = item['price'] ?? 0.0;
        final total = (quantity * price).toStringAsFixed(2);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1.5,
          child: ListTile(
            title: Text(
              item['productName'] ?? 'Unnamed Product',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Qty: $quantity × ₹$price  =  ₹$total',
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onRemove(item),
              tooltip: 'Remove Product',
            ),
          ),
        );
      }).toList(),
    );
  }
}
