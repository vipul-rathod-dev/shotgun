// widgets/product_card.dart
import 'package:flutter/material.dart';
import 'product_customizations_list.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> orderData;

  const ProductCard({super.key, required this.product, required this.orderData});

  @override
  Widget build(BuildContext context) {
    final productName = product['productName'] ?? 'Unnamed Product';
    final qty = product['quantity'] ?? 0;
    final price = (product['price'] ?? 0);
    final totalAmount = (qty * price);

    final double grandTotal = (orderData['products'] as List<dynamic>).fold(0.0, (sum, p) {
      final qty = (p['quantity'] ?? 0) as num;
      final price = (p['price'] ?? 0) as num;
      return sum + (qty * price);
    });

    final productCustomizations = (orderData['productCustomizations'] ?? {});
    final modelGender = product['modelGender'];
    final boxQtyMap = (orderData['boxQuantity'] ?? {});
    final perModelOrderQty = boxQtyMap[modelGender] == null || boxQtyMap[modelGender] == 0
        ? qty
        : (qty / (boxQtyMap[modelGender] as num));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$productName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Qty: $qty',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price: ₹${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
                  Text('Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 10),
              if (productCustomizations.isEmpty)
                const Text('No customizations', style: TextStyle(color: Colors.grey))
              else
                ProductCustomizationsList(
                  customizations: (productCustomizations[modelGender] ?? []) as List<dynamic>,
                  perModelOrderQty: perModelOrderQty,
                ),
              if (product['remarks'] != null && (product['remarks'] as String).trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Remarks: ${product['remarks']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('₹${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
