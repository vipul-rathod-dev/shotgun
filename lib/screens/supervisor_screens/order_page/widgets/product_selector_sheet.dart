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
  String? _selectedProductId;
  String? _selectedProductName;
  int _quantity = 1;
  double _price = 0;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();

  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadCompanyAndProducts();
  }

  Future<void> _loadCompanyAndProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null) {
        throw Exception('Company ID not found in cache');
      }

      setState(() => _companyId = companyId);

      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('products')
          .orderBy('name')
          .get();

      setState(() {
        _products = snapshot.docs;
        _filteredProducts = _products;
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading products')),
        );
      }
    }
  }

  void _updateSearch(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final data = product.data() as Map<String, dynamic>;
        final name = (data['displayName'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery);
      }).toList();
    });
  }

  void _submitSelection() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product')),
      );
      return;
    }
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than zero')),
      );
      return;
    }
    if (_price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid price')),
      );
      return;
    }

    Navigator.pop(context, {
      'productId': _selectedProductId,
      'productName': _selectedProductName,
      'quantity': _quantity,
      'price': _price,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    if (_companyId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const Text(
                'Select Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // ✅ Search Field
              CustomTextField(
                label: 'Search Products',
                icon: Icons.search,
                controller: _searchController,
                onChanged: _updateSearch,
              ),
              const SizedBox(height: 12),

              // ✅ Product List
              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final data = product.data() as Map<String, dynamic>;
                          final name = data['displayName'] ?? 'Unnamed';
                          final price = data['price']?.toString() ?? '-';
                          final stock = data['stock']?.toString() ?? '-';

                          return RadioListTile<String>(
                            title: Text(name),
                            subtitle: Text('₹$price • Stock: $stock'),
                            value: product.id,
                            groupValue: _selectedProductId,
                            onChanged: (value) {
                              setState(() {
                                _selectedProductId = value;
                                _selectedProductName = name;
                                _priceController.text =
                                    data['price']?.toString() ?? '';
                                _price =
                                    double.tryParse(_priceController.text) ?? 0;
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              // ✅ Quantity + Price Fields
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Quantity',
                      icon: Icons.numbers,
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _quantity = int.tryParse(value) ?? 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Price',
                      icon: Icons.currency_rupee,
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _price = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Confirm Button
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Add Product'),
                onPressed: _submitSelection,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
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
