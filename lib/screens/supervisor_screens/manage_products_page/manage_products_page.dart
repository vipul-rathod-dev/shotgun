// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/paginated_product_list.dart';

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
  String? selectedRawType; // 🔹 for Raw products
  String? selectedFinishedType; // 🔹 for Finished products
  late TabController _tabController;
  int _reloadKey = 0;

  final List<String> rawTypes = ['Black', 'Clear', 'PC'];
  final List<String> finishedTypes = ['Gents', 'Ladies', 'Baby'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        selectedCategory = _tabController.index == 0 ? 'Raw' : 'Finished';
        selectedRawType = null; // reset type when switching tabs
        selectedFinishedType = null; // reset type when switching tabs
      });
    });
  }

  Future<void> addProduct() async {
    final baseName = _nameController.text.trim();
    if (baseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required')),
      );
      return;
    }

    final name = selectedCategory == 'Finished'
        ? baseName
        : '$baseName - $selectedRawType';

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

    if (selectedCategory == 'Raw' && selectedRawType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a type for Raw product')),
      );
      return;
    }

    print(selectedFinishedType);

    if (selectedCategory == 'Finished' && selectedFinishedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a type for Finished product')),
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

    // ✅ Duplicate check only within same category & type
    Query<Map<String, dynamic>> query = productsRef
        .where('name', isEqualTo: lowercaseName)
        .where('category', isEqualTo: selectedCategory);

    if (selectedCategory == 'Raw') {
      query = query.where('type', isEqualTo: selectedRawType);
    } else {
      query = query.where('modelGender', isEqualTo: selectedFinishedType);
    }

    final duplicateQuery = await query.get();

    if (duplicateQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selectedCategory == 'Raw'
              ? 'Product "$name" with type "$selectedRawType" already exists.'
              : 'Product "$name" already exists.'),
        ),
      );
      return;
    }

    // ✅ Add new product (with type only for Raw)
    final productData = {
      'name': lowercaseName,
      'displayName': name,
      'price': price,
      'category': selectedCategory,
      if (selectedCategory == 'Raw') 'type': selectedRawType,
      if (selectedCategory == 'Finished') 'modelGender': selectedFinishedType,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await productsRef.add(productData);

    _nameController.clear();
    _priceController.clear();
    setState(() {
      _reloadKey++;
      selectedRawType = null;
      selectedFinishedType = null;
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
                          selectedRawType = null;
                        });
                      },
                    ),

                    // 🔽 Type dropdown visible only for Raw category
                    if (selectedCategory == 'Raw') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRawType,
                        items: rawTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        decoration: const InputDecoration(
                          labelText: 'Material Type',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            selectedRawType = value;
                          });
                        },
                      ),
                    ] else if (selectedCategory == 'Finished') ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedFinishedType,
                        items: finishedTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        decoration: const InputDecoration(
                          labelText: 'Finished Type',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            selectedFinishedType = value;
                          });
                        },
                      ),
                    ],

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
