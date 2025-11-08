import 'package:flutter/material.dart';
import 'product_model.dart';

class ProductListView extends StatelessWidget {
  final List<ProductModel> products;
  final bool hasMore;
  final bool isLoading;
  final ScrollController controller;
  final String category;
  final Future<void> Function(String id) onDelete;

  const ProductListView({
    super.key,
    required this.products,
    required this.hasMore,
    required this.isLoading,
    required this.controller,
    required this.category,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return Center(child: Text('No $category products found.'));
    }

    return ListView.builder(
      controller: controller,
      itemCount: products.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == products.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final p = products[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Icon(
              category == 'Raw' ? Icons.settings_input_component : Icons.done_all,
              color: Colors.lightBlue,
            ),
            title: Text(p.displayName),
            subtitle: Text(
              '₹ ${p.price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDelete(p.id),
            ),
          ),
        );
      },
    );
  }
}
