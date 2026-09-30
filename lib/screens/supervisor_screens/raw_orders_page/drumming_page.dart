import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      _companyId = prefs.getString('cachedCompanyId');
      if (_companyId == null || _companyId!.isEmpty) {
        throw Exception('Company ID not found. Please log in again.');
      }

      _ref.snapshots().listen((snapshot) {
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

  DateTime _date(Map<String, dynamic> x) {
    final v = x['updatedAt'] ?? x['createdAt'];
    return v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _completeDrumming(Map<String, dynamic> item) async {
    final sent = _toInt(item['quantitySent']);
    final completedController = TextEditingController(text: '$sent');
    final rejectedController = TextEditingController(text: '0');

    try {
      final result = await showDialog<Map<String, int>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Complete Drumming'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item['variantType']} • ${item['productName']}'),
              const SizedBox(height: 4),
              Text('Sent to Drumming: $sent pcs'),
              const SizedBox(height: 14),
              TextField(
                controller: completedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Good Quantity',
                  suffixText: 'pcs',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rejectedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rejected / Wastage',
                  suffixText: 'pcs',
                ),
              ),
              const SizedBox(height: 8),
              const Text('Good + Rejected must equal the quantity sent.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final good = int.tryParse(completedController.text.trim()) ?? -1;
                final rejected = int.tryParse(rejectedController.text.trim()) ?? -1;
                if (good < 0 || rejected < 0 || good + rejected != sent) return;
                Navigator.pop(dialogContext, {
                  'good': good,
                  'rejected': rejected,
                });
              },
              child: const Text('Complete'),
            ),
          ],
        ),
      );

      if (result == null) return;

      final good = result['good']!;
      final rejected = result['rejected']!;
      final ref = _ref.doc(item['id'].toString());
      final productRef = _productsRef.doc(item['productId'].toString());

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final orderSnap = await tx.get(ref);
        final productSnap = await tx.get(productRef);

        final live = orderSnap.data();
        final product = productSnap.data();

        if (live == null) throw Exception('Drumming order no longer exists.');
        if (product == null) throw Exception('Raw product no longer exists.');

        if (live['status'] != 'In Drumming') {
          throw Exception('This Drumming order is already completed.');
        }

        final liveSent = _toInt(live['quantitySent']);
        if (good + rejected != liveSent) {
          throw Exception('Drumming quantity changed. Please refresh and try again.');
        }

        final previousStock = _toInt(product['stock']);

        tx.update(productRef, {
          'stock': previousStock + good,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(ref, {
          'quantityCompleted': good,
          'quantityRejected': rejected,
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
          'quantitySent': liveSent,
          'quantityAddedToStock': good,
          'quantityRejected': rejected,
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
