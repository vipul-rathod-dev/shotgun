import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageInventoryPage extends StatefulWidget {
  const ManageInventoryPage({super.key});

  @override
  State<ManageInventoryPage> createState() => _ManageInventoryPageState();
}

class _ManageInventoryPageState extends State<ManageInventoryPage> {
  final CollectionReference _productsCollection =
      FirebaseFirestore.instance.collection('products');

  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  final int _limit = 10;
  List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  String _searchTerm = '';
  List<String> _moldingSuppliers = [];
  List<String> _drummingSuppliers = [];
  String? selectedMoldingSupplier;
  String? selectedDrummingSupplier;


  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _loadSuppliers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          !_isLoading &&
          _hasMore) {
        _fetchProducts();
      }
    });
  }

  Future<void> _loadSuppliers() async {
    final supplierSnapshot = await FirebaseFirestore.instance
        .collection('suppliers')
        .get();
    
    print(supplierSnapshot.docs);

    setState(() {
      _moldingSuppliers = supplierSnapshot.docs
          .where((doc) => doc['role'] == 'Molding')
          .map((doc) => doc['name'].toString())
          .toList();

      _drummingSuppliers = supplierSnapshot.docs
          .where((doc) => doc['role'] == 'Drumming')
          .map((doc) => doc['name'].toString())
          .toList();
    });
  }

  Future<void> _fetchProducts({bool clearPrevious = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    Query query = _productsCollection.orderBy('name').limit(_limit);

    if (_searchTerm.isNotEmpty) {
      String endTerm = '$_searchTerm\uf8ff';
      query = _productsCollection
          .orderBy('name')
          .where('name', isGreaterThanOrEqualTo: _searchTerm)
          .where('name', isLessThanOrEqualTo: endTerm)
          .limit(_limit);
    }

    if (_lastDocument != null && !clearPrevious) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (clearPrevious) {
      _products = [];
      _lastDocument = null;
      _hasMore = true;
    }

    if (snapshot.docs.length < _limit) {
      _hasMore = false;
    }

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _products.addAll(snapshot.docs);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteProduct(String docId) async {
    try {
      await _productsCollection.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );

      // Remove deleted product locally and refresh list
      _products.removeWhere((doc) => doc.id == docId);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $e')),
      );
    }
  }

  void _onSearchChanged() {
    final searchText = _searchController.text.trim();
    _searchTerm = searchText;

    // Reset pagination and reload products with search applied
    _lastDocument = null;
    _products = [];
    _hasMore = true;

    _fetchProducts(clearPrevious: true);
  }

  void _showAddInventoryDialog(String productId, String productName) {
    final TextEditingController quantityController = TextEditingController();
    // final TextEditingController moldingSupplierController = TextEditingController();
    // final TextEditingController drummingSupplierController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Inventory for "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    border: OutlineInputBorder(),
                  ),
                  items: _moldingSuppliers
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (value) {
                    selectedMoldingSupplier = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDrummingSupplier,
                  decoration: const InputDecoration(
                    labelText: 'Drumming Supplier',
                    prefixIcon: Icon(Icons.oil_barrel),
                    border: OutlineInputBorder(),
                  ),
                  items: _drummingSuppliers
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (value) {
                    selectedDrummingSupplier = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text.trim());
                final moldingSupplier = selectedMoldingSupplier ?? '';
                final drummingSupplier = selectedDrummingSupplier ?? '';


                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid quantity')),
                  );
                  return;
                }
                if (moldingSupplier.isEmpty && drummingSupplier.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter at least one supplier')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('inventory').add({
                    'productId': productId,
                    'productName': productName,
                    'quantity': quantity,
                    'moldingSupplier': moldingSupplier,
                    'drummingSupplier': drummingSupplier,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  await _fetchProducts(clearPrevious: true);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inventory added successfully')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
        backgroundColor: Colors.lightBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => {
            // Navigator.pop(context)
            Navigator.pushNamed(context, '/staff')
          },
        ),
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _onSearchChanged(),
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Product List with Pagination
          Expanded(
            child: _products.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _products.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final doc = _products[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final name = data['name'] ?? 'Unnamed product';
                          final category = data['category'] ?? 'Unknown';
                          final price = data['price'];

                          return FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('inventory')
                                .where('productId', isEqualTo: doc.id)
                                .limit(1)
                                .get(),
                            builder: (context, inventorySnapshot) {
                              int quantity = 0;

                              if (inventorySnapshot.hasData && inventorySnapshot.data!.docs.isNotEmpty) {
                                final inventoryData = inventorySnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                quantity = inventoryData['quantity'] ?? 0;
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    category.toString().toLowerCase() == 'raw'
                                        ? Icons.settings_input_component
                                        : Icons.done_all,
                                    color: Colors.lightBlue,
                                    size: 32,
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Category: $category'),
                                      if (category.toString() == 'Finished' && price != null)
                                        Text('Price: ₹$price'),
                                      Text('Quantity: $quantity'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmationDialog(doc.id, name),
                                  ),
                                  onTap: () => _showAddInventoryDialog(doc.id, name),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String docId, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(docId);
            },
          ),
        ],
      ),
    );
  }
}
