import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ReceiveMoldingGoodsPage extends StatefulWidget {
  final String orderId;

  final Map<String, dynamic>? order;

  const ReceiveMoldingGoodsPage({super.key, required this.orderId, this.order});

  @override
  State<ReceiveMoldingGoodsPage> createState() =>
      _ReceiveMoldingGoodsPageState();
}

class _ReceiveMoldingGoodsPageState extends State<ReceiveMoldingGoodsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  String? _companyId;

  Map<String, dynamic>? _order;

  bool _isLoading = true;

  bool _isSaving = false;

  List<Map<String, dynamic>> _drummingSuppliers = [];

  String? _selectedDrummingSupplierId;

  String? _selectedDrummingSupplierName;

  final TextEditingController _weightController = TextEditingController();

  final TextEditingController _bagsController = TextEditingController(
    text: '0',
  );

  final TextEditingController _remarksController = TextEditingController();

  final Map<String, TextEditingController> _receiveControllers = {};

  @override
  void initState() {
    super.initState();

    _loadOrder();
  }

  @override
  void dispose() {
    for (final controller in _receiveControllers.values) {
      controller.dispose();
    }

    _weightController.dispose();

    _bagsController.dispose();

    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.trim().isEmpty) {
        throw Exception('Company information is not available.');
      }

      final ref = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('raw_orders')
          .doc(widget.orderId);

      final snapshot = await ref.get();

      if (!snapshot.exists) {
        throw Exception('Molding order not found.');
      }

      final data = <String, dynamic>{...snapshot.data()!, 'id': snapshot.id};

      // Load all suppliers whose role is Drumming.

      // Do NOT auto-select one, because there can be multiple Drumming suppliers.

      final supplierSnapshot =
          await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('suppliers')
              .where('role', isEqualTo: 'Drumming')
              .get();

      final suppliers =
          supplierSnapshot.docs.map((doc) {
            return <String, dynamic>{...doc.data(), 'id': doc.id};
          }).toList();

      if (!mounted) return;

      setState(() {
        _companyId = companyId;

        _order = data;

        _drummingSuppliers = suppliers;

        _selectedDrummingSupplierId = null;

        _selectedDrummingSupplierName = null;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  String _supplierDisplayName(Map<String, dynamic> supplier) {
    return supplier['name']?.toString() ??
        supplier['supplierName']?.toString() ??
        supplier['displayName']?.toString() ??
        supplier['companyName']?.toString() ??
        supplier['id']?.toString() ??
        'Unknown Supplier';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _materialType(Map<String, dynamic> item) {
    final value = _stringValue(
      item['materialType'] ?? item['variantType'] ?? item['rawMaterial'],
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

  String _itemKey(Map<String, dynamic> item) {
    return [
      _stringValue(item['moldProductId']),

      _stringValue(item['cavityNumber'] ?? item['cavity']),

      _stringValue(item['modelId']),

      _stringValue(item['componentType']).toLowerCase(),

      _stringValue(item['variantType']).toLowerCase(),

      _stringValue(item['side']).toLowerCase(),

      _stringValue(item['variantKey']).toLowerCase(),

      _stringValue(item['productId']),
    ].join('|');
  }

  List<Map<String, dynamic>> _items() {
    final raw = _order?['items'];

    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool _isTemple(Map<String, dynamic> item) {
    return _stringValue(item['componentType']).toLowerCase() == 'temple';
  }

  bool _isFocus(Map<String, dynamic> item) {
    return _stringValue(item['componentType']).toLowerCase() == 'focus';
  }

  String _side(Map<String, dynamic> item) {
    return _stringValue(item['side']).toLowerCase();
  }

  String _groupKey(Map<String, dynamic> item) {
    final productId = _stringValue(item['productId']);
    final material = _materialType(item).toLowerCase();
    final component = _stringValue(item['componentType']).toLowerCase();

    // Focus: one group per product + material.
    if (component == 'focus') {
      return 'focus|$productId|$material';
    }

    // Temple: Left and Right are separate variants, so side is part
    // of the grouping key.
    if (component == 'temple') {
      final side = _side(item);
      return 'temple|$productId|$material|$side';
    }

    // Safe fallback for any future component types.
    final side = _side(item);
    return '$component|$productId|$material|$side';
  }

  Map<String, List<Map<String, dynamic>>> _groupItems(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      groups.putIfAbsent(_groupKey(item), () => []).add(item);
    }

    return groups;
  }

  Map<String, dynamic> _mergedGroupItem(List<Map<String, dynamic>> group) {
    final merged = Map<String, dynamic>.from(group.first);

    final ordered = group.fold<int>(
      0,
      (total, item) =>
          total + _toInt(item['orderedQuantity'] ?? item['quantity']),
    );

    final received = group.fold<int>(
      0,
      (total, item) => total + _toInt(item['receivedQuantity']),
    );

    merged['orderedQuantity'] = ordered;
    merged['receivedQuantity'] = received;

    return merged;
  }

  TextEditingController _controllerFor(String key) {
    return _receiveControllers.putIfAbsent(
      key,

      () => TextEditingController(text: '0'),
    );
  }

  int _entered(String key) => _toInt(_controllerFor(key).text);

  int _received(Map<String, dynamic> item) => _toInt(item['receivedQuantity']);

  int _ordered(Map<String, dynamic> item) =>
      _toInt(item['orderedQuantity'] ?? item['quantity']);

  int _remaining(Map<String, dynamic> item) {
    return (_ordered(item) - _received(item)).clamp(0, _ordered(item));
  }

  int _shotsFromPieces(dynamic pieces, dynamic piecesPerCycle) {
    final pieceCount = _toInt(pieces);

    if (pieceCount <= 0) return 0;

    final cyclePieces = _toInt(piecesPerCycle);

    if (cyclePieces <= 0) return pieceCount;

    return (pieceCount + cyclePieces - 1) ~/ cyclePieces;
  }

  int _calculateShots(List<Map<String, dynamic>> items, String field) {
    final itemsByMold = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final mold = _stringValue(item['moldProductId']);

      itemsByMold.putIfAbsent(mold, () => []).add(item);
    }

    var total = 0;

    for (final moldItems in itemsByMold.values) {
      final byCavity = <String, List<Map<String, dynamic>>>{};

      for (final item in moldItems) {
        final cavity = _stringValue(item['cavityNumber'] ?? item['cavity']);

        byCavity.putIfAbsent(cavity, () => []).add(item);
      }

      final cavityShots = <int>[];

      for (final cavityItems in byCavity.values) {
        final productionVariantShots = <String, int>{};

        for (final item in cavityItems) {
          final component = _stringValue(item['componentType']).toLowerCase();

          final model = _stringValue(item['modelId']);

          final material = _stringValue(item['variantType']);

          // Temple Left/Right are two physical inventory records for the same

          // molding production. Take the larger side instead of adding them.

          final key =
              component == 'temple'
                  ? '$model|$material'
                  : '$model|$material|${_stringValue(item['productId'])}';

          final shots = _shotsFromPieces(item[field], item['piecesPerCycle']);

          final current = productionVariantShots[key] ?? 0;

          if (shots > current) {
            productionVariantShots[key] = shots;
          }
        }

        cavityShots.add(
          productionVariantShots.values.fold<int>(
            0,

            (total, value) => total + value,
          ),
        );
      }

      // Selected cavities are produced simultaneously in one molding cycle.

      if (cavityShots.isNotEmpty) {
        total += cavityShots.reduce((a, b) => a > b ? a : b);
      }
    }

    return total;
  }

  Future<void> _saveReceiving() async {
    if (_companyId == null || _order == null || _isSaving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final items = _items();

    if (items.isEmpty) {
      _showMessage('This molding order has no items.', error: true);

      return;
    }

    final changes = <String, int>{};
    final groupedItems = _groupItems(items);

    for (final entry in groupedItems.entries) {
      final entered = _entered(entry.key);

      if (entered < 0) {
        _showMessage('Received quantity cannot be negative.', error: true);
        return;
      }

      if (entered == 0) continue;
      changes[entry.key] = entered;
    }

    if (changes.isEmpty) {
      _showMessage('Enter at least one received quantity.', error: true);

      return;
    }

    if (_drummingSuppliers.isEmpty) {
      _showMessage(
        'No Drumming supplier is available. Add a supplier with role \'Drumming\' first.',

        error: true,
      );

      return;
    }

    if (_selectedDrummingSupplierId == null ||
        _selectedDrummingSupplierId!.trim().isEmpty) {
      _showMessage('Please select a Drumming supplier.', error: true);

      return;
    }

    final weight = _toDouble(_weightController.text);

    final totalBags = _toInt(_bagsController.text);

    if (_weightController.text.trim().isNotEmpty && weight < 0) {
      _showMessage('Weight cannot be negative.', error: true);

      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        'User session has expired. Please login again.',

        error: true,
      );

      return;
    }

    setState(() => _isSaving = true);

    try {
      final companyRef = _firestore.collection('companies').doc(_companyId);

      final orderRef = companyRef.collection('raw_orders').doc(widget.orderId);

      final drummingOrderRef = companyRef.collection('raw_orders').doc();

      final drummingCounterRef = companyRef
          .collection('metadata')
          .doc('drumming_order_counter');

      String? generatedDrummingOrderNumber;

      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(orderRef);

        final counterSnapshot = await transaction.get(drummingCounterRef);

        if (!snapshot.exists) {
          throw Exception('Molding order no longer exists.');
        }

        final existing = Map<String, dynamic>.from(snapshot.data()!);

        final existingRawItems = existing['items'];

        if (existingRawItems is! List) {
          throw Exception('Molding order items are missing.');
        }

        final updatedItems = <Map<String, dynamic>>[];
        final remainingByGroup = <String, int>{...changes};
        final allocationByGroup = <String, List<int>>{};

        for (final raw in existingRawItems) {
          if (raw is! Map) continue;

          final item = Map<String, dynamic>.from(raw);
          final groupKey = _groupKey(item);
          final oldReceived = _toInt(item['receivedQuantity']);
          final ordered = _toInt(item['orderedQuantity'] ?? item['quantity']);
          final plannedRemaining = (ordered - oldReceived).clamp(0, ordered);

          var additional = remainingByGroup[groupKey] ?? 0;

          final plannedAllocation =
              additional > plannedRemaining ? plannedRemaining : additional;

          additional -= plannedAllocation;
          remainingByGroup[groupKey] = additional;

          item['receivedQuantity'] = oldReceived + plannedAllocation;
          updatedItems.add(item);

          allocationByGroup
              .putIfAbsent(groupKey, () => [])
              .add(plannedAllocation);
        }

        // Extra production is allowed. If the entered grouped quantity is
        // greater than the total pending quantity, put the extra on the
        // first matching row of that group.
        for (final entry in remainingByGroup.entries) {
          var extra = entry.value;
          if (extra <= 0) continue;

          final groupKey = entry.key;
          final allocations = allocationByGroup[groupKey] ?? <int>[];

          for (var i = 0; i < updatedItems.length && extra > 0; i++) {
            if (_groupKey(updatedItems[i]) != groupKey) continue;

            updatedItems[i]['receivedQuantity'] =
                _toInt(updatedItems[i]['receivedQuantity']) + extra;

            // The first item belonging to this group receives any extra
            // production beyond the planned quantity.
            if (allocations.isNotEmpty) {
              allocations[0] += extra;
            }

            extra = 0;
          }
        }

        // Keep the nested mold blocks synchronized because the existing

        // Create Molding Order page stores the same item records there too.

        final updatedMolds = <Map<String, dynamic>>[];

        final rawMolds = existing['molds'];

        final nestedAllocationOffsets = <String, int>{};

        if (rawMolds is List) {
          for (final rawMold in rawMolds) {
            if (rawMold is! Map) continue;

            final mold = Map<String, dynamic>.from(rawMold);
            final rawMoldItems = mold['items'];

            if (rawMoldItems is List) {
              mold['items'] =
                  rawMoldItems.map((rawItem) {
                    if (rawItem is! Map) return rawItem;

                    final item = Map<String, dynamic>.from(rawItem);
                    final groupKey = _groupKey(item);
                    final allocations =
                        allocationByGroup[groupKey] ?? const <int>[];
                    final offset = nestedAllocationOffsets[groupKey] ?? 0;

                    final additional =
                        offset < allocations.length ? allocations[offset] : 0;

                    nestedAllocationOffsets[groupKey] = offset + 1;

                    item['receivedQuantity'] =
                        _toInt(item['receivedQuantity']) + additional;

                    return item;
                  }).toList();
            }

            final moldItems = mold['items'];

            if (moldItems is List) {
              final typed =
                  moldItems
                      .whereType<Map>()
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList();

              mold['receivedPieces'] = typed.fold<int>(
                0,
                (total, item) => total + _toInt(item['receivedQuantity']),
              );

              mold['receivedShots'] = _calculateShots(
                typed,
                'receivedQuantity',
              );
            }

            updatedMolds.add(mold);
          }
        }

        final totalReceivedPieces = updatedItems.fold<int>(
          0,

          (total, item) => total + _toInt(item['receivedQuantity']),
        );

        final receivedShots = _calculateShots(updatedItems, 'receivedQuantity');

        final allItemsComplete =
            updatedItems.isNotEmpty &&
            updatedItems.every(
              (item) =>
                  _toInt(item['receivedQuantity']) >=
                  _toInt(item['orderedQuantity'] ?? item['quantity']),
            );

        final status = allItemsComplete ? 'Received' : 'Partially Received';

        final receiptItemsByGroup = <String, Map<String, dynamic>>{};
        final receiptAllocationOffsets = <String, int>{};

        for (final item in updatedItems) {
          final groupKey = _groupKey(item);
          final allocations = allocationByGroup[groupKey] ?? const <int>[];
          final offset = receiptAllocationOffsets[groupKey] ?? 0;
          final additional =
              offset < allocations.length ? allocations[offset] : 0;

          receiptAllocationOffsets[groupKey] = offset + 1;

          if (additional <= 0) continue;

          final existingReceipt = receiptItemsByGroup[groupKey];

          if (existingReceipt == null) {
            receiptItemsByGroup[groupKey] = {
              ...item,
              'orderedQuantity': additional,
              'receivedQuantity': 0,
              'sourceMoldingItemKey': groupKey,
            };
          } else {
            existingReceipt['orderedQuantity'] =
                _toInt(existingReceipt['orderedQuantity']) + additional;
          }
        }

        final receiptItems = receiptItemsByGroup.values.toList();

        if (receiptItems.isEmpty) {
          throw Exception(
            'No received items were found for the Drumming order.',
          );
        }

        final history = <dynamic>[];

        final existingHistory = existing['receivingHistory'];

        if (existingHistory is List) {
          history.addAll(existingHistory);
        }

        final historyItems =
            receiptItems.map((item) {
              return <String, dynamic>{
                'itemKey': item['sourceMoldingItemKey'],

                'productId': item['productId'],

                'productName': item['productName'],

                'componentType': item['componentType'],

                'variantType': item['variantType'],

                'materialType': _materialType(item),

                'side': item['side'],

                'cavityNumber': item['cavityNumber'],

                'quantity': item['orderedQuantity'],
              };
            }).toList();

        history.add({
          'receivedAt': Timestamp.now(),

          'receivedByUid': currentUser.uid,

          'weight': weight > 0 ? weight : null,

          'remarks': _remarksController.text.trim(),

          'items': historyItems,
        });

        int lastDrummingNumber = 0;

        if (counterSnapshot.exists) {
          final counterData = counterSnapshot.data();

          lastDrummingNumber = _toInt(counterData?['lastNumber']);
        }

        final nextDrummingNumber = lastDrummingNumber + 1;

        generatedDrummingOrderNumber =
            'DRUM-${nextDrummingNumber.toString().padLeft(5, '0')}';

        transaction.set(drummingCounterRef, {
          'lastNumber': nextDrummingNumber,

          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final drummingMolds = <String, Map<String, dynamic>>{};

        for (final item in receiptItems) {
          final moldId = _stringValue(item['moldProductId']);

          final moldKey =
              moldId.isEmpty ? _stringValue(item['moldName']) : moldId;

          final mold = drummingMolds.putIfAbsent(moldKey, () {
            return <String, dynamic>{
              'moldId': item['moldProductId'],

              'moldName': item['moldName'],

              'items': <Map<String, dynamic>>[],
            };
          });

          (mold['items'] as List<Map<String, dynamic>>).add(item);
        }

        final drummingItems = receiptItems;

        final drummingOrderedPieces = drummingItems.fold<int>(
          0,

          (total, item) => total + _toInt(item['orderedQuantity']),
        );

        transaction.set(drummingOrderRef, {
          'process': 'Drumming',

          'status': 'Pending',

          'orderNumber': generatedDrummingOrderNumber,

          'orderDate': FieldValue.serverTimestamp(),

          'createdAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),

          'createdByUid': currentUser.uid,

          'createdByName': currentUser.displayName ?? '',

          'supplierId': _selectedDrummingSupplierId,

          'supplierName': _selectedDrummingSupplierName ?? '',

          'sourceMoldingOrderId': widget.orderId,

          'sourceMoldingOrderNumber': _stringValue(existing['orderNumber']),

          'moldingSupplierId': existing['supplierId'],

          'moldingSupplierName': existing['supplierName'],

          'moldingReceiptId': drummingOrderRef.id,

          'moldingReceiptAt': FieldValue.serverTimestamp(),

          'moldingReceiptWeight': weight > 0 ? weight : null,

          'moldingReceiptTotalBags': totalBags > 0 ? totalBags : null,

          'moldingReceiptRemarks': _remarksController.text.trim(),

          'items': drummingItems,

          'molds': drummingMolds.values.toList(),

          'moldCount': drummingMolds.length,

          'variantCount': drummingItems.length,

          'orderedPieces': drummingOrderedPieces,

          'receivedPieces': 0,

          'orderedShots': _calculateShots(drummingItems, 'orderedQuantity'),

          'receivedShots': 0,
        });

        transaction.update(orderRef, {
          'items': updatedItems,

          'molds': updatedMolds,

          'receivedPieces': totalReceivedPieces,

          'receivedShots': receivedShots,

          'status': status,

          'lastReceivedAt': FieldValue.serverTimestamp(),

          'lastReceivedByUid': currentUser.uid,

          'lastReceivedWeight': weight > 0 ? weight : null,

          'lastReceivedTotalBags': totalBags > 0 ? totalBags : null,

          'lastReceivedRemarks': _remarksController.text.trim(),

          'receivingHistory': history,

          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      _showMessage(
        'Molding goods received and Drumming order ${generatedDrummingOrderNumber ?? ''} created successfully.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to receive molding goods: ${e.toString().replaceFirst('Exception: ', '')}',

        error: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,

      style: GoogleFonts.poppins(
        fontSize: 12,

        fontWeight: FontWeight.w600,

        color: const Color(0xFF4B5563),
      ),
    );
  }

  Widget _numberField({
    required String label,

    required TextEditingController controller,

    String? helper,
  }) {
    return TextFormField(
      controller: controller,

      keyboardType: const TextInputType.numberWithOptions(decimal: false),

      style: GoogleFonts.poppins(fontSize: 13),

      decoration: InputDecoration(
        labelText: label,

        helperText: helper,

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,

          vertical: 12,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),

          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),

          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }

  Widget _buildFocusCard(Map<String, dynamic> item) {
    final key = _groupKey(item);

    final received = _received(item);

    final ordered = _ordered(item);

    final remaining = _remaining(item);

    return _buildVariantCard(
      title:
          _stringValue(item['productName']).isEmpty
              ? _stringValue(item['modelName'])
              : _stringValue(item['productName']),

      subtitle: [
        _materialType(item),
        if (_isTemple(item) && _side(item).isNotEmpty)
          'Side: ${_side(item).toUpperCase()}',
        'Cavity ${_stringValue(item['cavityNumber'] ?? item['cavity'])}',
      ].join(' • '),

      orderedText: '$ordered pieces',

      receivedText: '$received pieces',

      remainingText: '$remaining pieces',

      child: _numberField(
        label: 'Receive Now (Pieces)',

        controller: _controllerFor(key),

        helper:
            'Extra pieces are allowed when production exceeds the planned quantity',
      ),
    );
  }

  Widget _buildVariantCard({
    required String title,

    required String subtitle,

    required String orderedText,

    required String receivedText,

    required String remainingText,

    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: GoogleFonts.poppins(
              fontSize: 14,

              fontWeight: FontWeight.w600,

              color: const Color(0xFF343741),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,

            style: GoogleFonts.poppins(
              fontSize: 11,

              color: const Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 14,

            runSpacing: 4,

            children: [
              _summaryText('Ordered', orderedText),

              _summaryText('Already Received', receivedText),

              _summaryText('Remaining', remainingText),
            ],
          ),

          const SizedBox(height: 12),

          child,
        ],
      ),
    );
  }

  Widget _summaryText(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',

            style: GoogleFonts.poppins(
              fontSize: 11,

              color: const Color(0xFF6B7280),
            ),
          ),

          TextSpan(
            text: value,

            style: GoogleFonts.poppins(
              fontSize: 11,

              fontWeight: FontWeight.w600,

              color: const Color(0xFF343741),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final items = _items();

    final focusItems = items.where(_isFocus).toList();
    final templeItems = items.where(_isTemple).toList();

    // Focus  -> productId + material
    // Temple -> productId + material + side
    final focusGroups = _groupItems(focusItems);
    final templeGroups = _groupItems(templeItems);

    final orderedShots = _calculateShots(items, 'orderedQuantity');

    final receivedShots = _calculateShots(items, 'receivedQuantity');

    final pendingShots = (orderedShots - receivedShots).clamp(0, orderedShots);

    return Form(
      key: _formKey,

      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),

        children: [
          Container(
            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  _stringValue(_order?['orderNumber']).isEmpty
                      ? '-'
                      : _stringValue(_order?['orderNumber']),

                  style: GoogleFonts.poppins(
                    fontSize: 17,

                    fontWeight: FontWeight.w600,

                    color: const Color(0xFF343741),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Molding Supplier: ${_stringValue(_order?['supplierName']).isEmpty ? '-' : _stringValue(_order?['supplierName'])}',

                  style: GoogleFonts.poppins(
                    fontSize: 12,

                    color: const Color(0xFF6B7280),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _summaryText('Ordered Shots', '$orderedShots'),
                    ),

                    Expanded(
                      child: _summaryText('Received Shots', '$receivedShots'),
                    ),

                    Expanded(
                      child: _summaryText('Pending Shots', '$pendingShots'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (focusGroups.isNotEmpty) ...[
            _sectionTitle('Focus - Received Pieces'),

            const SizedBox(height: 8),

            ...focusGroups.values.map(
              (group) => _buildFocusCard(_mergedGroupItem(group)),
            ),
          ],

          if (templeGroups.isNotEmpty) ...[
            const SizedBox(height: 6),

            _sectionTitle('Temple - Received Pieces'),

            const SizedBox(height: 8),

            ...templeGroups.values.map(
              (group) => _buildFocusCard(_mergedGroupItem(group)),
            ),
          ],

          const SizedBox(height: 6),

          _sectionTitle('Receiving Details'),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _label('Drumming Supplier *'),

                const SizedBox(height: 6),

                DropdownButtonFormField<String>(
                  value: _selectedDrummingSupplierId,

                  isExpanded: true,

                  decoration: InputDecoration(
                    hintText:
                        _drummingSuppliers.isEmpty
                            ? 'No Drumming suppliers available'
                            : 'Select Drumming supplier',

                    filled: true,

                    fillColor: const Color(0xFFF9FAFB),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,

                      vertical: 12,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),

                  items:
                      _drummingSuppliers.map((supplier) {
                        final id = supplier['id']?.toString() ?? '';

                        return DropdownMenuItem<String>(
                          value: id,

                          child: Text(
                            _supplierDisplayName(supplier),

                            overflow: TextOverflow.ellipsis,

                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        );
                      }).toList(),

                  onChanged:
                      _drummingSuppliers.isEmpty
                          ? null
                          : (value) {
                            Map<String, dynamic>? supplier;

                            for (final item in _drummingSuppliers) {
                              if (item['id']?.toString() == value) {
                                supplier = item;

                                break;
                              }
                            }

                            setState(() {
                              _selectedDrummingSupplierId = value;

                              _selectedDrummingSupplierName =
                                  supplier == null
                                      ? null
                                      : _supplierDisplayName(supplier);
                            });
                          },

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select a Drumming supplier';
                    }

                    return null;
                  },
                ),

                if (_drummingSuppliers.isEmpty) ...[
                  const SizedBox(height: 6),

                  Text(
                    'Add a supplier with role "Drumming" before receiving goods.',

                    style: GoogleFonts.poppins(
                      fontSize: 11,

                      color: Colors.redAccent,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                _label('Weight'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _weightController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  style: GoogleFonts.poppins(fontSize: 13),

                  decoration: InputDecoration(
                    hintText: 'Enter received weight',

                    suffixText: 'kg',

                    filled: true,

                    fillColor: const Color(0xFFF9FAFB),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,

                      vertical: 12,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _label('Total Bags Received'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _bagsController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),

                  style: GoogleFonts.poppins(fontSize: 13),

                  decoration: InputDecoration(
                    hintText: 'Enter total bags received',

                    suffixText: 'bags',

                    filled: true,

                    fillColor: const Color(0xFFF9FAFB),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,

                      vertical: 12,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),

                  validator: (value) {
                    if (_toInt(value) < 0) {
                      return 'Bags cannot be negative';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _label('Remarks'),

                const SizedBox(height: 6),

                TextFormField(
                  controller: _remarksController,

                  maxLines: 3,

                  style: GoogleFonts.poppins(fontSize: 13),

                  decoration: InputDecoration(
                    hintText: 'Optional receiving remarks',

                    filled: true,

                    fillColor: const Color(0xFFF9FAFB),

                    contentPadding: const EdgeInsets.all(12),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),

                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,

      style: GoogleFonts.poppins(
        fontSize: 14,

        fontWeight: FontWeight.w600,

        color: const Color(0xFF343741),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        title: Text(
          'Receive Molding Goods',

          style: GoogleFonts.poppins(
            fontSize: 18,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),
          ),
        ),

        iconTheme: const IconThemeData(color: Color(0xFF343741)),
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _order == null
              ? Center(
                child: Text(
                  'Unable to load molding order.',

                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              )
              : _buildBody(),

      bottomNavigationBar:
          _order == null || _isLoading
              ? null
              : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),

                child: SizedBox(
                  height: 50,

                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveReceiving,

                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,

                              height: 18,

                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.inventory_2_outlined),

                    label: Text(
                      _isSaving ? 'Saving...' : 'Receive Goods',

                      style: GoogleFonts.poppins(
                        fontSize: 14,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
