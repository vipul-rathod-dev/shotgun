import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DrummingPage extends StatefulWidget {
  final bool embedded;

  const DrummingPage({
    super.key,
    this.embedded = false,
  });

  @override
  State<DrummingPage> createState() => _DrummingPageState();
}

class _DrummingPageState extends State<DrummingPage> {
  String? _companyId;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('drumming_orders');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('inventory_transactions');

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

      _subscription = _ref.snapshots().listen((snapshot) {
        if (!mounted) return;
        final data = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        data.sort((a, b) => _date(b).compareTo(_date(a)));
        setState(() {
          _orders = data.where((e) => e['status'] == 'In Drumming').toList();
          _loading = false;
        });
      }, onError: (e) {
        if (mounted) {
          setState(() => _loading = false);
          _message('Failed to load Drumming orders: $e', true);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Failed to load Drumming: $e', true);
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

  Future<void> _completeDrumming(Map<String, dynamic> item) async {
    final sent = _toInt(item['quantitySent']);
    final sentWeight = _toDouble(item['weightSentKg']);
    final completedController = TextEditingController(text: '$sent');
    final rejectedController = TextEditingController(text: '0');
    final goodWeightController = TextEditingController(text: sentWeight.toStringAsFixed(3));
    final rejectedWeightController = TextEditingController(text: '0');

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final good = _toInt(completedController.text);
            final rejected = _toInt(rejectedController.text);
            final goodWeight = _toDouble(goodWeightController.text);
            final rejectedWeight = _toDouble(rejectedWeightController.text);

            return AlertDialog(
              title: const Text('Complete Drumming'),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['variantType']} • ${item['productName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Sent: $sent pcs • ${sentWeight.toStringAsFixed(3)} kg'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: completedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Good Qty', suffixText: 'pcs'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: rejectedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rejected', suffixText: 'pcs'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: goodWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Good Weight', suffixText: 'kg'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: rejectedWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Rejected Weight', suffixText: 'kg'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Good + rejected must equal $sent pcs.'),
                    Text('Good weight + rejected weight should equal ${sentWeight.toStringAsFixed(3)} kg.'),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (good < 0 || rejected < 0 || good + rejected != sent) return;
                    if (goodWeight < 0 || rejectedWeight < 0 || (goodWeight + rejectedWeight - sentWeight).abs() > 0.01) return;
                    Navigator.pop(dialogContext, {
                      'good': good,
                      'rejected': rejected,
                      'goodWeightKg': goodWeight,
                      'rejectedWeightKg': rejectedWeight,
                    });
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        ),
      );

      if (result == null) return;

      final good = _toInt(result['good']);
      final rejected = _toInt(result['rejected']);
      final goodWeight = _toDouble(result['goodWeightKg']);
      final rejectedWeight = _toDouble(result['rejectedWeightKg']);
      final ref = _ref.doc(item['id'].toString());
      final productRef = _productsRef.doc(item['productId'].toString());

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final orderSnap = await tx.get(ref);
        final productSnap = await tx.get(productRef);
        final live = orderSnap.data();
        final product = productSnap.data();
        if (live == null) throw Exception('Drumming order no longer exists.');
        if (product == null) throw Exception('Raw product no longer exists.');
        if (live['status'] != 'In Drumming') throw Exception('This Drumming order is already completed.');

        final liveSent = _toInt(live['quantitySent']);
        final liveWeight = _toDouble(live['weightSentKg']);
        if (good + rejected != liveSent) throw Exception('Drumming quantity changed. Please refresh and try again.');
        if ((goodWeight + rejectedWeight - liveWeight).abs() > 0.01) throw Exception('Drumming weight changed. Please refresh and try again.');

        final previousStock = _toInt(product['stock']);
        final previousStockWeight = _toDouble(product['stockWeightKg']);
        final productUpdates = <String, dynamic>{
          'stock': previousStock + good,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (product.containsKey('stockWeightKg')) {
          productUpdates['stockWeightKg'] = previousStockWeight + goodWeight;
        } else {
          productUpdates['stockWeightKg'] = goodWeight;
        }
        tx.update(productRef, productUpdates);

        tx.update(ref, {
          'quantityCompleted': good,
          'quantityRejected': rejected,
          'goodWeightKg': goodWeight,
          'rejectedWeightKg': rejectedWeight,
          'status': 'Completed',
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(_transactionsRef.doc(), {
          'type': 'DRUMMING_COMPLETION',
          'drummingOrderId': ref.id,
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
          'quantitySent': liveSent,
          'weightSentKg': liveWeight,
          'quantityAddedToStock': good,
          'quantityRejected': rejected,
          'goodWeightKg': goodWeight,
          'rejectedWeightKg': rejectedWeight,
          'drummingLabor': live['drummingLabor'],
          'drummingSupplierId': live['drummingSupplierId'],
          'drummingSupplierName': live['drummingSupplierName'],
          'laborRate': live['laborRate'],
          'laborRateUnit': live['laborRateUnit'],
          'laborCost': live['laborCost'],
          'previousStock': previousStock,
          'newStock': previousStock + good,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Drumming completed. $good pcs added to raw stock.');
    } catch (e) {
      _message('Failed to complete Drumming: $e', true);
    } finally {
      completedController.dispose();
      rejectedController.dispose();
      goodWeightController.dispose();
      rejectedWeightController.dispose();
    }
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

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
          : _orders.isEmpty
              ? const Center(child: Text('No goods currently in Drumming.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final item = _orders[i];
                    final sent = _toInt(item['quantitySent']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['variantType']} • ${item['productName']}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Mold: ${item['moldName']} • Cavity ${item['cavityNumber']} • ${item['modelName']}',
                            ),
                            Text('Quantity in Drumming: $sent pcs'),
                            Text('Weight in Drumming: ${_toDouble(item['weightSentKg']).toStringAsFixed(3)} kg'),
                            Text('Drumming Supplier: ${item['drummingSupplierName'] ?? ''}'),
                            Text('Drumming Labour: ₹${_toDouble(item['laborCost']).toStringAsFixed(2)}'),
                            Text('Raw Order: ${item['rawOrderNumber'] ?? ''}'),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => _completeDrumming(item),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Complete Drumming'),
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
        title: const Text('Drumming Process'),
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
