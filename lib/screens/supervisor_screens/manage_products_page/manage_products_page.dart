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
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _minimumStockController = TextEditingController(text: '0');
  final TextEditingController _openingStockController = TextEditingController(text: '0');


  String selectedCategory = 'Raw';
  String? selectedRawType; // 🔹 for Raw products
  String? selectedFinishedType; // 🔹 for Finished products
  late TabController _tabController;
  int _reloadKey = 0;

  bool _isAddProductExpanded = false;
  bool? _wasDesktop;

  final List<String> rawTypes = ['Black', 'Clear', 'PC'];
  final List<String> finishedTypes = ['Gents', 'Ladies', 'Baby'];

  String? selectedOtherType;

  final List<String> otherTypes = [
    'Raw Material',
    'Mold',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        selectedCategory = switch (_tabController.index) {
          0 => 'Raw',
          1 => 'Finished',
          _ => 'Other',
        };
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
    final productCode = _codeController.text.trim();

    if (selectedCategory == 'Finished' && productCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product code is required for Finished products')),
      );
      return;
    }

    final name = selectedCategory == 'Finished' || selectedCategory == 'Other'
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

    final minimumStockText =
    _minimumStockController.text.trim();

    final minimumStock = int.tryParse(minimumStockText);

    if (minimumStock == null || minimumStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid minimum stock',
          ),
        ),
      );
      return;
    }

    final openingStockText =
    _openingStockController.text.trim();

    final openingStock = int.tryParse(openingStockText);

    if (openingStock == null || openingStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid opening stock'),
        ),
      );
      return;
    }

    if (selectedCategory == 'Raw' && selectedRawType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a type for Raw product')),
      );
      return;
    }

    if (selectedCategory == 'Finished' && selectedFinishedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a type for Finished product')),
      );
      return;
    }

    if (selectedCategory == 'Other' && selectedOtherType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product type')),
      );
      return;
    }

    if (selectedCategory == 'Other' && _codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product code is required')),
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
      query = query.where(
        'type',
        isEqualTo: selectedRawType,
      );
    } else if (selectedCategory == 'Finished') {
      query = query.where(
        'modelGender',
        isEqualTo: selectedFinishedType,
      );
    } else if (selectedCategory == 'Other') {
      query = query.where(
        'type',
        isEqualTo: selectedOtherType,
      );
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
    final productData = <String, dynamic>{
      'name': lowercaseName,
      'displayName': name,
      'price': price,
      'category': selectedCategory,
      'stock': openingStock,
      'minimumStock': minimumStock,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (selectedCategory == 'Raw') {
      productData['type'] = selectedRawType;
    }

    if (selectedCategory == 'Finished') {
      productData['productCode'] = productCode;
      productData['modelGender'] = selectedFinishedType;
    }

    if (selectedCategory == 'Other') {
      productData['type'] = selectedOtherType;
      productData['productCode'] = productCode;
    }

    await productsRef.add(productData);

    _nameController.clear();
    _priceController.clear();
    _codeController.clear();
    _openingStockController.text = '0';
    _minimumStockController.text = '0';
    setState(() {
      _reloadKey++;
      selectedRawType = null;
      selectedFinishedType = null;

      // Collapse form after adding
      _isAddProductExpanded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product added successfully')),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    // Only change the accordion automatically when
    // crossing the 900px breakpoint.
    if (_wasDesktop != isDesktop) {
      _wasDesktop = isDesktop;
      _isAddProductExpanded = isDesktop;
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _codeController.dispose();
    _minimumStockController.dispose();
    _openingStockController.dispose();
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
            Tab(text: 'Other'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🔽 Add Product Form
          // 🔽 Responsive Add Product Accordion
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Card(
              elevation: 3,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // ─────────────────────────────
                  // Accordion Header
                  // ─────────────────────────────
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isAddProductExpanded = !_isAddProductExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_box_outlined,
                              color: Colors.lightBlue,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add Product',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isAddProductExpanded
                                      ? 'Enter product details'
                                      : 'Tap to add a new product',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          AnimatedRotation(
                            turns: _isAddProductExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─────────────────────────────
                  // Add Product Form
                  // ─────────────────────────────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                    sizeCurve: Curves.easeInOut,

                    crossFadeState: _isAddProductExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,

                    firstChild: const SizedBox(
                      width: double.infinity,
                      height: 0,
                    ),

                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        16,
                      ),
                      child: Column(
                        children: [
                          const Divider(),

                          const SizedBox(height: 8),

                          // Product Name
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              prefixIcon: Icon(Icons.label),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Product Code
                          if (selectedCategory == 'Finished') ...[
                            TextField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Product Code',
                                prefixIcon: Icon(
                                  Icons.confirmation_number,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                          ],

                          // Price
                          TextField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              prefixIcon: Icon(
                                Icons.currency_rupee,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Minimum Stock
                          TextField(
                            controller: _minimumStockController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Stock',
                              hintText: 'Enter minimum stock alert level',
                              prefixIcon: Icon(
                                Icons.inventory_2_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Opening Stock
                          TextField(
                            controller: _openingStockController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Opening Stock',
                              hintText: 'Enter initial stock quantity',
                              prefixIcon: Icon(
                                Icons.inventory_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Category
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            items: ['Raw', 'Finished', 'Other'].map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedCategory = value;
                                selectedRawType = null;
                                selectedFinishedType = null;
                              });
                            },
                          ),

                          // Raw Type
                          if (selectedCategory == 'Raw') ...[
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: selectedRawType,
                              items: rawTypes.map((type) {
                                return DropdownMenuItem<String>(
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
                          ]

                          // Finished Type
                          else if (selectedCategory == 'Finished') ...[
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: selectedFinishedType,
                              items: finishedTypes.map((type) {
                                return DropdownMenuItem<String>(
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
                          ]

                          else if (selectedCategory == 'Other') ...[
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: selectedOtherType,
                              items: otherTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              decoration: const InputDecoration(
                                labelText: 'Product Type',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  selectedOtherType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Product Code',
                                prefixIcon: Icon(Icons.qr_code_2_outlined),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Add Product Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: addProduct,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Add Product',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                PaginatedProductList(
                  key: ValueKey('Other-$_reloadKey'),
                  category: 'Other',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
