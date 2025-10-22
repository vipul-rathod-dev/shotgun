import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/product_list.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/product_selector_sheet.dart';

class ProductTable extends StatefulWidget {
  final AddOrderController controller;

  const ProductTable({Key? key, required this.controller}) : super(key: key);

  @override
  State<ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<ProductTable> {
  final List<Map<String, dynamic>> _productSelections = [];

  /// ✅ Add Product
  Future<void> _addProduct() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProductSelectorSheet(),
    );

    if (result != null) {
      if (_productSelections.any((p) => p['productId'] == result['productId'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product already added')),
        );
      } else {
        setState(() {
          _productSelections.add(result);
          widget.controller.addProduct(result);
        });
      }
    }
  }

  /// ✅ Remove Product
  void _removeProduct(Map<String, dynamic> product) {
    setState(() {
      _productSelections.removeWhere((p) => p['productId'] == product['productId']);
      widget.controller.products.removeWhere((p) => p['productId'] == product['productId']);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['productName']} removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.controller.formKeys[2], // Linked to Step 3
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Hidden validator field ensures Stepper validation works
          TextFormField(
            validator: (_) {
              if (widget.controller.products.isEmpty) {
                return 'Please add at least one product before continuing';
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          ProductList(
            products: _productSelections,
            onRemove: _removeProduct,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
