import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      _companyId = prefs.getString('cachedCompanyId');
      if (_companyId == null || _companyId!.isEmpty) {
        throw Exception('Company ID not found. Please log in again.');
      }

      _wipRef.snapshots().listen((snapshot) {
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

  DateTime _date(Map<String, dynamic> x) {
    final v = x['updatedAt'] ?? x['createdAt'];
    return v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _sendToDrumming(Map<String, dynamic> item) async {
    final max = _toInt(item['availableQuantity']);
    final controller = TextEditingController(text: '$max');

    try {
      final qty = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Send to Drumming'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item['variantType']} • ${item['productName']}'),
              Text('Mold: ${item['moldName']} • Cavity ${item['cavityNumber']}'),
              const SizedBox(height: 12),
              Text('Available: $max pcs'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  suffixText: 'pcs',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim()) ?? 0;
                if (value <= 0 || value > max) return;
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );

      if (qty == null || qty <= 0) return;

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

        final available = _toInt(live['availableQuantity']);
        if (qty > available) {
          throw Exception('Only $available pcs are available.');
        }

        final nowAvailable = available - qty;
        tx.update(wipRef, {
          'availableQuantity': nowAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
          'status': nowAvailable == 0 ? 'Sent to Drumming' : 'Partially Sent',
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
          'quantitySent': qty,
          'quantityCompleted': 0,
          'quantityRejected': 0,
          'status': 'In Drumming',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Material sent to Drumming.');
    } catch (e) {
      _message('Failed to send to Drumming: $e', true);
    } finally {
      controller.dispose();
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
