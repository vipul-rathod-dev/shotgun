import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supplier-side granule balance and issue/return ledger for molding suppliers.
/// Factory stock remains in companies/{companyId}/products.
class SupplierGranuleInventoryPage extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierGranuleInventoryPage({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierGranuleInventoryPage> createState() =>
      _SupplierGranuleInventoryPageState();
}

class _SupplierGranuleInventoryPageState
    extends State<SupplierGranuleInventoryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _quantityController = TextEditingController();
  String? _companyId;
  String? _selectedProductId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('companies').doc(_companyId).collection('products');

  DocumentReference<Map<String, dynamic>> get _balanceRef => _firestore
      .collection('companies')
      .doc(_companyId)
      .collection('labor_granules_balances')
      .doc(widget.supplierId);

  CollectionReference<Map<String, dynamic>> get _transactions => _firestore
      .collection('companies')
      .doc(_companyId)
      .collection('granule_transactions');

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('cachedCompanyId');
      if (id == null || id.trim().isEmpty) {
        throw Exception('Company information is not available. Please login again.');
      }
      if (!mounted) return;
      setState(() {
        _companyId = id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _str(dynamic value) => value?.toString().trim() ?? '';
  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_str(value)) ?? 0;
  }

  String _productName(Map<String, dynamic> data) =>
      _str(data['displayName']).isNotEmpty
          ? _str(data['displayName'])
          : (_str(data['name']).isNotEmpty ? _str(data['name']) : _str(data['productCode']));

  /// Expected names include "TR90 Black - Virgin" and "TR90 Black - Grinding".
  /// The returned key matches labor_granules_balances fields.
  String? _balanceField(Map<String, dynamic> data) {
    final name = '${data['displayName'] ?? ''} ${data['name'] ?? ''} ${data['productCode'] ?? ''}'
        .toLowerCase();
    final material = name.contains(RegExp(r'\bblack\b'))
        ? 'black'
        : name.contains(RegExp(r'\bclear\b'))
            ? 'clear'
            : name.contains(RegExp(r'\bpc\b'))
                ? 'pc'
                : null;
    final process = name.contains('virgin')
        ? 'VirginKg'
        : (name.contains('grinding') ? 'GrindingKg' : null);
    if (material == null || process == null) return null;
    return '$material$process';
  }

  Future<void> _issueGranules() async {
    if (_companyId == null || _selectedProductId == null || _saving) return;
    final qty = _double(_quantityController.text);
    if (qty <= 0) {
      _message('Enter a quantity greater than 0 kg.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Your session has expired. Please login again.');
      return;
    }

    setState(() => _saving = true);
    try {
      final productRef = _products.doc(_selectedProductId);
      final transactionRef = _transactions.doc();
      await _firestore.runTransaction((tx) async {
        // All reads happen before writes.
        final productSnapshot = await tx.get(productRef);
        final balanceSnapshot = await tx.get(_balanceRef);
        if (!productSnapshot.exists) throw Exception('Selected granule product no longer exists.');
        final product = productSnapshot.data()!;
        if (_str(product['type']).toLowerCase() != 'raw material') {
          throw Exception('Only Raw Material products can be issued as granules.');
        }
        final field = _balanceField(product);
        if (field == null) {
          throw Exception('Product name must identify material (Black/Clear/PC) and process (Virgin/Grinding).');
        }
        final stock = _double(product['stock']);
        if (stock + 0.000001 < qty) {
          throw Exception('Insufficient factory stock. Available: ${stock.toStringAsFixed(3)} kg.');
        }
        final balance = balanceSnapshot.data() ?? <String, dynamic>{};
        final currentBalance = _double(balance[field]);

        tx.update(productRef, {
          'stock': double.parse((stock - qty).toStringAsFixed(4)),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastIssuedToSupplierId': widget.supplierId,
          'lastIssuedToSupplierName': widget.supplierName,
        });
        tx.set(_balanceRef, {
          'laborId': widget.supplierId,
          'laborName': widget.supplierName,
          field: double.parse((currentBalance + qty).toStringAsFixed(4)),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedByUid': user.uid,
          'lastMovementType': 'Issue from factory',
        }, SetOptions(merge: true));
        tx.set(transactionRef, {
          'transactionType': 'Factory to Molding Supplier Issue',
          'status': 'Posted',
          'companyId': _companyId,
          'inventoryCollection': 'products',
          'inventoryProductId': productRef.id,
          'inventoryProductName': _productName(product),
          'supplierId': widget.supplierId,
          'supplierName': widget.supplierName,
          'balanceField': field,
          'quantityKg': qty,
          'factoryStockBeforeKg': stock,
          'factoryStockAfterKg': stock - qty,
          'supplierBalanceBeforeKg': currentBalance,
          'supplierBalanceAfterKg': currentBalance + qty,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': user.uid,
        });
      });
      if (!mounted) return;
      _quantityController.clear();
      _message('Issued ${qty.toStringAsFixed(3)} kg to ${widget.supplierName}.');
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Supplier Granules')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(
        title: Text('Granule Balance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _balanceRef.snapshots(),
        builder: (context, balanceSnapshot) {
          final balance = balanceSnapshot.data?.data() ?? <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.supplierName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Molding supplier • Supplier granules are tracked separately from factory stock', style: theme.textTheme.bodySmall),
                    const Divider(height: 24),
                    _balanceRow('Black Virgin', balance['blackVirginKg']),
                    _balanceRow('Black Grinding', balance['blackGrindingKg']),
                    _balanceRow('Clear Virgin', balance['clearVirginKg']),
                    _balanceRow('Clear Grinding', balance['clearGrindingKg']),
                    _balanceRow('PC Virgin', balance['pcVirginKg']),
                    _balanceRow('PC Grinding', balance['pcGrindingKg']),
                    if (balance['requiresReconciliation'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Balance needs reconciliation before further production.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Issue granules from factory', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('This deducts stock from the existing products inventory and adds the same quantity to this supplier’s balance.'),
                    const SizedBox(height: 14),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _products.where('type', isEqualTo: 'Raw Material').snapshots(),
                      builder: (context, productsSnapshot) {
                        if (productsSnapshot.hasError) return Text('Unable to load raw materials: ${productsSnapshot.error}');
                        if (!productsSnapshot.hasData) return const LinearProgressIndicator();
                        final products = productsSnapshot.data!.docs.where((doc) => _balanceField(doc.data()) != null).toList();
                        if (products.isEmpty) return const Text('No matching Raw Material products found. Add products with names such as TR90 Black - Virgin or TR90 Black - Grinding.');
                        final selectedExists = products.any((doc) => doc.id == _selectedProductId);
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          DropdownButtonFormField<String>(
                            value: selectedExists ? _selectedProductId : null,
                            decoration: const InputDecoration(labelText: 'Granule product', border: OutlineInputBorder()),
                            items: products.map((doc) {
                              final data = doc.data();
                              return DropdownMenuItem(value: doc.id, child: Text('${_productName(data)} • ${_double(data['stock']).toStringAsFixed(3)} kg available', overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: _saving ? null : (value) => setState(() => _selectedProductId = value),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity to issue (kg)', hintText: 'e.g. 5.5', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving || _selectedProductId == null ? null : _issueGranules,
                            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.outbox_outlined),
                            label: Text(_saving ? 'Issuing...' : 'Issue to supplier'),
                          ),
                        ]);
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('Recent granule movements', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _transactions.where('supplierId', isEqualTo: widget.supplierId).limit(50).snapshots(),
                builder: (context, txSnapshot) {
                  if (txSnapshot.hasError) return Text('Unable to load movements: ${txSnapshot.error}');
                  if (!txSnapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  final docs = txSnapshot.data!.docs.toList()..sort((a, b) {
                    final at = a.data()['createdAt'];
                    final bt = b.data()['createdAt'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });
                  if (docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No granule movements recorded yet.'));
                  return Column(children: docs.map((doc) {
                    final data = doc.data();
                    final qty = _double(data['quantityKg']);
                    final title = _str(data['transactionType']).isEmpty ? 'Granule movement' : _str(data['transactionType']);
                    final product = _str(data['inventoryProductName']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                      title: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(product.isEmpty ? _str(data['moldingOrderNumber']) : product),
                      trailing: Text('${qty.toStringAsFixed(3)} kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }).toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _balanceRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(label)), Text('${_double(value).toStringAsFixed(3)} kg', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))]),
    );
  }
}
