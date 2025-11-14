import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class RawProcessPage extends StatefulWidget {
  final String companyId;
  final String orderId;
  final Map<String, dynamic> orderData;

  const RawProcessPage({
    super.key,
    required this.companyId,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<RawProcessPage> createState() => _RawProcessPageState();
}

class _RawProcessPageState extends State<RawProcessPage> {
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _productEntries = [];
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _selectedStaff; // temporary UI selection only
  List<Map<String, dynamic>> _staffList = [];
  bool _loadingStaff = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchStaff();
  }

  @override
  void dispose() {
    for (var entry in _productEntries) {
      final controller = entry['quantityController'] as TextEditingController?;
      controller?.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products')
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'displayName': data['displayName'] ?? data['name'] ?? 'Unnamed',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _products.addAll(products);
          // ensure at least one entry exists (original behaviour)
          if (_productEntries.isEmpty) _addProductEntry();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      final staff = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed',
          'email': data['email'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _staffList = staff;
          _loadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStaff = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load staff: $e')),
        );
      }
    }
  }

  void _addProductEntry() {
    final controller = TextEditingController();
    setState(() {
      _productEntries.add({'product': null, 'quantityController': controller});
    });

    // scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _removeProductEntry(int index) {
    final controller = _productEntries[index]['quantityController'] as TextEditingController?;
    controller?.dispose();
    setState(() {
      _productEntries.removeAt(index);
    });
  }

  Future<void> _startColorProcess() async {
    // validate staff selection (still required but not persisted)
    if (_selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a staff member')),
      );
      return;
    }

    // validate products & quantities
    for (var entry in _productEntries) {
      final controller = entry['quantityController'] as TextEditingController?;
      if (entry['product'] == null || controller == null || controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all product fields')),
        );
        return;
      }
    }

    final rawProcessData = _productEntries.map((entry) {
      final controller = entry['quantityController'] as TextEditingController;
      return {
        'productId': entry['product']['id'],
        'productName': entry['product']['displayName'],
        'quantity': controller.text.trim(),
      };
    }).toList();

    try {
      // NOTE: assigned staff is intentionally NOT saved to Firestore (temporary UI selection only)
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'orderStatus': 'Color Process',
        'rawProcess': {
          'products': rawProcessData,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved to Color Process successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget is designed to be embedded inside a parent (e.g. OrderDashboardPage)
    // which should give it bounded height (e.g. by wrapping in Expanded).
    // The layout here uses a bounded inner ListView (SizedBox) to avoid infinite constraints.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Raw Process Setup',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey[900],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select products, quantities, and assign staff before moving to color process.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 20),

          // --- Assign Staff Dropdown (temporary selection only) ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign Staff',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _loadingStaff
                      ? const Center(child: CircularProgressIndicator())
                      : SearchableDropdown(
                          key: const ValueKey('staff_dropdown'),
                          items: _staffList,
                          keyName: 'name',
                          labelText: 'Select Staff',
                          value: _selectedStaff,
                          onChanged: (value) => setState(() => _selectedStaff = value),
                        ),
                  const SizedBox(height: 6),
                  // Small hint to remind it's temporary
                  const Text(
                    'Note: Assigned staff is selected locally (not saved yet).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Product Entries Section ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add Raw Materials',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bounded height ListView to avoid infinite height in scrollable parent
                  SizedBox(
                    height: 275,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _productEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _productEntries[index];
                        final isLast = index == _productEntries.length - 1;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            elevation: 1,
                            margin: EdgeInsets.zero,
                            color: Colors.grey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: SearchableDropdown(
                                      key: ValueKey('product_${index}_${entry.hashCode}'),
                                      items: _products,
                                      keyName: 'displayName',
                                      labelText: 'Product',
                                      value: entry['product'],
                                      onChanged: (value) => setState(() => entry['product'] = value),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: CustomTextField(
                                      controller: entry['quantityController'],
                                      hintText: 'Qty',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLast)
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 26),
                                          onPressed: _addProductEntry,
                                        ),
                                      if (_productEntries.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 26),
                                          onPressed: () => _removeProductEntry(index),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Start Process Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.color_lens_rounded),
              label: const Text('Start Color Process'),
              onPressed: _startColorProcess,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Order Summary Section
          Row(
            children: const [
              Icon(Icons.inventory_2_rounded, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Order Products Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(thickness: 1, height: 20),
          const SizedBox(height: 8),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _buildOrderSummary(),
          ),
        ],
      ),
    );
  }

  // --- Build Order Summary ---
  Widget _buildOrderSummary() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('orders')
          .doc(widget.orderId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final orderData = snapshot.data!.data() as Map<String, dynamic>?;
        if (orderData == null || orderData['products'] == null) {
          return const Center(child: Text('No products found for this order'));
        }

        final List products = orderData['products'];
        final productCustomizations = orderData['productCustomizations'] ?? {};

        return ListView.builder(
          shrinkWrap: true,
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final name = p['productName'] ?? 'Unknown';
            final modelGender = p['modelGender'];
            final boxQuantity = orderData['boxQuantity'][modelGender] ?? 0;
            final orderQuantity = p["quantity"] ?? 0;
            final totalBoxQuantity = boxQuantity != 0 ? (orderQuantity / boxQuantity) : 0;
            final customizations = productCustomizations[modelGender] ?? [];

            var totalFocus = {'Black': 0, 'Clear': 0, 'PC': 0};
            var totalTemple = {'Black': 0, 'Clear': 0, 'PC': 0};

            for (var cust in customizations) {
              final qty = int.tryParse(cust['focusQty'].toString()) ?? 0;
              final focusBase = cust['focusBaseMaterial'] ?? '';
              final templeBase = cust['templeBaseMaterial'] ?? '';
              totalFocus[focusBase] = (totalFocus[focusBase] ?? 0) + qty;
              totalTemple[templeBase] = (totalTemple[templeBase] ?? 0) + qty;
            }

            totalFocus = totalFocus.map((k, v) => MapEntry(k, (v * totalBoxQuantity).toInt()));
            totalTemple = totalTemple.map((k, v) => MapEntry(k, (v * totalBoxQuantity).toInt()));

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ExpansionTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.blueAccent),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text(
                  "Model: $modelGender • Boxes: ${totalBoxQuantity.toStringAsFixed(1)}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildColorRow('Focus', totalFocus),
                  const SizedBox(height: 8),
                  _buildColorRow('Temple', totalTemple),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorRow(String title, Map<String, int> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            "$title:",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: data.entries.map((e) {
              final colorMap = {
                'Black': Colors.black,
                'Clear': Colors.grey.shade300,
                'PC': Colors.blue.shade200,
              };
              return Chip(
                label: Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(
                    color: e.key == 'Clear' ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: colorMap[e.key],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
