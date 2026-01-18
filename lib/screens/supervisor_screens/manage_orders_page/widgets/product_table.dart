import 'package:flutter/material.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/product_list.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/product_selector_sheet.dart';

class ProductTable extends StatefulWidget {
  final AddOrderController controller;

  const ProductTable({super.key, required this.controller});

  @override
  State<ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<ProductTable> {
  final List<Map<String, dynamic>> _productSelections = [];

  @override
  void initState() {
    super.initState();
    // ✅ When editing an existing order, load products from the controller
    if (widget.controller.products.isNotEmpty) {
      _productSelections.clear();
      _productSelections.addAll(widget.controller.products);
    }

    // ✅ Also listen for future changes in controller (optional)
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    // Keeps local list in sync if controller updates (like initEditMode)
    if (mounted) {
      setState(() {
        _productSelections
          ..clear()
          ..addAll(widget.controller.products);
      });
    }
  }

  Map<String, dynamic> computeMaterialBreakdown(
    Map<String, dynamic> p,
    Map<String, int> boxQuantity,
    Map<String, List<Map<String, dynamic>>> productCustomizations,
  ) {
    final gender = p['modelGender'];
    final qty = (p['quantity'] ?? 0).toDouble();

    final genderBoxQty = (boxQuantity[gender] ?? 0).toDouble();
    final ratio = genderBoxQty > 0 ? qty / genderBoxQty : 0.0;

    double fBlack = 0, fClear = 0, fPC = 0;
    double tBlack = 0, tClear = 0, tPC = 0;

    final customList = productCustomizations[gender] ?? [];

    for (final c in customList) {
      // ----------- FOCUS -----------
      final focusMat = c['focusBaseMaterial'];
      final fQty = ((c['focusQty'] ?? 0).toDouble() * ratio);

      if (focusMat == "Black") fBlack += fQty;
      if (focusMat == "Clear") fClear += fQty;
      if (focusMat == "PC")    fPC += fQty;

      // ----------- TEMPLE -----------
      final templeMat = c['templeBaseMaterial'];
      final tQty = ((c['templeQty'] ?? 0).toDouble() * ratio);

      if (templeMat == "Black") tBlack += tQty;
      if (templeMat == "Clear") tClear += tQty;
      if (templeMat == "PC")    tPC += tQty;
    }

    return {
      "focusBaseMaterialQuantities": {
        if (fBlack > 0) "Black": double.parse(fBlack.toStringAsFixed(1)),
        if (fClear > 0) "Clear": double.parse(fClear.toStringAsFixed(1)),
        if (fPC > 0)    "PC": double.parse(fPC.toStringAsFixed(1)),
      },
      "templeBaseMaterialQuantities": {
        if (tBlack > 0) "Black": double.parse(tBlack.toStringAsFixed(1)),
        if (tClear > 0) "Clear": double.parse(tClear.toStringAsFixed(1)),
        if (tPC > 0)    "PC": double.parse(tPC.toStringAsFixed(1)),
      }
    };
  }


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
          final breakdown = computeMaterialBreakdown(
            result,
            widget.controller.boxQuantity,
            widget.controller.productCustomizations,
          );

          final updatedProduct = {
            ...result,
            ...breakdown,
          };
          _productSelections.add(updatedProduct);
          widget.controller.addProduct(updatedProduct);
          // Product Result: {productId: RgGqHRItCyGo8GDh0uwk, productName: M:4045, modelGender: Ladies, quantity: 150, price: 45.0}
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
