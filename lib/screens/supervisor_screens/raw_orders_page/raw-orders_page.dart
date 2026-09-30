import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'raw_order_create_page.dart';
import 'molding_page.dart';
import 'drumming_page.dart';

class RawOrdersPage extends StatefulWidget {
  const RawOrdersPage({super.key});

  @override
  State<RawOrdersPage> createState() => _RawOrdersPageState();
}

class _RawOrdersPageState extends State<RawOrdersPage>
    with SingleTickerProviderStateMixin {
  String? _companyId;
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;
  late final TabController _processTabController;

  List<Map<String, dynamic>> _orders = [];
  String _search = '';
  String _statusFilter = 'All';
  final _searchController = TextEditingController();
  int _selectedTab = 0;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('raw_orders');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _inventoryTransactionsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('inventory_transactions');

  @override
  void initState() {
    super.initState();

    _processTabController = TabController(length: 3, vsync: this);
    _processTabController.addListener(() {
      if (_processTabController.indexIsChanging) return;
      if (!mounted) return;

      setState(() {
        _selectedTab = _processTabController.index;
      });
    });

    _initialize();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _processTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');
      if (companyId == null || companyId.isEmpty) {
        throw Exception('Company ID not found. Please log in again.');
      }
      _companyId = companyId;
      await _loadOrders();
      _startOrdersListener();
    } catch (e) {
      _showMessage('Failed to load raw orders: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrders() async {
    if (_companyId == null) return;

    try {
      // Do not depend on a Firestore orderBy here. Older raw_orders documents
      // may not have createdAt, and a query using orderBy can then fail or
      // make the page appear empty. Fetch the company orders and sort locally.
      final snapshot = await _ordersRef.get();

      final loadedOrders = snapshot.docs
          .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
          .toList();

      loadedOrders.sort((a, b) {
        final aDate = _orderSortDate(a);
        final bDate = _orderSortDate(b);
        return bDate.compareTo(aDate);
      });

      _orders = loadedOrders;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _orders = []);
      }
      rethrow;
    }
  }

  void _startOrdersListener() {
    if (_companyId == null) return;

    _ordersSubscription?.cancel();

    _ordersSubscription = _ordersRef.snapshots().listen(
      (snapshot) {
        final loadedOrders = snapshot.docs
            .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
            .toList();

        loadedOrders.sort((a, b) {
          final aDate = _orderSortDate(a);
          final bDate = _orderSortDate(b);
          return bDate.compareTo(aDate);
        });

        if (!mounted) return;
        setState(() {
          _orders = loadedOrders;
          _loading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        _showMessage('Failed to listen for raw order updates: $error', error: true);
      },
    );
  }

  DateTime _orderSortDate(Map<String, dynamic> order) {
    final createdAt = order['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();

    final orderDate = order['orderDate'];
    if (orderDate is Timestamp) return orderDate.toDate();

    final updatedAt = order['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _openCreateOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RawOrderCreatePage()),
    );

    if (created == true) await _loadOrders();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final q = _search.trim().toLowerCase();

    return _orders.where((order) {
      final status = order['status']?.toString() ?? 'Ordered';
      if (_statusFilter != 'All' && status != _statusFilter) return false;

      if (q.isEmpty) return true;

      return (order['orderNumber']?.toString().toLowerCase().contains(q) ?? false) ||
          (order['moldName']?.toString().toLowerCase().contains(q) ?? false) ||
          (order['supplierName']?.toString().toLowerCase().contains(q) ?? false) ||
          _orderItems(order).any((item) =>
              item['moldName']?.toString().toLowerCase().contains(q) == true ||
              item['modelName']?.toString().toLowerCase().contains(q) == true ||
              item['productName']?.toString().toLowerCase().contains(q) == true);
    }).toList();
  }

  List<Map<String, dynamic>> _orderItems(Map<String, dynamic> order) {
    final raw = order['items'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _showReceiveDialog(Map<String, dynamic> order) async {
    final items = _orderItems(order);
    if (items.isEmpty) {
      _showMessage(
        'This is an older raw order without variant line items. Create a new order using the new order page.',
        error: true,
      );
      return;
    }

    final remainingItems = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final ordered = _toInt(items[i]['orderedQuantity']);
      final received = _toInt(items[i]['receivedQuantity']);
      if (ordered > received) {
        remainingItems.add({
          ...items[i],
          '_originalIndex': i,
          '_remaining': ordered - received,
        });
      }
    }

    if (remainingItems.isEmpty) {
      _showMessage('This order has already been fully received.');
      return;
    }

    final controllers = <String, TextEditingController>{};
    for (final item in remainingItems) {
      final index = item['_originalIndex'].toString();
      controllers[index] = TextEditingController(text: '0');
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              var selectedPieces = 0;
              for (final item in remainingItems) {
                selectedPieces += _toInt(
                  controllers[item['_originalIndex'].toString()]?.text,
                );
              }

              return AlertDialog(
                title: const Text('Receive Raw Material'),
                content: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order['orderNumber'] ?? order['id']} • ${order['supplierName'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        ...remainingItems.map((item) {
                          final index = item['_originalIndex'].toString();
                          final controller = controllers[index]!;
                          final remaining = _toInt(item['_remaining']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['variantType']} • ${item['productName']}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Mold: ${item['moldName']} • Cavity ${item['cavityNumber']} • ${item['modelName']}',
                                      ),
                                      Text(
                                        'Ordered: ${item['orderedQuantity']}  •  Already received: ${item['receivedQuantity']}  •  Remaining: $remaining',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Receive',
                                      suffixText: 'pcs',
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        Text(
                          'Receiving now: $selectedPieces pieces',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving || selectedPieces <= 0
                        ? null
                        : () async {
                            final quantities = <int, int>{};
                            var valid = true;

                            for (final item in remainingItems) {
                              final index = _toInt(item['_originalIndex']);
                              final value = _toInt(controllers[index.toString()]?.text);
                              final remaining = _toInt(item['_remaining']);
                              if (value < 0 || value > remaining) {
                                valid = false;
                                break;
                              }
                              if (value > 0) quantities[index] = value;
                            }

                            if (!valid || quantities.isEmpty) {
                              _showMessage('Enter valid quantities within the remaining quantity.', error: true);
                              return;
                            }

                            await _receiveOrder(
                              order: order,
                              quantities: quantities,
                              dialogContext: dialogContext,
                            );
                          },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Receive Selected'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  // implementation. It moves received molded goods into molding_wip instead of
  // adding them directly to products.stock.

  Future<void> _receiveOrder({
    required Map<String, dynamic> order,
    required Map<int, int> quantities,
    required BuildContext dialogContext,
  }) async {
    final orderId = order['id']?.toString();
    if (orderId == null || _companyId == null) return;

    setState(() => _saving = true);

    try {
      final orderRef = _ordersRef.doc(orderId);
      final moldingWipRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('molding_wip');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final liveOrder = orderSnapshot.data();
        if (liveOrder == null) throw Exception('Order no longer exists.');

        final rawItems = liveOrder['items'];
        if (rawItems is! List) {
          throw Exception('This order uses the old order structure.');
        }

        final liveItems = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        var receiptTotal = 0;
        final wipDeltas = <String, int>{};
        final receiptHistory = <Map<String, dynamic>>[];

        for (final entry in quantities.entries) {
          if (entry.key < 0 || entry.key >= liveItems.length) {
            throw Exception('Order item changed. Refresh and try again.');
          }

          final item = liveItems[entry.key];
          final receiveQty = entry.value;
          final orderedQty = _toInt(item['orderedQuantity']);
          final receivedQty = _toInt(item['receivedQuantity']);
          final remaining = orderedQty - receivedQty;

          if (receiveQty <= 0) continue;
          if (receiveQty > remaining) {
            throw Exception(
              'Cannot receive ${receiveQty} pcs of ${item['productName']}. '
              'Only $remaining remain.',
            );
          }

          final productId = item['productId']?.toString() ?? '';
          if (productId.isEmpty) {
            throw Exception('Missing product ID for ${item['productName']}.');
          }

          final wipKey = [
            liveOrder['orderNumber'],
            item['moldProductId'],
            item['cavityNumber'],
            item['modelId'],
            item['variantType'],
            productId,
          ].join('_').replaceAll('/', '_');

          final wipRef = moldingWipRef.doc(wipKey);
          wipDeltas[wipRef.path] = (wipDeltas[wipRef.path] ?? 0) + receiveQty;

          item['receivedQuantity'] = receivedQty + receiveQty;
          receiptTotal += receiveQty;

          receiptHistory.add({
            'wipRef': wipRef,
            'productId': productId,
            'productName': item['productName'],
            'productCode': item['productCode'],
            'variantType': item['variantType'],
            'moldProductId': item['moldProductId'],
            'moldName': item['moldName'],
            'cavityNumber': item['cavityNumber'],
            'modelId': item['modelId'],
            'modelName': item['modelName'],
            'quantity': receiveQty,
          });
        }

        if (receiptTotal <= 0) {
          throw Exception('No quantity selected.');
        }

        // Read all existing WIP documents before writing.
        final wipSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final history in receiptHistory) {
          final ref = history['wipRef'] as DocumentReference<Map<String, dynamic>>;
          wipSnapshots[ref.path] ??= await transaction.get(ref);
        }

        for (final history in receiptHistory) {
          final ref = history['wipRef'] as DocumentReference<Map<String, dynamic>>;
          final snap = wipSnapshots[ref.path]!;
          final current = snap.data();
          final currentQty = current == null ? 0 : _toInt(current['availableQuantity']);

          final previousForWrite = currentQty;
          final delta = history['quantity'] as int;

          if (current == null) {
            transaction.set(ref, {
              'rawOrderId': orderId,
              'rawOrderNumber': liveOrder['orderNumber'],
              'moldProductId': history['moldProductId'],
              'moldName': history['moldName'],
              'cavityNumber': history['cavityNumber'],
              'modelId': history['modelId'],
              'modelName': history['modelName'],
              'variantType': history['variantType'],
              'productId': history['productId'],
              'productName': history['productName'],
              'productCode': history['productCode'],
              'availableQuantity': delta,
              'totalReceivedQuantity': delta,
              'status': 'Available for Drumming',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            transaction.update(ref, {
              'availableQuantity': previousForWrite + delta,
              'totalReceivedQuantity':
                  _toInt(current['totalReceivedQuantity']) + delta,
              'status': 'Available for Drumming',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        final allReceived = liveItems.every(
          (item) =>
              _toInt(item['receivedQuantity']) >=
              _toInt(item['orderedQuantity']),
        );
        final anyReceived =
            liveItems.any((item) => _toInt(item['receivedQuantity']) > 0);

        transaction.update(orderRef, {
          'items': liveItems,
          'receivedPieces':
              _toInt(liveOrder['receivedPieces']) + receiptTotal,
          'status': allReceived
              ? 'Received'
              : anyReceived
                  ? 'Partially Received'
                  : 'Ordered',
          'lastReceiptAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final history in receiptHistory) {
          transaction.set(
            FirebaseFirestore.instance
                .collection('companies')
                .doc(_companyId)
                .collection('inventory_transactions')
                .doc(),
            {
              'type': 'MOLDING_RECEIPT',
              'rawOrderId': orderId,
              'orderNumber': liveOrder['orderNumber'],
              'productId': history['productId'],
              'productName': history['productName'],
              'productCode': history['productCode'],
              'variantType': history['variantType'],
              'moldProductId': history['moldProductId'],
              'moldName': history['moldName'],
              'cavityNumber': history['cavityNumber'],
              'modelId': history['modelId'],
              'modelName': history['modelName'],
              'quantity': history['quantity'],
              'destination': 'MOLDING_WIP',
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      });

      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await _loadOrders();
      _showMessage('Molding received and moved to Molding WIP.');
    } catch (e) {
      _showMessage('Failed to receive order: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final items = _orderItems(order);
    final received = _toInt(order['receivedPieces']);

    if (received > 0) {
      _showMessage('An order with received inventory cannot be cancelled.', error: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Cancel ${order['orderNumber'] ?? order['id']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Order')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _ordersRef.doc(order['id'].toString()).update({
        'status': 'Cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadOrders();
    } catch (e) {
      _showMessage('Failed to cancel order: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Manufacturing'),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              onPressed: _loading ? null : _loadOrders,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Raw Orders',
            ),
        ],
        bottom: TabBar(
          controller: _processTabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long_outlined),
              text: 'Raw Orders',
            ),
            Tab(
              icon: Icon(Icons.precision_manufacturing_outlined),
              text: 'Molding',
            ),
            Tab(
              icon: Icon(Icons.rotate_right_outlined),
              text: 'Drumming',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _openCreateOrder,
              icon: const Icon(Icons.add),
              label: const Text('New Order'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _processTabController,
              children: [
                _buildRawOrdersView(orders),
                const MoldingPage(embedded: true),
                const DrummingPage(embedded: true),
              ],
            ),
    );
  }

  Widget _buildRawOrdersView(List<Map<String, dynamic>> orders) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search order, mold, model, variant or supplier',
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  'All',
                  'Ordered',
                  'Partially Received',
                  'Received',
                  'Cancelled',
                ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _statusFilter = v ?? 'All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text('No raw mold orders found.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                    itemCount: orders.length,
                    itemBuilder: (_, index) =>
                        _buildOrderCard(orders[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = _orderItems(order);
    final ordered = _toInt(order['orderedPieces']);
    final received = _toInt(order['receivedPieces']);
    final progress = ordered == 0 ? 0.0 : (received / ordered).clamp(0.0, 1.0);
    final status = order['status']?.toString() ?? 'Ordered';

    final moldNames = <String>{};
    for (final item in items) {
      final name = item['moldName']?.toString() ?? '';
      if (name.isNotEmpty) moldNames.add(name);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['orderNumber']?.toString() ?? 'Raw Order',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                _statusChip(status),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'receive') _showReceiveDialog(order);
                    if (value == 'cancel') _cancelOrder(order);
                  },
                  itemBuilder: (_) => [
                    if (status != 'Received' && status != 'Cancelled')
                      const PopupMenuItem(value: 'receive', child: Text('Receive Material')),
                    if (status == 'Ordered')
                      const PopupMenuItem(value: 'cancel', child: Text('Cancel Order')),
                  ],
                ),
              ],
            ),
            if ((order['supplierName']?.toString() ?? '').isNotEmpty)
              Text('Supplier: ${order['supplierName']}'),
            if (moldNames.isNotEmpty) Text('Molds: ${moldNames.join(', ')}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Pieces: $received / $ordered')),
                Text('${items.length} variant lines'),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            if (items.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: items.map((item) {
                  final remaining = _toInt(item['orderedQuantity']) - _toInt(item['receivedQuantity']);
                  return Chip(
                    label: Text(
                      '${item['variantType']} • ${item['modelName']} • ${item['orderedQuantity']} pcs${remaining > 0 ? ' ($remaining left)' : ''}',
                    ),
                  );
                }).toList(),
              )
            else
              const Text('Legacy order format'),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'Received'
        ? Colors.green
        : status == 'Cancelled'
            ? Colors.red
            : status == 'Partially Received'
                ? Colors.orange
                : Colors.blue;

    return Chip(
      label: Text(status),
      side: BorderSide(color: color.withOpacity(.3)),
      backgroundColor: color.withOpacity(.08),
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }
}
