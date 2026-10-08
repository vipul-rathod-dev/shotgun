import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ReceiveDrummingGoodsPage extends StatefulWidget {
  final String orderId;

  final Map<String, dynamic>? order;

  const ReceiveDrummingGoodsPage({
    super.key,

    required this.orderId,

    this.order,
  });

  @override
  State<ReceiveDrummingGoodsPage> createState() =>
      _ReceiveDrummingGoodsPageState();
}

class _ReceiveDrummingGoodsPageState extends State<ReceiveDrummingGoodsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();

  final _bagsController = TextEditingController(text: '0');

  final _remarksController = TextEditingController();

  String? _companyId;

  Map<String, dynamic>? _order;

  List<Map<String, dynamic>> _items = [];

  final List<TextEditingController> _receiveControllers = [];

  bool _isLoading = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadOrder();
  }

  @override
  void dispose() {
    _weightController.dispose();

    _bagsController.dispose();

    _remarksController.dispose();

    for (final controller in _receiveControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _materialType(Map<String, dynamic> item) {
    final value = _stringValue(
      item['materialType'] ??
          item['type'] ??
          item['variantType'] ??
          item['rawMaterial'],
    );

    if (value.isEmpty) return '-';

    switch (value.toLowerCase()) {
      case 'black':
        return 'Black';

      case 'clear':
        return 'Clear';

      case 'pc':
        return 'PC';

      default:
        return value;
    }
  }

  bool _isTemple(Map<String, dynamic> item) {
    final component =
        _stringValue(
          item['componentType'] ?? item['component'] ?? item['partType'],
        ).toLowerCase();

    if (component.contains('temple')) return true;

    final side =
        _stringValue(
          item['side'] ??
              item['templeSide'] ??
              item['sideType'] ??
              item['partSide'],
        ).toLowerCase();

    return side == 'left' || side == 'right';
  }

  String _side(Map<String, dynamic> item) {
    final value =
        _stringValue(
          item['side'] ??
              item['templeSide'] ??
              item['sideType'] ??
              item['partSide'],
        ).toLowerCase();

    if (value.contains('right') || value == 'r') return 'Right';

    if (value.contains('left') || value == 'l') return 'Left';

    final text =
        [
          _stringValue(item['productName']),

          _stringValue(item['variantType']),

          _stringValue(item['type']),
        ].join(' ').toLowerCase();

    if (RegExp(r'(^|[^a-z])right([^a-z]|$)').hasMatch(text)) return 'Right';

    if (RegExp(r'(^|[^a-z])left([^a-z]|$)').hasMatch(text)) return 'Left';

    return '';
  }

  String _productName(Map<String, dynamic> item) {
    final value = _stringValue(
      item['productName'] ??
          item['displayName'] ??
          item['name'] ??
          item['product'],
    );

    return value.isEmpty ? '-' : value;
  }

  String _productId(Map<String, dynamic> item) {
    return _stringValue(
      item['productId'] ?? item['rawProductId'] ?? item['inventoryProductId'],
    );
  }

  int _ordered(Map<String, dynamic> item) {
    return _toInt(
      item['orderedQuantity'] ?? item['quantity'] ?? item['pieces'],
    );
  }

  int _received(Map<String, dynamic> item) {
    return _toInt(item['receivedQuantity']);
  }

  int _pending(Map<String, dynamic> item) {
    return (_ordered(item) - _received(item)).clamp(0, _ordered(item)).toInt();
  }

  String _variantKey(Map<String, dynamic> item) {
    final productId = _productId(item);
    final material = _materialType(item).trim().toLowerCase();
    final side = _side(item).trim().toLowerCase();

    if (productId.isNotEmpty) {
      return 'product:$productId|material:$material|side:$side';
    }

    final productCode = _stringValue(item['productCode']).toLowerCase();
    final productName = _productName(item).toLowerCase();

    return 'fallback:$productCode|name:$productName|material:$material|side:$side';
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.isEmpty) {
        throw Exception('Company ID is not available.');
      }

      _companyId = companyId;

      Map<String, dynamic> data;

      if (widget.order != null && widget.order!.isNotEmpty) {
        data = Map<String, dynamic>.from(widget.order!);

        data['id'] ??= widget.orderId;
      } else {
        final snapshot =
            await _firestore
                .collection('companies')
                .doc(companyId)
                .collection('raw_orders')
                .doc(widget.orderId)
                .get();

        if (!snapshot.exists) {
          throw Exception('Drumming order was not found.');
        }

        data = snapshot.data() ?? {};

        data['id'] = snapshot.id;
      }

      if (_stringValue(data['process']).toLowerCase() != 'drumming') {
        throw Exception('Selected order is not a Drumming order.');
      }

      final rawItems = data['items'];
      final grouped = <String, Map<String, dynamic>>{};

      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);
          final key = _variantKey(item);

          if (grouped.containsKey(key)) {
            final existing = grouped[key]!;
            existing['orderedQuantity'] =
                _toInt(existing['orderedQuantity']) + _ordered(item);
            existing['receivedQuantity'] =
                _toInt(existing['receivedQuantity']) + _received(item);
          } else {
            if (_productId(item).isEmpty) {
              // Do not silently create inventory against an unknown product.
              item['_inventoryError'] = 'Missing productId';
            }

            item['orderedQuantity'] = _ordered(item);
            item['receivedQuantity'] = _received(item);
            item['_receivedNow'] = 0;
            grouped[key] = item;
          }
        }
      }

      final items = grouped.values.toList();

      if (items.isEmpty) {
        throw Exception('No variants were found in this Drumming order.');
      }

      for (final controller in _receiveControllers) {
        controller.dispose();
      }

      _receiveControllers
        ..clear()
        ..addAll(
          items.map(
            (item) => TextEditingController(
              text: _toInt(item['_receivedNow']).toString(),
            ),
          ),
        );

      if (!mounted) return;

      setState(() {
        _order = data;

        _items = items;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),

            style: GoogleFonts.poppins(),
          ),

          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setReceived(int index, String value) {
    final parsed = int.tryParse(value.trim()) ?? 0;

    final item = _items[index];

    final pending = _pending(item);

    setState(() {
      item['_receivedNow'] = parsed.clamp(0, pending);
    });
  }

  void _fillAllPending() {
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        final pending = _pending(_items[i]);

        _items[i]['_receivedNow'] = pending;

        if (i < _receiveControllers.length) {
          _receiveControllers[i].text = pending.toString();
        }
      }
    });
  }

  int _totalReceivingPieces() {
    return _items.fold<int>(
      0,

      (total, item) => total + _toInt(item['_receivedNow']),
    );
  }

  bool _hasMissingProductIds() {
    return _items.any(
      (item) => _toInt(item['_receivedNow']) > 0 && _productId(item).isEmpty,
    );
  }

  Future<void> _saveReceiving() async {
    if (_isSaving || _companyId == null || _order == null) return;

    if (!_formKey.currentState!.validate()) return;

    final totalPieces = _totalReceivingPieces();

    if (totalPieces <= 0) {
      _showMessage(
        'Enter received quantity for at least one variant.',
        error: true,
      );

      return;
    }

    if (_hasMissingProductIds()) {
      _showMessage(
        'One or more selected variants do not have a productId. '
        'Inventory cannot be updated safely.',

        error: true,
      );

      return;
    }

    final weight = _toDouble(_weightController.text);

    final totalBags = _toInt(_bagsController.text);

    if (weight < 0 || totalBags < 0) {
      _showMessage('Weight and bags cannot be negative.', error: true);

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Your session has expired. Please log in again.',
        error: true,
      );

      return;
    }

    setState(() => _isSaving = true);

    try {
      final companyRef = _firestore.collection('companies').doc(_companyId);

      final orderRef = companyRef.collection('raw_orders').doc(widget.orderId);

      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Drumming order no longer exists.');
        }

        final latestOrder = orderSnapshot.data() ?? {};

        final latestRawItems = latestOrder['items'];

        if (latestRawItems is! List) {
          throw Exception('Drumming order has no item data.');
        }

        final latestItems =
            latestRawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

        final updates = <Map<String, dynamic>>[];

        final pendingProductReads = <Map<String, dynamic>>[];

        // Group the latest order rows by the same product/variant so duplicate
        // rows such as TH02 + Black + Left are treated as one receiving line.
        final latestGroups = <String, List<Map<String, dynamic>>>{};
        for (final candidate in latestItems) {
          latestGroups
              .putIfAbsent(_variantKey(candidate), () => [])
              .add(candidate);
        }

        for (final selectedItem in _items) {
          final additional = _toInt(selectedItem['_receivedNow']);
          if (additional <= 0) continue;

          final productId = _productId(selectedItem);
          final key = _variantKey(selectedItem);
          final matchingItems = latestGroups[key] ?? [];

          if (matchingItems.isEmpty) {
            throw Exception(
              'Variant ${_productName(selectedItem)} could not be matched in the latest order.',
            );
          }

          final totalPending = matchingItems.fold<int>(
            0,
            (total, candidate) => total + _pending(candidate),
          );

          if (additional > totalPending) {
            throw Exception(
              '${_productName(selectedItem)} has only $totalPending pieces pending.',
            );
          }

          pendingProductReads.add({
            'selectedItem': selectedItem,
            'matchingItems': matchingItems,
            'additional': additional,
            'productRef': companyRef.collection('products').doc(productId),
          });
        }

        // Read every affected inventory product before issuing any writes.*

        for (final entry in pendingProductReads) {
          final productSnapshot = await transaction.get(
            entry['productRef'] as DocumentReference,
          );

          if (!productSnapshot.exists) {
            throw Exception(
              'Inventory product ${_productName(entry['selectedItem'])} '
              'no longer exists.',
            );
          }

          entry['productData'] =
              productSnapshot.data() as Map<String, dynamic>? ?? {};
        }

        // Update inventory once per unique product/variant, then distribute
        // the received quantity across duplicate order rows.
        for (final entry in pendingProductReads) {
          final selectedItem = entry['selectedItem'] as Map<String, dynamic>;
          final matchingItems =
              (entry['matchingItems'] as List).cast<Map<String, dynamic>>();
          final additional = entry['additional'] as int;
          final productRef = entry['productRef'] as DocumentReference;
          final productData = entry['productData'] as Map<String, dynamic>;

          final currentStock = _toInt(productData['stock']);

          if (currentStock < 0) {
            throw Exception(
              'Invalid negative stock for ${_productName(selectedItem)}.',
            );
          }

          final newStock = currentStock + additional;

          transaction.update(productRef, {
            'stock': newStock,
            'lastReceivedQuantity': additional,
            'lastReceivedAt': FieldValue.serverTimestamp(),
            'lastReceivedFrom': 'Drumming',
            'lastReceivedOrderId': widget.orderId,
            'lastReceivedOrderNumber': latestOrder['orderNumber'],
            'inventoryUpdatedAt': FieldValue.serverTimestamp(),
          });

          updates.add({
            'productId': _productId(selectedItem),
            'productName': _productName(selectedItem),
            'productCode': _stringValue(selectedItem['productCode']),
            'componentType': _stringValue(
              selectedItem['componentType'] ?? selectedItem['component'],
            ),
            'materialType': _materialType(selectedItem),
            'side': _side(selectedItem).isEmpty ? null : _side(selectedItem),
            'quantity': additional,
            'previousStock': currentStock,
            'newStock': newStock,
          });

          // The UI contains one combined receiving field, but Firestore keeps
          // all original rows. Allocate the combined quantity across those
          // duplicate rows without exceeding each row's pending quantity.
          var remaining = additional;
          for (final latestItem in matchingItems) {
            if (remaining <= 0) break;

            final rowPending = _pending(latestItem);
            if (rowPending <= 0) continue;

            final allocation = remaining > rowPending ? rowPending : remaining;

            latestItem['receivedQuantity'] = _received(latestItem) + allocation;
            remaining -= allocation;
          }

          if (remaining > 0) {
            throw Exception(
              'Unable to distribute received quantity for ${_productName(selectedItem)}.',
            );
          }
        }

        final allComplete =
            latestItems.isNotEmpty &&
            latestItems.every((item) => _received(item) >= _ordered(item));

        final anyReceived = latestItems.any((item) => _received(item) > 0);

        final status =
            allComplete
                ? 'Received'
                : anyReceived
                ? 'Partially Received'
                : 'Pending';

        final history = <dynamic>[];

        final oldHistory = latestOrder['receivingHistory'];

        if (oldHistory is List) {
          history.addAll(oldHistory);
        }

        history.add({
          'receivedAt': Timestamp.now(),

          'receivedByUid': user.uid,

          'receivedByName': user.displayName ?? '',

          'weight': weight > 0 ? weight : null,

          'totalBags': totalBags > 0 ? totalBags : null,

          'totalPieces': totalPieces,

          'items': updates,

          'remarks': _remarksController.text.trim(),
        });

        transaction.update(orderRef, {
          'items': latestItems,

          'receivedPieces': latestItems.fold<int>(
            0,

            (total, item) => total + _received(item),
          ),

          'receivedShots': latestOrder['receivedShots'] ?? 0,

          'status': status,

          'lastReceivedAt': FieldValue.serverTimestamp(),

          'lastReceivedByUid': user.uid,

          'lastReceivedByName': user.displayName ?? '',

          'lastReceivedWeight': weight > 0 ? weight : null,

          'lastReceivedTotalBags': totalBags > 0 ? totalBags : null,

          'lastReceivedPieces': totalPieces,

          'lastReceivedRemarks': _remarksController.text.trim(),

          'receivingHistory': history,

          'inventoryReceived': true,

          'lastInventoryReceiptAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      _showMessage(
        'Drumming goods received. $totalPieces pieces added to inventory.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to receive drumming goods: '
        '${e.toString().replaceFirst('Exception: ', '')}',

        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),

        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) date = value.toDate();

    if (value is DateTime) date = value;

    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receive Drumming Goods')),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receive Drumming Goods')),

        body: const Center(child: Text('Unable to load Drumming order.')),
      );
    }

    final orderNumber =
        _stringValue(_order!['orderNumber']).isEmpty
            ? '-'
            : _stringValue(_order!['orderNumber']);

    final supplier =
        _stringValue(_order!['supplierName']).isEmpty
            ? '-'
            : _stringValue(_order!['supplierName']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: AppBar(
        elevation: 0,

        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),

          onPressed: () => Navigator.pop(context),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Receive Drumming Goods',

              style: GoogleFonts.poppins(
                fontSize: 16,

                fontWeight: FontWeight.w600,
              ),
            ),

            Text(
              orderNumber,

              style: GoogleFonts.poppins(
                fontSize: 10,

                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),

      body: Form(
        key: _formKey,

        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 24),

              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      _buildOrderCard(
                        orderNumber: orderNumber,

                        supplier: supplier,

                        isMobile: isMobile,
                      ),

                      const SizedBox(height: 16),

                      _buildReceiptCard(isMobile),

                      const SizedBox(height: 16),

                      _buildItemsCard(isMobile),

                      const SizedBox(height: 20),

                      _buildActions(isMobile),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required String orderNumber,

    required String supplier,

    required bool isMobile,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _title(
            Icons.rotate_right_outlined,

            'Drumming Order',

            'Goods will be received into Raw Product inventory',
          ),

          const SizedBox(height: 16),

          if (isMobile)
            Column(
              children: [
                _info('Order Number', orderNumber, Icons.receipt_long_outlined),

                const SizedBox(height: 12),

                _info('Drumming Supplier', supplier, Icons.person_outline),

                const SizedBox(height: 12),

                _info(
                  'Order Date',

                  _formatDate(_order!['orderDate']),

                  Icons.calendar_today_outlined,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _info(
                    'Order Number',

                    orderNumber,

                    Icons.receipt_long_outlined,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: _info(
                    'Drumming Supplier',

                    supplier,

                    Icons.person_outline,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: _info(
                    'Order Date',

                    _formatDate(_order!['orderDate']),

                    Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(bool isMobile) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _title(
            Icons.inventory_2_outlined,

            'Receipt Details',

            'Enter actual goods received from drumming',
          ),

          const SizedBox(height: 16),

          if (isMobile)
            Column(
              children: [
                _numberField(
                  controller: _weightController,

                  label: 'Weight Received',

                  suffix: 'kg',

                  allowDecimal: true,
                ),

                const SizedBox(height: 12),

                _numberField(
                  controller: _bagsController,

                  label: 'Total Bags Received',

                  suffix: 'bags',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    controller: _weightController,

                    label: 'Weight Received',

                    suffix: 'kg',

                    allowDecimal: true,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: _numberField(
                    controller: _bagsController,

                    label: 'Total Bags Received',

                    suffix: 'bags',
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),

          TextFormField(
            controller: _remarksController,

            maxLines: 3,

            style: GoogleFonts.poppins(fontSize: 12),

            decoration: InputDecoration(
              labelText: 'Remarks',

              alignLabelWithHint: true,

              filled: true,

              fillColor: const Color(0xFFF9FAFB),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),

                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),

                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(bool isMobile) {
    final totalPending = _items.fold<int>(
      0,

      (total, item) => total + _pending(item),
    );

    final totalNow = _totalReceivingPieces();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  Icons.list_alt_outlined,

                  'Variants to Receive',

                  '$totalPending pieces pending',
                ),
              ),

              OutlinedButton.icon(
                onPressed: _isSaving ? null : _fillAllPending,

                icon: const Icon(Icons.done_all, size: 17),

                label: const Text('Receive All Pending'),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),

              borderRadius: BorderRadius.circular(10),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.add_box_outlined,

                  size: 18,

                  color: Color(0xFF3F51B5),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Receiving now: $totalNow pieces',

                    style: GoogleFonts.poppins(
                      fontSize: 12,

                      fontWeight: FontWeight.w600,

                      color: const Color(0xFF3F51B5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (isMobile)
            Column(
              children: [
                for (int i = 0; i < _items.length; i++)
                  _buildMobileItem(_items[i], i),
              ],
            )
          else
            _buildDesktopItems(),
        ],
      ),
    );
  }

  Widget _buildMobileItem(Map<String, dynamic> item, int index) {
    final ordered = _ordered(item);

    final received = _received(item);

    final pending = _pending(item);

    final temple = _isTemple(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),

        borderRadius: BorderRadius.circular(11),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 28,

                height: 28,

                alignment: Alignment.center,

                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Text(
                  '${index + 1}',

                  style: GoogleFonts.poppins(
                    fontSize: 10,

                    fontWeight: FontWeight.w700,

                    color: const Color(0xFF3F51B5),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  _productName(item),

                  style: GoogleFonts.poppins(
                    fontSize: 13,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Padding(
            padding: const EdgeInsets.only(left: 37),

            child: Wrap(
              spacing: 10,

              runSpacing: 3,

              children: [
                _smallMeta('Material', _materialType(item)),

                if (temple)
                  _smallMeta('Side', _side(item).isEmpty ? '-' : _side(item)),

                _smallMeta('Ordered', ordered.toString()),

                _smallMeta('Received', received.toString()),

                _smallMeta('Pending', pending.toString()),
              ],
            ),
          ),

          const SizedBox(height: 11),

          TextFormField(
            controller: _receiveControllers[index],

            keyboardType: TextInputType.number,

            style: GoogleFonts.poppins(
              fontSize: 13,

              fontWeight: FontWeight.w600,
            ),

            decoration: InputDecoration(
              labelText: 'Receive Now',

              suffixText: 'pcs',

              helperText: 'Maximum $pending',

              filled: true,

              fillColor: Colors.white,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),

            onChanged: (value) {
              _setReceived(index, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopItems() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),

            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),

          child: Row(
            children: [
              Expanded(flex: 4, child: _tableHeader('Product')),

              Expanded(flex: 2, child: _tableHeader('Material')),

              Expanded(flex: 1, child: _tableHeader('Side')),

              Expanded(flex: 2, child: _tableHeader('Ordered')),

              Expanded(flex: 2, child: _tableHeader('Received')),

              Expanded(flex: 2, child: _tableHeader('Pending')),

              Expanded(flex: 2, child: _tableHeader('Receive Now')),
            ],
          ),
        ),

        for (int i = 0; i < _items.length; i++) _buildDesktopRow(_items[i], i),
      ],
    );
  }

  Widget _buildDesktopRow(Map<String, dynamic> item, int index) {
    final pending = _pending(item);

    final temple = _isTemple(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),

      child: Row(
        children: [
          Expanded(
            flex: 4,

            child: Text(
              _productName(item),

              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ),

          Expanded(
            flex: 2,

            child: Text(
              _materialType(item),

              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ),

          Expanded(
            flex: 1,

            child: Text(
              temple ? _side(item) : '-',

              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ),

          Expanded(
            flex: 2,

            child: Text(
              _ordered(item).toString(),

              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ),

          Expanded(
            flex: 2,

            child: Text(
              _received(item).toString(),

              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ),

          Expanded(
            flex: 2,

            child: Text(
              pending.toString(),

              style: GoogleFonts.poppins(
                fontSize: 11,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex: 2,

            child: TextFormField(
              controller: _receiveControllers[index],

              keyboardType: TextInputType.number,

              style: GoogleFonts.poppins(fontSize: 11),

              decoration: InputDecoration(
                isDense: true,

                suffixText: 'pcs',

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              onChanged: (value) => _setReceived(index, value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,

      children: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),

          child: const Text('Cancel'),
        ),

        const SizedBox(width: 10),

        FilledButton.icon(
          onPressed: _isSaving ? null : _saveReceiving,

          icon:
              _isSaving
                  ? const SizedBox(
                    width: 16,

                    height: 16,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.inventory_rounded, size: 18),

          label: Text(
            _isSaving ? 'Updating Inventory...' : 'Receive & Add to Inventory',
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,

    required String label,

    required String suffix,

    bool allowDecimal = false,
  }) {
    return TextFormField(
      controller: controller,

      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),

      style: GoogleFonts.poppins(fontSize: 12),

      validator: (value) {
        final text = value?.trim() ?? '';

        if (text.isEmpty) return null;

        final number =
            allowDecimal
                ? double.tryParse(text.replaceAll(',', ''))
                : int.tryParse(text.replaceAll(',', ''));

        if (number == null || number < 0) {
          return 'Enter a valid value';
        }

        return null;
      },

      decoration: InputDecoration(
        labelText: label,

        suffixText: suffix,

        filled: true,

        fillColor: const Color(0xFFF9FAFB),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _smallMeta(String label, String value) {
    return Text(
      '$label: $value',

      style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFF6B7280)),
    );
  }

  Widget _info(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 19, color: const Color(0xFF3F51B5)),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,

                style: GoogleFonts.poppins(
                  fontSize: 9,

                  color: const Color(0xFF9CA3AF),
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: GoogleFonts.poppins(
                  fontSize: 12,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 38,

          height: 38,

          alignment: Alignment.center,

          decoration: BoxDecoration(
            color: const Color(0xFFEFF2FF),

            borderRadius: BorderRadius.circular(10),
          ),

          child: Icon(icon, size: 20, color: const Color(0xFF3F51B5)),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: GoogleFonts.poppins(
                  fontSize: 14,

                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 1),

              Text(
                subtitle,

                style: GoogleFonts.poppins(
                  fontSize: 10,

                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String value) {
    return Text(
      value,

      style: GoogleFonts.poppins(
        fontSize: 9,

        fontWeight: FontWeight.w600,

        color: const Color(0xFF6B7280),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),

      child: child,
    );
  }
}
