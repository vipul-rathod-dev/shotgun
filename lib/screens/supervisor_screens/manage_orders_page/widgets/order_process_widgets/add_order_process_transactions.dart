import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';

class MaterialItem {
  String id;
  String name;
  double quantity;
  String unit;
  MaterialItem({required this.id, required this.name, required this.quantity, required this.unit});
}

class ProductItem {
  final String id; // or productName
  final String display;

  ProductItem({required this.id, required this.display});
}

class AddOrderProcessTransactionPage extends StatefulWidget {
  final String orderId;
  final String companyId;
  final String processType;
  final String processTitle;
  final String transactionType;
  final User currentUser;

  const AddOrderProcessTransactionPage({
    super.key,
    required this.orderId,
    required this.companyId,
    required this.processType,
    required this.processTitle,
    required this.transactionType,
    required this.currentUser,
  });

  @override
  State<AddOrderProcessTransactionPage> createState() => _AddOrderProcessTransactionPageState();
}

class _AddOrderProcessTransactionPageState extends State<AddOrderProcessTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _selectedMaterial;
  final _quantityCtrl = TextEditingController();
  String _unit = 'pcs';
  DateTime _date = DateTime.now();
  final _remarksCtrl = TextEditingController();
  List<MaterialItem> _materials = [];
  bool _isSaving = false;

  late Future<List<ProductItem>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
  }


  Future<List<ProductItem>> _fetchProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('products')
        .get();

    return snapshot.docs.map((doc) {
      final name = doc.data()['displayName'] ?? doc.id;
      final stock = doc.data()['stock'] ?? 0;
      return ProductItem(id: doc.id, display: '$name - $stock');
    }).toList();
  }

  void _addMaterial() {
    final name = _selectedMaterial;
    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 0.0;

    if (name == null || name.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product and enter valid quantity')),
      );
      return;
    }

    // Check if product already added
    final exists = _materials.any((m) => m.name == name['name']);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product has already been added')),
      );
      return;
    }

    setState(() {
      // _materials.add(MaterialItem(name: name['name'], quantity: qty, unit: _unit));
      _materials.add(MaterialItem(id: name['id'], name: name['name'], quantity: qty, unit: _unit));
      _selectedMaterial = null;
      _quantityCtrl.clear();
      _unit = 'pcs';
    });
  }



  @override
  void dispose() {
    _quantityCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one material')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('processTransactions')
          .doc(widget.orderId);

      // Prepare materials list
      final materialsList = _materials.map((m) => {
        'id': m.id,
        'name': m.name,
        'quantity': m.quantity,
        'unit': m.unit,
      }).toList();

      // Build dynamic field path, e.g. "processes.raw_material.incoming"
      final processType = {widget.transactionType: materialsList};

      final processes = {widget.processType: processType};

      await docRef.set({
        'orderId': widget.orderId,
        'companyId': widget.companyId,
        'createdBy': widget.currentUser.email ?? widget.currentUser.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': _date,
        'remarks': _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        'processes': processes,
      }, SetOptions(merge: true));

      // ✅ Update product stock only for raw_material outgoing
      if (widget.processType == 'raw_material' && widget.transactionType == 'outgoing') {
        final batch = FirebaseFirestore.instance.batch();
        for (var material in _materials) {
          final productRef = FirebaseFirestore.instance
              .collection('companies')
              .doc(widget.companyId)
              .collection('products')
              .doc(material.id);
          batch.update(productRef, {
            'stock': FieldValue.increment(-material.quantity),
          });
        }
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding transaction: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() {
      _date = t != null ? DateTime(d.year, d.month, d.day, t.hour, t.minute) : d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.transactionType} - ${widget.processTitle}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: FutureBuilder<List<ProductItem>>(
                      future: _productsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No products found');
                        }
                        return SearchableDropdown(
                          items: snapshot.data!.map((p) => {'name': p.display, 'id': p.id}).toList(),
                          keyName: 'name',
                          labelText: 'Select Product',
                          value: _selectedMaterial,
                          onChanged: (v) {
                            setState(() {
                              _selectedMaterial = v;
                            });
                          },
                        );
                        
                      },
                    ),
                  ),

                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      items: const [
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'mtr', child: Text('mtr')),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                      ],
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addMaterial),
                ],
              ),
              const SizedBox(height: 12),

              // Show added materials in a Card with scrollable list
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Added Materials',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(),
                      _materials.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('No materials added yet'),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _materials.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final m = _materials[index];
                                return ListTile(
                                  title: Text('${m.name}'),
                                  subtitle: Text('${m.quantity} ${m.unit}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _materials.removeAt(index));
                                    },
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              if (_materials.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Total Materials: ${_materials.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Align(
                      child: TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Clear all?'),
                              content: const Text('This will remove all added materials.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                              ],
                            ),
                          );
                          if (confirm == true) setState(() => _materials.clear());
                        },
                        child: const Text('Clear All'),
                      )
                    )
                  ],
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & Time'),
                subtitle: Text(dateFmt.format(_date)),
                trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: const Icon(Icons.save),
                label: const Text('Save All'),
              ),
              const SizedBox(height: 30),
              const Text(
                'Order Products Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot>(
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
                    return const Text('No products found for this order');
                  }

                  final List products = orderData['products'];
                  final productCustomizations = orderData['productCustomizations'] ?? {};

                  return Column(
                    children: products.map((p) {
                      final name = p['productName'] ?? 'Unknown';
                      final modelGender = p['modelGender'];
                      final boxQuantity = orderData['boxQuantity'][modelGender] ?? 0;
                      final orderQuantity = p["quantity"] ?? 0;
                      final totalBoxQuantity = boxQuantity != 0 ? (orderQuantity / boxQuantity) : 0;
                      final customizations = productCustomizations[modelGender] ?? [];


                      var totalFocusClearEachBox = 0;
                      var totalFocusBlackEachBox = 0;
                      var totalFocusPCEachBox = 0;
                      var totalTempleClearEachBox = 0;
                      var totalTempleBlackEachBox = 0;
                      var totalTemplePCEachBox = 0;
                      for (var cust in customizations) {
                        final qty = int.tryParse(cust['focusQty'].toString()) ?? 0;
                        final focusBase = cust['focusBaseMaterial'] ?? '';
                        final templeBase = cust['templeBaseMaterial'] ?? '';

                        if (focusBase == 'Clear') {
                          totalFocusClearEachBox += qty;
                        } else if (focusBase == 'Black') {
                          totalFocusBlackEachBox += qty;
                        } else {
                          totalFocusPCEachBox += qty;
                        }

                        if (templeBase == 'Clear') {
                          totalTempleClearEachBox += qty;
                        } else if (templeBase == 'Black') {
                          totalTempleBlackEachBox += qty;
                        } else {
                          totalTemplePCEachBox += qty;
                        }
                      }

                      final totalFocusBlack = (totalFocusBlackEachBox * totalBoxQuantity).toInt();
                      final totalFocusClear = (totalFocusClearEachBox * totalBoxQuantity).toInt();
                      final totalFocusPC = (totalFocusPCEachBox * totalBoxQuantity).toInt();
                      final totalTempleBlack = (totalTempleBlackEachBox * totalBoxQuantity).toInt();
                      final totalTempleClear = (totalTempleClearEachBox * totalBoxQuantity).toInt();
                      final totalTemplePC = (totalTemplePCEachBox * totalBoxQuantity).toInt();
                      return Card(
                        child: ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Focus: Black Qty: $totalFocusBlack  •  Clear Qty: $totalFocusClear  •  PC Qty: $totalFocusPC'),
                              Text('Temple: Black Qty: $totalTempleBlack  •  Clear Qty: $totalTempleClear  •  PC Qty: $totalTemplePC'),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}
