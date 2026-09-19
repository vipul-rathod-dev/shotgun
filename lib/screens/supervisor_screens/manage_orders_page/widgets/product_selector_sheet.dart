import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class ProductSelectorSheet extends StatefulWidget {
  const ProductSelectorSheet({super.key});

  @override
  State<ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<ProductSelectorSheet> {
  String? _companyId;

  final TextEditingController _searchController = TextEditingController();

  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];

  // Selected product IDs
  final Set<String> _selectedProductIds = {};

  // Quantity controllers for each selected product
  final Map<String, TextEditingController> _quantityControllers = {};

  // Price controllers for each selected product
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadCompanyAndProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();

    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }

    for (final controller in _priceControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD COMPANY + PRODUCTS
  // ---------------------------------------------------------------------------

  Future<void> _loadCompanyAndProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null) {
        throw Exception('Company ID not found in cache');
      }

      if (!mounted) return;

      setState(() {
        _companyId = companyId;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('products')
          .orderBy('name')
          .get();

      if (!mounted) return;

      setState(() {
        _products = snapshot.docs;
        _filteredProducts = snapshot.docs;
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading products'),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  void _updateSearch(String query) {
    final lowerQuery = query.toLowerCase().trim();

    setState(() {
      _filteredProducts = _products.where((product) {
        final data = product.data() as Map<String, dynamic>;

        final name =
            (data['displayName'] ?? '').toString().toLowerCase();

        return name.contains(lowerQuery);
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // SELECT / UNSELECT PRODUCT
  // ---------------------------------------------------------------------------

  void _toggleProduct(QueryDocumentSnapshot product) {
    final productId = product.id;

    final data = product.data() as Map<String, dynamic>;

    setState(() {
      if (_selectedProductIds.contains(productId)) {
        // ---------------------------------------------------------------
        // UNSELECT
        // ---------------------------------------------------------------

        _selectedProductIds.remove(productId);

        _quantityControllers[productId]?.dispose();
        _priceControllers[productId]?.dispose();

        _quantityControllers.remove(productId);
        _priceControllers.remove(productId);
      } else {
        // ---------------------------------------------------------------
        // SELECT
        // ---------------------------------------------------------------

        _selectedProductIds.add(productId);

        final quantityController = TextEditingController(
          text: '1',
        );

        final priceController = TextEditingController(
          text: data['price']?.toString() ?? '',
        );

        _quantityControllers[productId] = quantityController;
        _priceControllers[productId] = priceController;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // VALIDATE + RETURN SELECTED PRODUCTS
  // ---------------------------------------------------------------------------

  void _submitSelection() {
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one product'),
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> selectedProducts = [];

    for (final product in _products) {
      final productId = product.id;

      if (!_selectedProductIds.contains(productId)) {
        continue;
      }

      final data = product.data() as Map<String, dynamic>;

      final quantityText =
          _quantityControllers[productId]?.text.trim() ?? '';

      final priceText =
          _priceControllers[productId]?.text.trim() ?? '';

      final quantity = int.tryParse(quantityText);
      final price = double.tryParse(priceText);

      // ---------------------------------------------------------------
      // QUANTITY VALIDATION
      // ---------------------------------------------------------------

      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a valid quantity for ${data['displayName'] ?? 'product'}',
            ),
          ),
        );
        return;
      }

      // ---------------------------------------------------------------
      // PRICE VALIDATION
      // ---------------------------------------------------------------

      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a valid price for ${data['displayName'] ?? 'product'}',
            ),
          ),
        );
        return;
      }

      selectedProducts.add({
        'productId': productId,
        'productName': data['displayName'] ?? 'Unnamed',
        'modelGender': data['modelGender'] ?? 'Unknown',
        'quantity': quantity,
        'price': price,
      });
    }

    if (selectedProducts.isEmpty) {
      return;
    }

    Navigator.pop(context, selectedProducts);
  }

  // ---------------------------------------------------------------------------
  // PRODUCT CARD
  // ---------------------------------------------------------------------------

  Widget _buildProductItem(
    QueryDocumentSnapshot product,
  ) {
    final data = product.data() as Map<String, dynamic>;

    final productId = product.id;

    final name = data['displayName'] ?? 'Unnamed';

    final modelGender = data['modelGender'] ?? 'Unknown';

    final price = data['price']?.toString() ?? '-';

    final stock = data['stock']?.toString() ?? '-';

    final isSelected = _selectedProductIds.contains(productId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Column(
          children: [
            CheckboxListTile(
              value: isSelected,
              onChanged: (_) {
                _toggleProduct(product);
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                name.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '$modelGender • ₹$price • Stock: $stock',
              ),
            ),

            if (isSelected)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Quantity',
                        icon: Icons.numbers,
                        controller: _quantityControllers[productId]!,
                        keyboardType: TextInputType.number,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: CustomTextField(
                        label: 'Price',
                        icon: Icons.currency_rupee,
                        controller: _priceControllers[productId]!,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom;

    if (_companyId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: bottomPadding + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Select Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // -----------------------------------------------------------
              // SEARCH
              // -----------------------------------------------------------

              CustomTextField(
                label: 'Search Products',
                icon: Icons.search,
                controller: _searchController,
                onChanged: _updateSearch,
              ),

              const SizedBox(height: 12),

              // -----------------------------------------------------------
              // SELECTED COUNT
              // -----------------------------------------------------------

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selectedProductIds.length} product${_selectedProductIds.length == 1 ? '' : 's'} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // -----------------------------------------------------------
              // PRODUCT LIST
              // -----------------------------------------------------------

              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(
                        child: Text('No products found'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductItem(
                            _filteredProducts[index],
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),

              // -----------------------------------------------------------
              // CONFIRM
              // -----------------------------------------------------------

              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text(
                  _selectedProductIds.isEmpty
                      ? 'Add Products'
                      : 'Add ${_selectedProductIds.length} Product${_selectedProductIds.length == 1 ? '' : 's'}',
                ),
                onPressed: _submitSelection,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    48,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}