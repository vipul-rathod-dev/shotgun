// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewInventoryPage extends StatefulWidget {
  const ViewInventoryPage({super.key});

  @override
  State<ViewInventoryPage> createState() => _ViewInventoryPageState();
}

class _ViewInventoryPageState extends State<ViewInventoryPage> {
  Future<List<Map<String, dynamic>>>? _inventoryFuture;
  String _searchQuery = '';
  String? _cachedCompanyId;
  String _sortOption = 'name'; // default sort

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedCompanyId = prefs.getString('cachedCompanyId');
    _sortOption = prefs.getString('inventorySortOption') ?? 'name';
    setState(() {
      _inventoryFuture = _fetchInventory();
    });
  }

  Future<void> _saveSortPreference(String sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventorySortOption', sort);
  }

  Future<List<Map<String, dynamic>>> _fetchInventory() async {
    if (_cachedCompanyId == null) {
      final prefs = await SharedPreferences.getInstance();
      _cachedCompanyId = prefs.getString('cachedCompanyId');
      if (_cachedCompanyId == null) {
        throw Exception('cachedCompanyId not found. Please log in again.');
      }
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_cachedCompanyId)
        .collection('products')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['displayName'] ?? 'Unnamed Product',
        'category': data['category'] ?? '—',
        'stock': data['stock'] ?? 0,
      };
    }).toList();
  }

  Future<void> _refreshInventory() async {
    // Fetch the data first (await outside of setState)
    final future = _fetchInventory();

    // Then update state synchronously
    setState(() {
      _inventoryFuture = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Inventory',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 6,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            tooltip: 'Add / Remove Inventory',
            icon:
                const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
            onPressed: () => _showAddRemoveInventoryDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _showAddRemoveInventoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Adjust Inventory'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshInventory,
        child: Column(
          children: [
            _buildSearchAndSortRow(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _inventoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: Colors.blueAccent));
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading inventory: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No inventory items found.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  List<Map<String, dynamic>> filtered = snapshot.data!.where((item) {
                    return item['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                  }).toList();

                  filtered = _applySorting(filtered);

                  return _buildInventoryList(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded, color: Colors.blueAccent),
            onSelected: (value) async {
              setState(() => _sortOption = value);
              await _saveSortPreference(value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha,
                        color:
                            _sortOption == 'name' ? Colors.blue : Colors.black54),
                    const SizedBox(width: 8),
                    const Text('Sort by Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'low_stock',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward,
                        color: _sortOption == 'low_stock'
                            ? Colors.blue
                            : Colors.black54),
                    const SizedBox(width: 8),
                    const Text('Low → High Stock'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'high_stock',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward,
                        color: _sortOption == 'high_stock'
                            ? Colors.blue
                            : Colors.black54),
                    const SizedBox(width: 8),
                    const Text('High → Low Stock'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> list) {
    switch (_sortOption) {
      case 'low_stock':
        list.sort((a, b) => (a['stock'] ?? 0).compareTo(b['stock'] ?? 0));
        break;
      case 'high_stock':
        list.sort((a, b) => (b['stock'] ?? 0).compareTo(a['stock'] ?? 0));
        break;
      case 'name':
      default:
        list.sort((a, b) =>
            (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    }
    return list;
  }

  Widget _buildInventoryList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final stock = item['stock'] ?? 0;
        final bool isLowStock = stock <= 5;

        final Color badgeColor = isLowStock
            ? Colors.red[100]!
            : stock <= 20
                ? Colors.amber[100]!
                : Colors.green[100]!;

        final Color textColor = isLowStock
            ? Colors.red[800]!
            : stock <= 20
                ? Colors.orange[800]!
                : Colors.green[800]!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor,
                  child: Icon(Icons.inventory_2_rounded, color: textColor),
                ),
                if (isLowStock)
                  const Positioned(
                    right: -4,
                    top: -4,
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                  ),
              ],
            ),
            title: Text(
              item['name'],
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              'Category: ${item['category']}',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Stock: $stock',
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🧩 Existing Add/Remove Inventory dialog stays unchanged
  void _showAddRemoveInventoryDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');
    if (companyId == null) return;

    final productSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('products')
        .get();

    final productList = productSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['displayName'] ?? 'Unnamed Product',
        'stock': data['stock'] ?? 0,
      };
    }).toList();

    String? selectedProductId;
    bool isAddOperation = true;
    final TextEditingController stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Adjust Inventory'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    items: productList.map((product) {
                      return DropdownMenuItem<String>(
                        value: product['id'],
                        child: Text(product['name']),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedProductId = value),
                    decoration: const InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Remove'),
                      Switch(
                        value: isAddOperation,
                        onChanged: (value) =>
                            setState(() => isAddOperation = value),
                        activeColor: Colors.green,
                      ),
                      const Text('Add'),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(stockController.text.trim()) ?? 0;
                if (selectedProductId == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Select a product and valid quantity.')));
                  return;
                }

                final productRef = FirebaseFirestore.instance
                    .collection('companies')
                    .doc(companyId)
                    .collection('products')
                    .doc(selectedProductId);

                await FirebaseFirestore.instance
                    .runTransaction((transaction) async {
                  final snapshot = await transaction.get(productRef);
                  if (!snapshot.exists) return;
                  final currentStock = snapshot['stock'] ?? 0;
                  final newStock = isAddOperation
                      ? currentStock + quantity
                      : (currentStock - quantity).clamp(0, double.infinity);
                  transaction.update(productRef, {'stock': newStock});
                });

                Navigator.pop(context);
                _refreshInventory();

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor:
                      isAddOperation ? Colors.green : Colors.redAccent,
                  content: Row(
                    children: [
                      Icon(
                        isAddOperation
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(isAddOperation
                          ? 'Added +$quantity units successfully!'
                          : 'Removed -$quantity units successfully!'),
                    ],
                  ),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
