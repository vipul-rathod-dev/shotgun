import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RawMaterialSelectionPage extends StatefulWidget {
  final String companyId;
  final String orderId;
  final String assignedStaffId;

  const RawMaterialSelectionPage({
    super.key,
    required this.companyId,
    required this.orderId,
    required this.assignedStaffId,
  });

  @override
  State<RawMaterialSelectionPage> createState() =>
      _RawMaterialSelectionPageState();
}

class _RawMaterialSelectionPageState extends State<RawMaterialSelectionPage> {
  bool loading = true;
  List<Map<String, dynamic>> rawProducts = [];
  List<Map<String, dynamic>> selectedRaw = [];
  List<Map<String, dynamic>> finishedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Step 1: Load finished order products
      final orderDoc = await firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('orders')
          .doc(widget.orderId)
          .get();

      final orderData = orderDoc.data();
      finishedProducts =
          List<Map<String, dynamic>>.from(orderData?['products'] ?? []);

      // Step 2: Load all raw materials
      final rawSnap = await firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('products')
          .where('category', isEqualTo: 'Raw')
          .get();

      rawProducts = rawSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => loading = false);
    }
  }

  void _toggleSelection(Map<String, dynamic> product) {
    setState(() {
      if (selectedRaw.contains(product)) {
        selectedRaw.remove(product);
      } else {
        selectedRaw.add(product);
      }
    });
  }

  Future<void> _createRawProcessOrder() async {
    if (selectedRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one raw material.')),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final rawOrderRef = firestore
          .collection('companies')
          .doc(widget.companyId)
          .collection('rawProcessOrders')
          .doc();

      await rawOrderRef.set({
        'originalOrderId': widget.orderId,
        'assignedStaffId': widget.assignedStaffId, // ✅ Include staff
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'rawMaterials': selectedRaw
            .map((r) => {
                  'rawProductId': r['id'],
                  'rawProductName': r['name'] ?? 'Unnamed Raw',
                  'requiredQty': r['defaultQty'] ?? 0,
                })
            .toList(),
        'finishedProducts': finishedProducts,
      });


      // Update order status
      await firestore
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId)
        .update({'orderStatus': 'Raw Process'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Raw Process Order Created!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Raw Process Order'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finished Products in this Order:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (var p in finishedProducts)
              ListTile(
                title: Text(p['productName'] ?? 'Unknown Product'),
                subtitle: Text('Qty: ${p['quantity']}'),
              ),
            const Divider(height: 30),
            const Text(
              'Select Required Raw Materials:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rawProducts.length,
                itemBuilder: (context, index) {
                  final raw = rawProducts[index];
                  final isSelected = selectedRaw.contains(raw);

                  return ListTile(
                    title: Text(raw['name'] ?? 'Unnamed Raw Product'),
                    subtitle:
                        Text('Category: ${raw['category'] ?? 'Unknown'}'),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(raw),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Create Raw Process Order'),
            onPressed: _createRawProcessOrder,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
