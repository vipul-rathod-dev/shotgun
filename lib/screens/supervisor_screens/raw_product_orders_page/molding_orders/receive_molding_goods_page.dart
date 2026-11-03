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

  // Actual physical cavity counts loaded from companies/{companyId}/products.
  final Map<String, int> _moldCavityCountCache = {};

  Map<String, dynamic>? _order;

  bool _isLoading = true;

  bool _isSaving = false;

  List<Map<String, dynamic>> _drummingSuppliers = [];

  String? _selectedDrummingSupplierId;

  String? _selectedDrummingSupplierName;

  final Map<String, TextEditingController> _weightControllers = {};

  final TextEditingController _bagsController = TextEditingController(
    text: '0',
  );

  final TextEditingController _remarksController = TextEditingController();

  // Date assigned to the Drumming order created from this receipt.
  DateTime _selectedOrderDate = DateTime.now();

  // Editable defaults for the granule-consumption calculation.
  final TextEditingController _runnerGramsController = TextEditingController(
    text: '4',
  );
  final TextEditingController _wastagePercentController = TextEditingController(
    text: '3',
  );
  final TextEditingController _virginRatioKgController = TextEditingController(
    text: '10',
  );
  final TextEditingController _grindingRatioKgController =
      TextEditingController(text: '3');

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

    for (final controller in _weightControllers.values) {
      controller.dispose();
    }

    _bagsController.dispose();

    _remarksController.dispose();
    _runnerGramsController.dispose();
    _wastagePercentController.dispose();
    _virginRatioKgController.dispose();
    _grindingRatioKgController.dispose();

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

      // Load the physical cavity count from the Mold product document.
      // In the mold document, cavityCount is the actual count (e.g. 2),
      // while cavities[].cavityNumber are cavity labels (1, 2, ...).
      final moldIds = <String>{};
      final rawItems = data['items'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is Map) {
            final moldId = _stringValue(rawItem['moldProductId']);
            if (moldId.isNotEmpty) moldIds.add(moldId);
          }
        }
      }

      final cavityCounts = <String, int>{};
      for (final moldId in moldIds) {
        final moldSnapshot =
            await _firestore
                .collection('companies')
                .doc(companyId)
                .collection('products')
                .doc(moldId)
                .get();
        if (!moldSnapshot.exists) continue;
        final moldData = moldSnapshot.data() ?? <String, dynamic>{};
        final cavityCount = _toInt(
          moldData['cavityCount'] ?? moldData['cavitiesCount'],
        );
        if (cavityCount > 0) cavityCounts[moldId] = cavityCount;
      }

      // Load all suppliers whose role is Drumming.*

      // Do NOT auto-select one, because there can be multiple Drumming suppliers.*

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

        _moldCavityCountCache.addAll(cavityCounts);

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
    final moldId = _stringValue(item['moldProductId']);

    final material = _materialType(item).toLowerCase();

    final component = _stringValue(item['componentType']).toLowerCase();

    // Focus: one group per product + material.*

    if (component == 'focus') {
      return 'focus|$moldId|$productId|$material';
    }

    // Temple: Left and Right are separate variants, so side is part*

    // of the grouping key.*

    if (component == 'temple') {
      final side = _side(item);

      return 'temple|$moldId|$productId|$material|$side';
    }

    // Safe fallback for any future component types.*

    final side = _side(item);

    return '$component|$moldId|$productId|$material|$side';
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

  TextEditingController _weightControllerFor(String key) {
    return _weightControllers.putIfAbsent(
      key,

      () => TextEditingController(text: '0'),
    );
  }

  double _enteredWeight(String key) =>
      _toDouble(_weightControllerFor(key).text);

  double? _ratioNumber(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim().replaceAll('%', '');

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  Map<String, double>? _ratioFractions(
    Map<String, dynamic> item, {

    Map<String, dynamic>? fallback,
  }) {
    dynamic readRatio(List<String> keys) {
      for (final key in keys) {
        if (item[key] != null && item[key].toString().trim().isNotEmpty) {
          return item[key];
        }
      }

      if (fallback != null) {
        for (final key in keys) {
          if (fallback[key] != null &&
              fallback[key].toString().trim().isNotEmpty) {
            return fallback[key];
          }
        }
      }

      return null;
    }

    var virgin = _ratioNumber(
      readRatio(['virginRatio', 'virginPercentage', 'virginPercent']),
    );

    var grinding = _ratioNumber(
      readRatio(['grindingRatio', 'grindingPercentage', 'grindingPercent']),
    );

    if (virgin == null && grinding == null) return null;

    if (virgin == null) {
      final currentGrinding = grinding;

      if (currentGrinding == null) return null;

      virgin =
          currentGrinding <= 1 ? 1 - currentGrinding : 100 - currentGrinding;
    }

    if (grinding == null) {
      final currentVirgin = virgin;

      grinding = currentVirgin <= 1 ? 1 - currentVirgin : 100 - currentVirgin;
    }

    final virginValue = virgin;

    final grindingValue = grinding;

    if (virginValue < 0 ||
        grindingValue < 0 ||
        virginValue + grindingValue <= 0) {
      return null;
    }

    final total = virginValue + grindingValue;

    return {
      'virgin': virginValue / total,

      'grinding': grindingValue / total,

      'virginRatioValue': virginValue,

      'grindingRatioValue': grindingValue,
    };
  }

  String _materialFieldPrefix(Map<String, dynamic> item) {
    switch (_materialType(item).toLowerCase()) {
      case 'black':
        return 'black';

      case 'clear':
        return 'clear';

      case 'pc':
        return 'pc';

      default:
        return '';
    }
  }

  Map<String, double> _granuleCalculation(
    double productWeight,
    Map<String, double> ratios,
    int shotCount,
  ) {
    final runnerWeightPerShotGrams = _toDouble(_runnerGramsController.text);
    final runnerWeightPerShotKg = runnerWeightPerShotGrams / 1000;
    final wastageRate = _toDouble(_wastagePercentController.text) / 100;
    final virginKg = _toDouble(_virginRatioKgController.text);
    final grindingKg = _toDouble(_grindingRatioKgController.text);
    final totalRatioKg = virginKg + grindingKg;
    final virginRatio = totalRatioKg > 0 ? virginKg / totalRatioKg : 0.0;
    final grindingRatio = totalRatioKg > 0 ? grindingKg / totalRatioKg : 0.0;

    // Step 1: Add configured wastage to the actual received product weight.
    final totalWastage = productWeight * wastageRate;
    final productWeightWithWastage = productWeight + totalWastage;

    // Step 2: Runner weight is configured in grams per molding shot.
    // It is credited directly to the supplier ledger.
    final runnerRecovered = shotCount * runnerWeightPerShotKg;

    // Step 3: Total granules used = adjusted product weight + runner.
    final totalGranulesUsed = productWeightWithWastage + runnerRecovered;
    final virginConsumed = totalGranulesUsed * virginRatio;
    final grindingConsumed = totalGranulesUsed * grindingRatio;

    return {
      'receivedProductWeightKg': productWeight,
      'productWeightWithWastageKg': productWeightWithWastage,
      'estimatedGranulesUsedKg': totalGranulesUsed,
      'runnerRecoveredKg': runnerRecovered,
      'runnerWeightPerShotGrams': runnerWeightPerShotGrams,
      'moldingShotsUsedForRunnerCalculation': shotCount.toDouble(),
      'wastageRatePercent': wastageRate * 100,
      'virginRatioKg': virginKg,
      'grindingRatioKg': grindingKg,
      'virginRatio': virginRatio * 100,
      'grindingRatio': grindingRatio * 100,
      'virginConsumedKg': virginConsumed,
      'grindingConsumedKg': grindingConsumed,
      'virginDeductionKg': virginConsumed,
      'grindingDeductionKg': grindingConsumed,
      'totalWastageKg': totalWastage,
    };
  }

  int _received(Map<String, dynamic> item) => _toInt(item['receivedQuantity']);

  int _ordered(Map<String, dynamic> item) =>
      _toInt(item['orderedQuantity'] ?? item['quantity']);

  int _remaining(Map<String, dynamic> item) {
    return (_ordered(item) - _received(item)).clamp(0, _ordered(item));
  }

  int _calculateShots(List<Map<String, dynamic>> items, String field) {
    final itemsByMold = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final moldId = _stringValue(item['moldProductId']);
      itemsByMold.putIfAbsent(moldId, () => []).add(item);
    }

    var totalShots = 0;
    for (final entry in itemsByMold.entries) {
      final moldId = entry.key;
      final moldItems = entry.value;
      final cavityCount = _moldCavityCountCache[moldId] ?? 0;

      final templeByVariant = <String, Map<String, int>>{};
      final focusByVariant = <String, int>{};
      final selectedFocusCavities = <String>{};

      for (final item in moldItems) {
        final component = _stringValue(item['componentType']).toLowerCase();
        final model = _stringValue(item['modelId']).isNotEmpty
            ? _stringValue(item['modelId'])
            : _stringValue(item['productId']);
        final material = _stringValue(item['variantType']).toLowerCase();
        final quantity = _toInt(item[field]);

        if (component == 'temple') {
          final side = _side(item);
          final key = '$model|$material';
          final sides = templeByVariant.putIfAbsent(key, () => <String, int>{});
          sides[side] = (sides[side] ?? 0) + quantity;
        } else if (component == 'focus') {
          final key = '$model|$material';
          focusByVariant[key] = (focusByVariant[key] ?? 0) + quantity;
          final cavity = _stringValue(item['cavityNumber'] ?? item['cavity']);
          if (cavity.isNotEmpty) selectedFocusCavities.add(cavity);
        }
      }

      // Temple Left and Right are paired outputs. Either side represents
      // the pair count; use the larger side to avoid double-counting.
      if (cavityCount > 0) {
        for (final sides in templeByVariant.values) {
          final left = sides['left'] ?? 0;
          final right = sides['right'] ?? 0;
          final pairedSidePieces = left > right ? left : right;
          if (pairedSidePieces > 0) {
            totalShots += (pairedSidePieces + cavityCount - 1) ~/ cavityCount;
          }
        }
      }

      // Focus quantities are stored once per mold/model/material group.
      // Divide by the number of cavities selected in this molding order.
      final selectedCount = selectedFocusCavities.length;
      if (selectedCount > 0) {
        for (final pieces in focusByVariant.values) {
          if (pieces > 0) {
            totalShots += (pieces + selectedCount - 1) ~/ selectedCount;
          }
        }
      }
    }
    return totalShots;
  }

  // Split a cumulative received total evenly across the cavity rows for the
  // same mold/model/material/side. Remainder pieces go to the lowest cavity
  // number first, so the sum always remains exactly equal to the entered total.
  List<int> _splitTotalAcrossCavityRows(
    List<Map<String, dynamic>> group,
    int total,
  ) {
    if (group.isEmpty) return <int>[];

    final orderedIndexes = List<int>.generate(group.length, (index) => index);
    int cavitySortValue(Map<String, dynamic> item) {
      final raw = _stringValue(item['cavityNumber'] ?? item['cavity']);
      final match = RegExp(r'\d+').firstMatch(raw);
      return match == null ? 1 << 30 : int.tryParse(match.group(0)!) ?? (1 << 30);
    }

    orderedIndexes.sort((a, b) {
      final comparison = cavitySortValue(group[a]).compareTo(cavitySortValue(group[b]));
      return comparison != 0 ? comparison : a.compareTo(b);
    });

    final baseQuantity = total ~/ group.length;
    final remainder = total % group.length;
    final allocations = List<int>.filled(group.length, 0);

    for (var position = 0; position < orderedIndexes.length; position++) {
      allocations[orderedIndexes[position]] =
          baseQuantity + (position < remainder ? 1 : 0);
    }

    return allocations;
  }

  void _applyReceivedTotalsAcrossCavities(
    List<Map<String, dynamic>> items,
    Map<String, int> totalsByGroup,
  ) {
    final groupedItems = _groupItems(items);
    for (final entry in groupedItems.entries) {
      final total = totalsByGroup[entry.key];
      if (total == null) continue;
      final allocations = _splitTotalAcrossCavityRows(entry.value, total);
      for (var i = 0; i < entry.value.length; i++) {
        entry.value[i]['receivedQuantity'] = allocations[i];
      }
    }
  }

  List<Map<String, dynamic>> _previewItemsWithEnteredReceipt() {
    final items = _items()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final groupedItems = _groupItems(items);
    final totalsByGroup = <String, int>{};

    for (final entry in groupedItems.entries) {
      final previousTotal = entry.value.fold<int>(
        0,
        (sum, item) => sum + _toInt(item['receivedQuantity']),
      );
      totalsByGroup[entry.key] = previousTotal + _entered(entry.key);
    }

    _applyReceivedTotalsAcrossCavities(items, totalsByGroup);
    return items;
  }

  Widget _buildReceivedQuantitySummaryByMold() {
    final previewItems = _previewItemsWithEnteredReceipt();
    final groupedItems = _groupItems(previewItems);

    if (groupedItems.isEmpty) return const SizedBox.shrink();

    final groupedByMold =
        <String, List<MapEntry<String, List<Map<String, dynamic>>>>>{};

    for (final entry in groupedItems.entries) {
      final item = entry.value.first;
      final moldId = _stringValue(item['moldProductId']);
      groupedByMold.putIfAbsent(moldId, () => []).add(entry);
    }

    var grandTotal = 0;

    String displayName(Map<String, dynamic> item) {
      final candidates = [
        item['productName'],
        item['modelName'],
        item['displayName'],
        item['productId'],
      ];
      for (final candidate in candidates) {
        final value = _stringValue(candidate);
        if (value.isNotEmpty) return value;
      }
      return 'Unknown product';
    }

    String moldDisplayName(
      String moldId,
      List<MapEntry<String, List<Map<String, dynamic>>>> entries,
    ) {
      for (final entry in entries) {
        final item = entry.value.first;
        final name = _stringValue(item['moldName']);
        if (name.isNotEmpty) return name;
      }
      return moldId.isEmpty ? 'Unknown mold' : moldId;
    }

    final moldSections = <Widget>[];

    for (final moldEntry in groupedByMold.entries) {
      final entries = moldEntry.value;
      final moldTotal = entries.fold<int>(
        0,
        (sum, entry) =>
            sum + _toInt(entry.value.first['receivedQuantity']),
      );
      grandTotal += moldTotal;

      final rows = <Widget>[];
      for (final entry in entries) {
        final item = entry.value.first;
        final quantity = _toInt(item['receivedQuantity']);
        final component = _stringValue(item['componentType']);
        final material = _materialType(item);
        final side = _side(item);
        final details = <String>[
          displayName(item),
          if (material.isNotEmpty && material != '-') material,
          if (side.isNotEmpty) side[0].toUpperCase() + side.substring(1),
          if (component.isNotEmpty) component,
        ];

        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    details.join(' • '),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$quantity pcs',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      moldSections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      moldDisplayName(moldEntry.key, entries),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343741),
                      ),
                    ),
                  ),
                  Text(
                    '$moldTotal pcs',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3F51B5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...rows,
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Received Quantity Summary'),
          const SizedBox(height: 4),
          Text(
            'Cumulative received pieces by mold, product, material and side. '
            'Includes previous receipts and the quantities entered above.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          ...moldSections,
          const Divider(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Received Quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
              Text(
                '$grandTotal pcs',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedShotsByMoldSummary() {
    final previewItems = _previewItemsWithEnteredReceipt();
    final groupedByMold = <String, List<Map<String, dynamic>>>{};

    for (final item in previewItems) {
      final moldId = _stringValue(item['moldProductId']);
      groupedByMold.putIfAbsent(moldId, () => []).add(item);
    }

    if (groupedByMold.isEmpty) return const SizedBox.shrink();

    final rows = groupedByMold.entries.map((entry) {
      final moldItems = entry.value;
      final moldName = _stringValue(moldItems.first['moldName']).isNotEmpty
          ? _stringValue(moldItems.first['moldName'])
          : (_stringValue(moldItems.first['productName']).isNotEmpty
              ? _stringValue(moldItems.first['productName'])
              : entry.key);
      return MapEntry(moldName, _calculateShots(moldItems, 'receivedQuantity'));
    }).toList();

    final totalShots = rows.fold<int>(0, (sum, row) => sum + row.value);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Received Shots Summary by Mold'),
          const SizedBox(height: 4),
          Text(
            'Includes quantities already received plus the quantities entered above.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.key,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF343741),
                        ),
                      ),
                    ),
                    Text(
                      '${row.value} shots',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3F51B5),
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Received Shots',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
              Text(
                '$totalShots shots',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _runnerShotsByGroup(
    Map<String, List<Map<String, dynamic>>> groupedItems,
    Map<String, int> quantities,
  ) {
    final result = <String, int>{};
    final groupsByMoldMaterialComponent = <String, List<String>>{};

    for (final entry in quantities.entries) {
      final group = groupedItems[entry.key];
      if (group == null || group.isEmpty || entry.value <= 0) continue;

      final item = group.first;
      final moldId = _stringValue(item['moldProductId']);
      final material = _materialType(item).toLowerCase();
      final component = _stringValue(item['componentType']).toLowerCase();
      final key = '$moldId|$material|$component';

      // Calculate runner shots once per mold, material and component.
      groupsByMoldMaterialComponent
          .putIfAbsent(key, () => <String>[])
          .add(entry.key);
    }

    for (final entry in groupsByMoldMaterialComponent.entries) {
      final groupKeys = entry.value;
      if (groupKeys.isEmpty) continue;

      final firstItem = groupedItems[groupKeys.first]!.first;
      final moldId = _stringValue(firstItem['moldProductId']);
      final component = _stringValue(firstItem['componentType']).toLowerCase();

      final totalPieces = groupKeys.fold<int>(
        0,
        (sum, key) => sum + (quantities[key] ?? 0),
      );
      if (totalPieces <= 0) continue;

      int piecesPerShot;

      if (component == 'focus') {
        // Focus runner shots must use only the cavities selected in THIS
        // molding order. A 2-cavity mold may be ordered with only cavity 1.
        // Count distinct cavityNumber/cavity values across the selected order
        // items, rather than reading the mold's physical cavityCount.
        final selectedCavities = <String>{};
        // Read the complete order, not only groups receiving pieces now.
        // This preserves the originally selected cavity count during partial
        // receipts (for example, one selected cavity may have 0 received yet).
        for (final orderItem in _items()) {
          if (_stringValue(orderItem['moldProductId']) != moldId ||
              _materialType(orderItem).toLowerCase() !=
                  _materialType(firstItem).toLowerCase() ||
              _stringValue(orderItem['componentType']).toLowerCase() !=
                  'focus') {
            continue;
          }
          final cavity = _stringValue(
            orderItem['cavityNumber'] ?? orderItem['cavity'],
          );
          if (cavity.isNotEmpty) selectedCavities.add(cavity);
        }

        // A missing cavity selection is not safe to guess for Focus.
        if (selectedCavities.isEmpty) {
          debugPrint(
            'Focus runner calculation skipped: selected cavity values are missing for mold $moldId',
          );
          continue;
        }
        piecesPerShot = selectedCavities.length;
      } else if (component == 'temple') {
        // Keep the existing Temple calculation based on the mold's physical
        // cavity count. Left + Right are paired outputs per selected cavity.
        final cavityCount = _moldCavityCountCache[moldId] ?? 0;
        if (cavityCount <= 0) {
          debugPrint(
            'Temple runner calculation skipped: cavityCount missing for mold $moldId',
          );
          continue;
        }
        piecesPerShot = cavityCount * 2;
      } else {
        continue;
      }

      final totalShots = (totalPieces + piecesPerShot - 1) ~/ piecesPerShot;

      // Assign runner shots to one group only so the supplier ledger is
      // credited exactly once for this mold/material/component.
      result[groupKeys.first] = totalShots;
      for (var i = 1; i < groupKeys.length; i++) {
        result[groupKeys[i]] = 0;
      }
    }

    return result;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _buildOrderDateField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Order Date *'),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: _isSaving
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedOrderDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: const Color(0xFF3F51B5),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null && mounted) {
                      setState(() {
                        _selectedOrderDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    }
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                ),
                suffixIcon: const Icon(Icons.arrow_drop_down),
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
              child: Text(
                _formatDate(_selectedOrderDate),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF343741),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This date will be saved as the Drumming order date.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReceiving() async {
    if (_companyId == null || _order == null || _isSaving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final runnerGrams = double.tryParse(_runnerGramsController.text.trim());
    final wastagePercent = double.tryParse(
      _wastagePercentController.text.trim(),
    );
    final virginKg = double.tryParse(_virginRatioKgController.text.trim());
    final grindingKg = double.tryParse(_grindingRatioKgController.text.trim());

    if (runnerGrams == null ||
        !runnerGrams.isFinite ||
        runnerGrams < 0 ||
        wastagePercent == null ||
        wastagePercent < 0 ||
        wastagePercent > 100 ||
        virginKg == null ||
        !virginKg.isFinite ||
        virginKg < 0 ||
        grindingKg == null ||
        !grindingKg.isFinite ||
        grindingKg < 0 ||
        virginKg + grindingKg <= 0) {
      _showMessage(
        'Enter valid calculation settings. Virgin and Grinding kg values must total more than zero and wastage must be between 0 and 100%.',
        error: true,
      );
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

    final weightByGroup = <String, double>{};

    final calculationsByGroup = <String, Map<String, double>>{};
    final runnerShotsByGroup = _runnerShotsByGroup(groupedItems, changes);

    // Focus uses the distinct cavities selected in the order itself.
    // Temple retains the physical mold cavityCount calculation.
    for (final entry in changes.entries) {
      final group = groupedItems[entry.key];
      if (group == null || group.isEmpty) continue;

      final item = group.first;
      final component = _stringValue(item['componentType']).toLowerCase();
      final moldId = _stringValue(item['moldProductId']);

      if (component == 'focus' && !runnerShotsByGroup.containsKey(entry.key)) {
        final selectedCavities = <String>{};
        for (final relatedEntry in changes.entries) {
          final relatedGroup = groupedItems[relatedEntry.key];
          if (relatedGroup == null || relatedGroup.isEmpty) continue;
          final relatedItem = relatedGroup.first;
          if (_stringValue(relatedItem['moldProductId']) != moldId ||
              _materialType(relatedItem).toLowerCase() !=
                  _materialType(item).toLowerCase() ||
              _stringValue(relatedItem['componentType']).toLowerCase() !=
                  'focus') {
            continue;
          }
          for (final cavityItem in relatedGroup) {
            final cavity = _stringValue(
              cavityItem['cavityNumber'] ?? cavityItem['cavity'],
            );
            if (cavity.isNotEmpty) selectedCavities.add(cavity);
          }
        }
        if (selectedCavities.isEmpty) {
          _showMessage(
            'Unable to calculate Focus runner shots: selected cavity information is missing from the molding order for ${_stringValue(item['productName']).isEmpty ? moldId : item['productName']}.',
            error: true,
          );
          return;
        }
      }

      if (component == 'temple' && (_moldCavityCountCache[moldId] ?? 0) <= 0) {
        _showMessage(
          'Unable to calculate Temple runner shots: cavityCount is missing for mold ${_stringValue(item['productName']).isEmpty ? moldId : item['productName']}. Check companies/$_companyId/products/$moldId.',
          error: true,
        );
        return;
      }
    }

    for (final entry in changes.entries) {
      final productWeight = _enteredWeight(entry.key);

      if (productWeight <= 0) {
        _showMessage(
          'Enter a received weight greater than 0 kg for every variant with received pieces.',

          error: true,
        );

        return;
      }

      final group = groupedItems[entry.key];

      if (group == null || group.isEmpty) continue;

      final item = group.first;

      final ratios = _ratioFractions(item, fallback: _order);

      if (ratios == null) {
        _showMessage(
          'Virgin and Grinding ratios are missing or invalid for ${_stringValue(item['productName']).isEmpty ? _stringValue(item['modelName']) : _stringValue(item['productName'])}. Please update the molding order ratios first.',

          error: true,
        );

        return;
      }

      if (_materialFieldPrefix(item).isEmpty) {
        _showMessage(
          'Unknown material type for a received variant.',

          error: true,
        );

        return;
      }

      weightByGroup[entry.key] = productWeight;

      calculationsByGroup[entry.key] = _granuleCalculation(
        productWeight,
        ratios,
        runnerShotsByGroup[entry.key] ?? 0,
      );
    }

    final weight = weightByGroup.values.fold<double>(
      0,

      (sum, value) => sum + value,
    );

    final totalBags = _toInt(_bagsController.text);

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

      final moldingLaborId = _stringValue(_order?['supplierId']);

      if (moldingLaborId.isEmpty) {
        throw Exception(
          'The molding order has no molding supplier/labor assigned, so granule balances cannot be updated.',
        );
      }

      final laborBalanceRef = companyRef
          .collection('labor_granules_balances')
          .doc(moldingLaborId);

      // One immutable supplier-ledger transaction for this goods receipt.
      // The generated Drumming order ID is also used as the receipt ID.
      final laborReceiptTransactionRef = laborBalanceRef
          .collection('transactions')
          .doc(drummingOrderRef.id);

      final granuleTransactionRefs =
          <String, DocumentReference<Map<String, dynamic>>>{};

      for (final key in changes.keys) {
        granuleTransactionRefs[key] =
            companyRef.collection('granule_transactions').doc();
      }

      final selectedOrderDate = Timestamp.fromDate(
        DateTime(
          _selectedOrderDate.year,
          _selectedOrderDate.month,
          _selectedOrderDate.day,
        ),
      );

      String? generatedDrummingOrderNumber;

      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(orderRef);

        final counterSnapshot = await transaction.get(drummingCounterRef);

        final laborBalanceSnapshot = await transaction.get(laborBalanceRef);

        if (!snapshot.exists) {
          throw Exception('Molding order no longer exists.');
        }

        final existing = Map<String, dynamic>.from(snapshot.data()!);

        final existingRawItems = existing['items'];

        if (existingRawItems is! List) {
          throw Exception('Molding order items are missing.');
        }

        final updatedItems = existingRawItems
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();

        // Store one cumulative received total per mold/model/material/side.
        // Cavity rows remain available for order configuration, but no longer
        // receive artificial sequential allocations.
        final groupedExisting = _groupItems(updatedItems);
        final receivedTotalsByGroup = <String, int>{};
        for (final entry in groupedExisting.entries) {
          final previousTotal = entry.value.fold<int>(
            0,
            (sum, item) => sum + _toInt(item['receivedQuantity']),
          );
          receivedTotalsByGroup[entry.key] =
              previousTotal + (changes[entry.key] ?? 0);
        }

        // Store each group's cumulative quantity across its actual cavity
        // rows. For a 2-cavity TH-02 group, 5,400 Right pieces become 2,700
        // on cavity 1 and 2,700 on cavity 2. Left is split independently.
        _applyReceivedTotalsAcrossCavities(updatedItems, receivedTotalsByGroup);

        // Keep nested mold blocks synchronized using the same cavity split.
        final updatedMolds = <Map<String, dynamic>>[];
        final rawMolds = existing['molds'];
        if (rawMolds is List) {
          for (final rawMold in rawMolds) {
            if (rawMold is! Map) continue;
            final mold = Map<String, dynamic>.from(rawMold);
            final rawMoldItems = mold['items'];
            if (rawMoldItems is List) {
              final nestedItems = rawMoldItems
                  .whereType<Map>()
                  .map((rawItem) => Map<String, dynamic>.from(rawItem))
                  .toList();
              _applyReceivedTotalsAcrossCavities(
                nestedItems,
                receivedTotalsByGroup,
              );
              mold['items'] = nestedItems;
              mold['receivedPieces'] = nestedItems.fold<int>(
                0,
                (sum, item) => sum + _toInt(item['receivedQuantity']),
              );
              mold['receivedShots'] = _calculateShots(
                nestedItems,
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
        debugPrint('Total received shots: $receivedShots');

        final updatedGroups = _groupItems(updatedItems);
        final allItemsComplete = updatedItems.isNotEmpty &&
            updatedGroups.values.every((group) {
              final orderedTotal = group.fold<int>(
                0,
                (sum, item) =>
                    sum + _toInt(item['orderedQuantity'] ?? item['quantity']),
              );
              final receivedTotal = group.fold<int>(
                0,
                (sum, item) => sum + _toInt(item['receivedQuantity']),
              );
              return receivedTotal >= orderedTotal;
            });

        final status = allItemsComplete ? 'Received' : 'Partially Received';

        final receiptItemsByGroup = <String, Map<String, dynamic>>{};
        for (final entry in changes.entries) {
          if (entry.value <= 0) continue;
          final group = groupedItems[entry.key];
          if (group == null || group.isEmpty) continue;
          receiptItemsByGroup[entry.key] = {
            ...group.first,
            'cavityNumber': null,
            'cavity': null,
            'orderedQuantity': entry.value,
            'receivedQuantity': 0,
            'sourceMoldingItemKey': entry.key,
          };
        }
        final receiptItems = receiptItemsByGroup.values.toList();

        if (receiptItems.isEmpty) {
          throw Exception(
            'No received items were found for the Drumming order.',
          );
        }

        final laborDeductions = <String, double>{};

        final runnerCredits = <String, double>{};

        final balanceData = laborBalanceSnapshot.data() ?? <String, dynamic>{};
        for (final receiptItem in receiptItems) {
          final groupKey = _stringValue(receiptItem['sourceMoldingItemKey']);

          final calculation = calculationsByGroup[groupKey];

          if (calculation == null) {
            throw Exception(
              'Granule calculation is missing for a received variant.',
            );
          }

          receiptItem.addAll(calculation);

          receiptItem['sourceMoldingItemKey'] = groupKey;

          final prefix = _materialFieldPrefix(receiptItem);

          if (prefix.isEmpty) {
            throw Exception('Unknown material type for a received variant.');
          }

          final virginField = '${prefix}VirginKg';

          final grindingField = '${prefix}GrindingKg';

          laborDeductions[virginField] =
              (laborDeductions[virginField] ?? 0) +
              calculation['virginDeductionKg']!;

          laborDeductions[grindingField] =
              (laborDeductions[grindingField] ?? 0) +
              calculation['grindingDeductionKg']!;

          runnerCredits[grindingField] =
              (runnerCredits[grindingField] ?? 0) +
              calculation['runnerRecoveredKg']!;
        }

        final updatedLaborBalance = <String, dynamic>{
          'laborId': moldingLaborId,

          'laborName': _stringValue(existing['supplierName']),

          'updatedAt': FieldValue.serverTimestamp(),

          'lastMoldingOrderId': widget.orderId,

          'lastMoldingOrderNumber': _stringValue(existing['orderNumber']),

          'lastUpdatedByUid': currentUser.uid,
        };

        var hasNegativeBalance = !laborBalanceSnapshot.exists;

        // Deduct estimated Virgin and Grinding consumed during molding.
        for (final entry in laborDeductions.entries) {
          final current = _toDouble(balanceData[entry.key]);
          updatedLaborBalance[entry.key] = current - entry.value;
        }

        // Recovered runners stay with the molding supplier until physically
        // returned to the factory, so credit Grinding back to the supplier ledger.
        // Do not update factory inventory during this receiving step.
        for (final entry in runnerCredits.entries) {
          final balanceAfterConsumption =
              updatedLaborBalance.containsKey(entry.key)
                  ? _toDouble(updatedLaborBalance[entry.key])
                  : _toDouble(balanceData[entry.key]);
          updatedLaborBalance[entry.key] =
              balanceAfterConsumption + entry.value;
        }

        // Check the final net balances after applying runner recovery credits.
        for (final key in {...laborDeductions.keys, ...runnerCredits.keys}) {
          if (_toDouble(updatedLaborBalance[key]) < -0.000001) {
            hasNegativeBalance = true;
          }
        }
        updatedLaborBalance['requiresReconciliation'] = hasNegativeBalance;
        updatedLaborBalance['lastRunnerRecoveryOrderId'] = widget.orderId;
        // Capture the supplier's balance immediately before and after THIS
        // receipt. These snapshots make historical order balances reliable
        // even after later receipts or other supplier transactions.
        final affectedBalanceFields = <String>{
          ...laborDeductions.keys,
          ...runnerCredits.keys,
        };

        final openingBalance = <String, double>{};
        final closingBalance = <String, double>{};
        for (final field in affectedBalanceFields) {
          openingBalance[field] = _toDouble(balanceData[field]);
          closingBalance[field] = _toDouble(updatedLaborBalance[field]);
        }

        final receiptDeductions = <String, double>{
          for (final entry in laborDeductions.entries) entry.key: entry.value,
        };
        final receiptRunnerCredits = <String, double>{
          for (final entry in runnerCredits.entries) entry.key: entry.value,
        };

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

                'receivedProductWeightKg': item['receivedProductWeightKg'],

                'productWeightWithWastageKg':
                    item['productWeightWithWastageKg'],

                'estimatedGranulesUsedKg': item['estimatedGranulesUsedKg'],

                'runnerRecoveredKg': item['runnerRecoveredKg'],

                'virginRatio': item['virginRatio'],

                'grindingRatio': item['grindingRatio'],

                'virginConsumedKg': item['virginConsumedKg'],

                'grindingConsumedKg': item['grindingConsumedKg'],

                'totalWastageKg': item['totalWastageKg'],
              };
            }).toList();

        history.add({
          'receiptId': drummingOrderRef.id,

          'supplierTransactionId': laborReceiptTransactionRef.id,

          'receivedAt': Timestamp.now(),

          'receivedByUid': currentUser.uid,

          'supplierOpeningBalance': openingBalance,

          'supplierDeductions': receiptDeductions,

          'supplierRunnerCredits': receiptRunnerCredits,

          'supplierClosingBalance': closingBalance,

          'weight': weight > 0 ? weight : null,

          'estimatedGranulesUsedKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['estimatedGranulesUsedKg']),
          ),

          'runnerRecoveredKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['runnerRecoveredKg']),
          ),

          'totalWastageKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['totalWastageKg']),
          ),

          'granuleCalculationSettings': {
            'runnerWeightPerShotGrams': _toDouble(_runnerGramsController.text),
            'wastagePercent': _toDouble(_wastagePercentController.text),
            'virginRatioKg': _toDouble(_virginRatioKgController.text),
            'grindingRatioKg': _toDouble(_grindingRatioKgController.text),
          },
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

        transaction.set(
          laborBalanceRef,
          updatedLaborBalance,
          SetOptions(merge: true),
        );

        // Persist one receipt-level transaction with complete item details
        // and exact supplier balance snapshots. This is separate from the
        // existing per-variant granule_transactions entries below.
        transaction.set(laborReceiptTransactionRef, {
          'transactionType': 'Molding Goods Receipt',
          'status': 'Posted',
          'companyId': _companyId,
          'laborId': moldingLaborId,
          'laborName': _stringValue(existing['supplierName']),
          'moldingOrderId': widget.orderId,
          'moldingOrderNumber': _stringValue(existing['orderNumber']),
          'receiptId': laborReceiptTransactionRef.id,
          'receiptNumber': generatedDrummingOrderNumber,
          'drummingOrderId': drummingOrderRef.id,
          'drummingOrderNumber': generatedDrummingOrderNumber,
          'drummingSupplierId': _selectedDrummingSupplierId,
          'drummingSupplierName': _selectedDrummingSupplierName ?? '',
          'receivedAt': FieldValue.serverTimestamp(),
          'orderDate': selectedOrderDate,
          'receivedByUid': currentUser.uid,
          'receivedProductWeightKg': weight,
          'totalBags': totalBags,
          'remarks': _remarksController.text.trim(),
          'granuleCalculationSettings': {
            'runnerWeightPerShotGrams': _toDouble(_runnerGramsController.text),
            'wastagePercent': _toDouble(_wastagePercentController.text),
            'virginRatioKg': _toDouble(_virginRatioKgController.text),
            'grindingRatioKg': _toDouble(_grindingRatioKgController.text),
          },
          'openingBalance': openingBalance,
          'virginAndGrindingDeductions': receiptDeductions,
          'runnerCredits': receiptRunnerCredits,
          'closingBalance': closingBalance,
          'estimatedGranulesUsedKg': receiptItems.fold<double>(
            0,
            (sum, item) => sum + _toDouble(item['estimatedGranulesUsedKg']),
          ),
          'runnerRecoveredKg': receiptItems.fold<double>(
            0,
            (sum, item) => sum + _toDouble(item['runnerRecoveredKg']),
          ),
          'totalWastageKg': receiptItems.fold<double>(
            0,
            (sum, item) => sum + _toDouble(item['totalWastageKg']),
          ),
          'items': historyItems,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': currentUser.uid,
        });

        for (final receiptItem in receiptItems) {
          final groupKey = _stringValue(receiptItem['sourceMoldingItemKey']);

          final granuleTransactionRef = granuleTransactionRefs[groupKey];

          if (granuleTransactionRef == null) continue;

          transaction.set(granuleTransactionRef, {
            'transactionType': 'Molding Consumption and Runner Recovery',

            'runnerRecoveryCreditedToMoldingSupplierLedger': true,

            'runnerRecoveryReturnedToFactory': false,

            'status': 'Posted',

            'companyId': _companyId,

            'laborId': moldingLaborId,

            'laborName': _stringValue(existing['supplierName']),

            'moldingOrderId': widget.orderId,

            'moldingOrderNumber': _stringValue(existing['orderNumber']),

            'receiptId': laborReceiptTransactionRef.id,

            'supplierTransactionId': laborReceiptTransactionRef.id,

            'drummingOrderId': drummingOrderRef.id,

            'materialType': _materialType(receiptItem),

            'componentType': receiptItem['componentType'],

            'productId': receiptItem['productId'],

            'productName': receiptItem['productName'],

            'sourceMoldingItemKey': groupKey,

            ...receiptItem.entries
                .where(
                  (entry) => [
                    'receivedProductWeightKg',

                    'productWeightWithWastageKg',

                    'estimatedGranulesUsedKg',

                    'runnerRecoveredKg',

                    'virginRatio',

                    'grindingRatio',

                    'virginConsumedKg',

                    'grindingConsumedKg',

                    'virginDeductionKg',

                    'grindingDeductionKg',

                    'totalWastageKg',
                    'runnerWeightPerShotGrams',
                    'moldingShotsUsedForRunnerCalculation',
                    'wastageRatePercent',
                    'virginRatioKg',
                    'grindingRatioKg',
                  ].contains(entry.key),
                )
                .fold<Map<String, dynamic>>(
                  <String, dynamic>{},

                  (map, entry) => map..[entry.key] = entry.value,
                ),

            'createdAt': FieldValue.serverTimestamp(),

            'createdByUid': currentUser.uid,
          });
        }

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

          'orderDate': selectedOrderDate,

          'createdAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),

          'createdByUid': currentUser.uid,

          'createdByName': currentUser.email ?? '',

          'supplierId': _selectedDrummingSupplierId,

          'supplierName': _selectedDrummingSupplierName ?? '',

          'sourceMoldingOrderId': widget.orderId,

          'sourceMoldingOrderNumber': _stringValue(existing['orderNumber']),

          'moldingSupplierId': existing['supplierId'],

          'moldingSupplierName': existing['supplierName'],

          'granuleCalculationSettings': {
            'runnerWeightPerShotGrams': _toDouble(_runnerGramsController.text),
            'wastagePercent': _toDouble(_wastagePercentController.text),
            'virginRatioKg': _toDouble(_virginRatioKgController.text),
            'grindingRatioKg': _toDouble(_grindingRatioKgController.text),
          },

          'moldingReceiptId': drummingOrderRef.id,

          'moldingReceiptAt': FieldValue.serverTimestamp(),

          'moldingReceiptWeight': weight > 0 ? weight : null,

          'estimatedGranulesUsedKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['estimatedGranulesUsedKg']),
          ),

          'runnerRecoveredKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['runnerRecoveredKg']),
          ),

          'totalWastageKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['totalWastageKg']),
          ),

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

          // Canonical cumulative totals keyed by mold/model/material/side.
          // Item-level receivedQuantity mirrors each total on its first row
          // for compatibility with screens that still read the items array.
          'receivedTotals': receivedTotalsByGroup,

          'receivedPieces': totalReceivedPieces,

          'receivedShots': receivedShots,

          'status': status,

          'lastReceivedAt': FieldValue.serverTimestamp(),

          'lastReceivedByUid': currentUser.uid,

          'lastReceivedWeight': weight > 0 ? weight : null,

          'lastEstimatedGranulesUsedKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['estimatedGranulesUsedKg']),
          ),

          'lastRunnerRecoveredKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['runnerRecoveredKg']),
          ),

          'lastTotalWastageKg': receiptItems.fold<double>(
            0,

            (sum, item) => sum + _toDouble(item['totalWastageKg']),
          ),

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

      print('Error receiving molding goods: $e');

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
      onChanged: (_) {
        if (mounted) setState(() {});
      },

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

  Widget _buildGranulePreview(Map<String, dynamic> item, String key) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _weightControllerFor(key),
        _controllerFor(key),
        _runnerGramsController,
        _wastagePercentController,
        _virginRatioKgController,
        _grindingRatioKgController,
      ]),
      builder: (context, _) => _buildGranulePreviewContent(item, key),
    );
  }

  Widget _buildGranulePreviewContent(Map<String, dynamic> item, String key) {
    final productWeight = _enteredWeight(key);

    if (productWeight <= 0) return const SizedBox.shrink();

    final ratios = _ratioFractions(item, fallback: _order);

    if (ratios == null) return const SizedBox.shrink();

    final previewGroups = _groupItems(_items());
    final previewQuantities = <String, int>{};
    for (final groupKey in previewGroups.keys) {
      final entered = _entered(groupKey);
      if (entered > 0) previewQuantities[groupKey] = entered;
    }
    final previewRunnerShots = _runnerShotsByGroup(
      previewGroups,
      previewQuantities,
    );

    final calculation = _granuleCalculation(
      productWeight,
      ratios,
      previewRunnerShots[key] ?? 0,
    );

    String kg(dynamic value) => '${_toDouble(value).toStringAsFixed(3)} kg';

    return Container(
      margin: const EdgeInsets.only(top: 10),

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FF),

        borderRadius: BorderRadius.circular(9),

        border: Border.all(color: const Color(0xFFDDE3FF)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Estimated Granule Calculation',

            style: GoogleFonts.poppins(
              fontSize: 11,

              fontWeight: FontWeight.w600,

              color: const Color(0xFF3F51B5),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Product weight + ${calculation['wastageRatePercent']}% wastage: ${kg(calculation['productWeightWithWastageKg'])}',

            style: GoogleFonts.poppins(fontSize: 11),
          ),

          Text(
            'Total granules used (adjusted product + runner): ${kg(calculation['estimatedGranulesUsedKg'])}',

            style: GoogleFonts.poppins(fontSize: 11),
          ),

          Text(
            'Runner credited to Grinding (${_toDouble(calculation['runnerWeightPerShotGrams']).toStringAsFixed(2)} g/shot × ${_toInt(calculation['moldingShotsUsedForRunnerCalculation'])} shots): ${kg(calculation['runnerRecoveredKg'])}',

            style: GoogleFonts.poppins(fontSize: 11),
          ),
          Text(
            'Virgin : Grinding reference quantity: ${calculation['virginRatioKg']} kg : ${calculation['grindingRatioKg']} kg',
            style: GoogleFonts.poppins(fontSize: 11),
          ),

          Text(
            'Virgin deduction: ${kg(calculation['virginDeductionKg'])} (includes ${calculation['wastageRatePercent']}% wastage)',

            style: GoogleFonts.poppins(fontSize: 11),
          ),

          Text(
            'Grinding deduction: ${kg(calculation['grindingDeductionKg'])} (includes ${calculation['wastageRatePercent']}% wastage)',

            style: GoogleFonts.poppins(fontSize: 11),
          ),
        ],
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

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          _numberField(
            label: 'Receive Now (Pieces)',

            controller: _controllerFor(key),

            helper:
                'Extra pieces are allowed when production exceeds the planned quantity',
          ),

          const SizedBox(height: 10),

          TextFormField(
            controller: _weightControllerFor(key),

            keyboardType: const TextInputType.numberWithOptions(decimal: true),

            style: GoogleFonts.poppins(fontSize: 13),

            decoration: InputDecoration(
              labelText: 'Received Product Weight',

              helperText:
                  'Actual weight for this variant; used to calculate granule consumption',

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

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),

                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),

          _buildGranulePreview(item, key),
        ],
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

  Widget _buildCalculationSettingsCard() {
    Widget field({
      required String label,
      required TextEditingController controller,
      required String helper,
    }) {
      return TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            'Granule Calculation Settings',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF343741),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Change these defaults before receiving. The preview and saved ledger calculations use the same values.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final width =
                  wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  SizedBox(
                    width: width,
                    child: field(
                      label: 'Runner weight per shot (grams)',
                      controller: _runnerGramsController,
                      helper: 'Default: 4 grams per molding shot',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: field(
                      label: 'Wastage (%)',
                      controller: _wastagePercentController,
                      helper: 'Default: 3%',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: field(
                      label: 'Virgin granules (kg)',
                      controller: _virginRatioKgController,
                      helper: 'Default: 10 kg (reference mixing quantity)',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: field(
                      label: 'Grinding granules (kg)',
                      controller: _grindingRatioKgController,
                      helper: 'Default: 3 kg (reference mixing quantity)',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final items = _items();

    final focusItems = items.where(_isFocus).toList();

    final templeItems = items.where(_isTemple).toList();

    // Focus  -> productId + material*

    // Temple -> productId + material + side*

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
          _buildOrderDateField(),

          const SizedBox(height: 12),

          _buildCalculationSettingsCard(),

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

          _buildReceivedQuantitySummaryByMold(),

          _buildReceivedShotsByMoldSummary(),
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
