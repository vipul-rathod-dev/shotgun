import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MoldingPage extends StatefulWidget {
  final bool embedded;

  const MoldingPage({
    super.key,
    this.embedded = false,
  });

  @override
  State<MoldingPage> createState() => _MoldingPageState();
}

class _MoldingPageState extends State<MoldingPage> {
  String? _companyId;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _suppliers = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('suppliers');

  CollectionReference<Map<String, dynamic>> get _wipRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('molding_wip');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _subscription?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      _companyId = prefs.getString('cachedCompanyId');
      if (_companyId == null || _companyId!.isEmpty) {
        throw Exception('Company ID not found. Please log in again.');
      }

      final supplierSnapshot = await _suppliersRef.get();
      _suppliers = supplierSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['supplierName']?.toString() ??
              data['name']?.toString() ??
              data['displayName']?.toString() ??
              data['companyName']?.toString() ??
              'Unnamed Supplier',
        };
      }).toList();
      _suppliers.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

      _subscription = _wipRef.snapshots().listen((snapshot) {
        if (!mounted) return;
        final data = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        data.sort((a, b) => _date(b).compareTo(_date(a)));
        setState(() {
          _items = data.where((e) => _toInt(e['availableQuantity']) > 0).toList();
          _loading = false;
        });
      }, onError: (e) {
        if (mounted) {
          setState(() => _loading = false);
          _message('Failed to load molding WIP: $e', true);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Failed to load molding WIP: $e', true);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  DateTime _date(Map<String, dynamic> x) {
    final v = x['updatedAt'] ?? x['createdAt'];
    return v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _sendToDrumming(Map<String, dynamic> item) async {
    final maxQty = _toInt(item['availableQuantity']);
    final maxWeight = _toDouble(item['availableWeightKg']);
    final quantityController = TextEditingController(text: '$maxQty');
    final weightController = TextEditingController(text: maxWeight.toStringAsFixed(3));
    String? selectedSupplierId;
    final rateController = TextEditingController(text: '0');
    String rateUnit = 'kg';

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final qty = _toInt(quantityController.text);
            final weight = _toDouble(weightController.text);
            final rate = _toDouble(rateController.text);
            final estimatedLabor = _calculateLaborCost(
              quantity: qty,
              weightKg: weight,
              rate: rate,
              rateUnit: rateUnit,
            );

            return AlertDialog(
              title: const Text('Send to Drumming'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item['variantType']} • ${item['productName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Mold: ${item['moldName']} • Cavity ${item['cavityNumber']} • ${item['modelName']}'),
                      const SizedBox(height: 10),
                      Text('Available: $maxQty pcs • ${maxWeight.toStringAsFixed(3)} kg'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'pcs'),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: DropdownButtonFormField<String>(
                              value: selectedSupplierId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Drumming Supplier',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              items: _suppliers.map((supplier) {
                                return DropdownMenuItem<String>(
                                  value: supplier['id'].toString(),
                                  child: Text(
                                    supplier['name'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() => selectedSupplierId = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: 135,
                            child: TextField(
                              controller: rateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Labour Rate', prefixText: '₹ '),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 135,
                            child: DropdownButtonFormField<String>(
                              value: rateUnit,
                              decoration: const InputDecoration(labelText: 'Rate Unit'),
                              items: const [
                                DropdownMenuItem(value: 'piece', child: Text('Per Piece')),
                                DropdownMenuItem(value: 'kg', child: Text('Per Kg')),
                                DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => rateUnit = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Estimated Drumming Labour: ₹${estimatedLabor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (qty <= 0 || qty > maxQty) return;
                    if (weight <= 0 || weight > maxWeight) return;
                    if (selectedSupplierId == null || selectedSupplierId!.isEmpty || rate <= 0) return;
                    Navigator.pop(dialogContext, {
                      'quantity': qty,
                      'weightKg': weight,
                      'drummingSupplierId': selectedSupplierId,
                      'drummingSupplierName': _supplierName(selectedSupplierId),
                      'laborRate': rate,
                      'laborRateUnit': rateUnit,
                      'laborCost': estimatedLabor,
                    });
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        ),
      );

      if (result == null) return;

      final qty = _toInt(result['quantity']);
      final weight = _toDouble(result['weightKg']);
      final wipRef = _wipRef.doc(item['id'].toString());
      final drummingRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('drumming_orders')
          .doc();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(wipRef);
        final live = snap.data();
        if (live == null) throw Exception('Molding WIP no longer exists.');

        final availableQty = _toInt(live['availableQuantity']);
        final availableWeight = _toDouble(live['availableWeightKg']);
        if (qty > availableQty) throw Exception('Only $availableQty pcs are available.');
        if (weight > availableWeight + 0.000001) throw Exception('Only ${availableWeight.toStringAsFixed(3)} kg are available.');

        final nowQty = availableQty - qty;
        final nowWeight = availableWeight - weight;

        tx.update(wipRef, {
          'availableQuantity': nowQty,
          'availableWeightKg': nowWeight,
          'updatedAt': FieldValue.serverTimestamp(),
          'status': nowQty == 0 ? 'Sent to Drumming' : 'Partially Sent',
        });

        tx.set(drummingRef, {
          'sourceMoldingWipId': wipRef.id,
          'moldingWipId': wipRef.id,
          'rawOrderId': live['rawOrderId'],
          'rawOrderNumber': live['rawOrderNumber'],
          'moldProductId': live['moldProductId'],
          'moldName': live['moldName'],
          'cavityNumber': live['cavityNumber'],
          'modelId': live['modelId'],
          'modelName': live['modelName'],
          'variantType': live['variantType'],
          'productId': live['productId'],
          'productName': live['productName'],
          'productCode': live['productCode'],
          'moldingSupplierId': live['moldingSupplierId'],
          'moldingSupplierName': live['moldingSupplierName'],
          'drummingSupplierId': result['drummingSupplierId'],
          'drummingSupplierName': result['drummingSupplierName'],
          'quantitySent': qty,
          'weightSentKg': weight,
          'quantityCompleted': 0,
          'quantityRejected': 0,
          'drummingLabor': {
            'supplierId': result['drummingSupplierId'],
            'supplierName': result['drummingSupplierName'],
            'rate': result['laborRate'],
            'rateUnit': result['laborRateUnit'],
            'laborCost': result['laborCost'],
          },
          'laborRate': result['laborRate'],
          'laborRateUnit': result['laborRateUnit'],
          'laborCost': result['laborCost'],
          'status': 'In Drumming',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Material sent to Drumming with labour cost recorded.');
    } catch (e) {
      _message('Failed to send to Drumming: $e', true);
    } finally {
      quantityController.dispose();
      weightController.dispose();
      rateController.dispose();
    }
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  String _supplierName(String? supplierId) {
    for (final supplier in _suppliers) {
      if (supplier['id'].toString() == supplierId) {
        return supplier['name'].toString();
      }
    }
    return '';
  }

  double _calculateLaborCost({
    required int quantity,
    required double weightKg,
    required double rate,
    required String rateUnit,
  }) {
    switch (rateUnit) {
      case 'piece':
        return quantity * rate;
      case 'fixed':
        return rate;
      case 'kg':
      default:
        return weightKg * rate;
    }
  }

  void _message(String text, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No molded goods waiting for Drumming.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final qty = _toInt(item['availableQuantity']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['variantType']} • ${item['productName']}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Chip(label: Text('$qty pcs')),
                              ],
                            ),
                            Text(
                              'Mold: ${item['moldName']} • Cavity ${item['cavityNumber']} • ${item['modelName']}',
                            ),
                            Text('Raw Order: ${item['rawOrderNumber'] ?? ''}'),
                            Text('Available Weight: ${_toDouble(item['availableWeightKg']).toStringAsFixed(3)} kg'),
                            Text('Molding Labour: ₹${_toDouble(item['totalMoldingLaborCost']).toStringAsFixed(2)}'),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => _sendToDrumming(item),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Send to Drumming'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Molding WIP'),
        actions: [
          IconButton(
            onPressed: _initialize,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

}
