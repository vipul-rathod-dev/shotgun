import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> showAddInventoryDialog(
  BuildContext context, {
  required String productId,
  required String productName,
  required List<String> moldingSuppliers,
  required List<String> drummingSuppliers,
}) async {
  final quantityController = TextEditingController();
  String? selectedMoldingSupplier;
  String? selectedDrummingSupplier;

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Add Inventory for "$productName"'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.add_box),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMoldingSupplier,
                decoration: const InputDecoration(
                  labelText: 'Molding Supplier',
                  prefixIcon: Icon(Icons.precision_manufacturing),
                ),
                items: moldingSuppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => selectedMoldingSupplier = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDrummingSupplier,
                decoration: const InputDecoration(
                  labelText: 'Drumming Supplier',
                  prefixIcon: Icon(Icons.oil_barrel),
                ),
                items: drummingSuppliers
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => selectedDrummingSupplier = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text.trim());
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid quantity')),
                );
                return;
              }

              await FirebaseFirestore.instance.collection('inventory').add({
                'productId': productId,
                'productName': productName,
                'quantity': quantity,
                'moldingSupplier': selectedMoldingSupplier ?? '',
                'drummingSupplier': selectedDrummingSupplier ?? '',
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inventory added successfully')),
              );
            },
          ),
        ],
      );
    },
  );
}
