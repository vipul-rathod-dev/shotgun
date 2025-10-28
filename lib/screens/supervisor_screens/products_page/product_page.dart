// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/products_page/widgets/product_list/paginated_product_list.dart';

class ManageProductPage extends StatefulWidget {
  const ManageProductPage({super.key});

  @override
  State<ManageProductPage> createState() => _ManageProductPageState();
}

class _ManageProductPageState extends State<ManageProductPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String selectedCategory = 'Raw';
  late TabController _tabController;
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        selectedCategory = _tabController.index == 0 ? 'Raw' : 'Finished';
      });
    });
  }

  Future<void> addProduct() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required')),
      );
      return;
    }

    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');

    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company ID not found')),
      );
      return;
    }

    final productsRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('products');

    final lowercaseName = name.toLowerCase();

    // ✅ GLOBAL DUPLICATE CHECK (across all categories)
    final duplicateQuery = await productsRef.get();
    final duplicateExists = duplicateQuery.docs.any((doc) {
      final existingName = (doc['name'] ?? '').toString().toLowerCase();
      return existingName == lowercaseName;
    });

    if (duplicateExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product "$name" already exists in another category')),
      );
      return;
    }

    // ✅ Add new product
    final productData = {
      'name': lowercaseName, // used for comparisons/search
      'displayName': name, // preserves case for display
      'price': price,
      'category': selectedCategory,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await productsRef.add(productData);

    _nameController.clear();
    _priceController.clear();

    setState(() {
      _reloadKey++; // triggers list refresh
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product added successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: Colors.lightBlue,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Raw'),
            Tab(text: 'Finished'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🔽 Add Product Form
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: ['Raw', 'Finished'].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: addProduct,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔽 Tabbed Product List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PaginatedProductList(
                  key: ValueKey('Raw-$_reloadKey'),
                  category: 'Raw',
                ),
                PaginatedProductList(
                  key: ValueKey('Finished-$_reloadKey'),
                  category: 'Finished',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
