import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

class CreateMoldingOrderPage extends StatefulWidget {
  final bool isEditMode;

  final String? orderId;

  const CreateMoldingOrderPage({
    super.key,

    this.isEditMode = false,

    this.orderId,
  });

  @override
  State<CreateMoldingOrderPage> createState() => _CreateMoldingOrderPageState();
}

class _MoldingProduct {
  final String id;

  final String modelId;

  final String modelName;

  final String productCode;

  final List<String> variants;

  final Map<String, String> variantProductIds;

  const _MoldingProduct({
    required this.id,

    required this.modelId,

    required this.modelName,

    required this.productCode,

    required this.variants,

    required this.variantProductIds,
  });

  String? productIdForVariant(String variant) {
    return variantProductIds[variant];
  }

  String get displayName {
    if (productCode.trim().isEmpty) return modelName;

    return '$modelName ($productCode)';
  }
}

class _MoldingCavityEntry {
  final String cavity;

  final String? linkedModelId;

  String? productId;

  final Map<String, TextEditingController> quantityControllers = {};
  final Map<String, TextEditingController> virginRatioControllers = {};
  final Map<String, TextEditingController> grindingRatioControllers = {};

  _MoldingCavityEntry(this.cavity, {this.linkedModelId});

  void dispose() {
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in virginRatioControllers.values) {
      controller.dispose();
    }
    for (final controller in grindingRatioControllers.values) {
      controller.dispose();
    }

    quantityControllers.clear();
    virginRatioControllers.clear();
    grindingRatioControllers.clear();
  }

  int get totalQuantity {
    return quantityControllers.values.fold<int>(
      0,

      (total, controller) =>
          total + (int.tryParse(controller.text.trim()) ?? 0),
    );
  }
}

class _MoldingMoldEntry {
  String moldId;
  String moldName;
  List<String> moldCavities;
  Map<String, String?> moldCavityModelIds;
  List<_MoldingProduct> rawProducts;
  List<_MoldingCavityEntry> cavityEntries;
  bool isLoadingProducts;

  _MoldingMoldEntry({
    required this.moldId,
    required this.moldName,
    List<String>? moldCavities,
    Map<String, String?>? moldCavityModelIds,
    List<_MoldingProduct>? rawProducts,
    List<_MoldingCavityEntry>? cavityEntries,
    this.isLoadingProducts = false,
  })  : moldCavities = List<String>.from(moldCavities ?? const []),
        moldCavityModelIds = Map<String, String?>.from(
          moldCavityModelIds ?? const {},
        ),
        rawProducts = List<_MoldingProduct>.from(rawProducts ?? const []),
        cavityEntries = List<_MoldingCavityEntry>.from(
          cavityEntries ?? const [],
        );

  int get totalQuantity =>
      cavityEntries.fold<int>(0, (total, entry) => total + entry.totalQuantity);

  void dispose() {
    for (final entry in cavityEntries) {
      entry.dispose();
    }
    cavityEntries = [];
  }
}

class _CreateMoldingOrderPageState extends State<CreateMoldingOrderPage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isEditMode => widget.isEditMode;

  String? _companyId;

  List<Map<String, dynamic>> _moldingSuppliers = [];

  String? selectedSupplierId;
  String? selectedSupplier;

  List<Map<String, dynamic>> molds = [];
  List<_MoldingMoldEntry> moldEntries = [];

  bool isLoadingMolds = true;

  bool isSaving = false;

  // Edit-mode state.*

  String? _editingOrderNumber;

  String? _editingOrderStatus;

  Map<String, dynamic>? _existingOrderData;

  bool _isLoadingExistingOrder = false;

  bool _existingOrderLoaded = false;

  @override
  void initState() {
    super.initState();

    _loadCompanyAndMolds();
  }

  @override
  void dispose() {
    for (final moldEntry in moldEntries) {
      moldEntry.dispose();
    }

    super.dispose();
  }

  void _closePage([dynamic result]) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pop(result);
    });
  }

  Future<void> _loadCompanyAndMolds() async {
    final prefs = await SharedPreferences.getInstance();

    final companyId = prefs.getString('cachedCompanyId');

    if (!mounted) return;

    if (companyId == null || companyId.trim().isEmpty) {
      setState(() {
        _companyId = null;

        isLoadingMolds = false;
      });

      return;
    }

    setState(() {
      _companyId = companyId;
    });

    await _loadMoldingSuppliers();

    try {
      final snapshot =
          await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('products')
              .where('category', isEqualTo: 'Other')
              .where('type', isEqualTo: 'Mold')
              .get();

      final loaded =
          snapshot.docs.map((doc) {
            final data = doc.data();

            return <String, dynamic>{
              'id': doc.id,
              'displayName': _stringValue(
                data['displayName'] ?? doc.id,
              ),

              'cavities': _extractCavityDefinitions(data),
            };
          }).toList();

      loaded.sort(
        (a, b) => (a['displayName'] as String).compareTo(b['displayName'] as String),
      );

      if (!mounted) return;

      setState(() {
        molds = loaded;

        isLoadingMolds = false;
      });

      if (isEditMode &&
          widget.orderId != null &&
          widget.orderId!.trim().isNotEmpty) {
        await _loadExistingOrder(widget.orderId!.trim());
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingMolds = false;
      });

      _showMessage('Unable to load molds: $e');
    }
  }

  Future<void> _loadExistingOrder(String orderId) async {
    if (_companyId == null || _companyId!.trim().isEmpty) return;
    if (mounted) {
      setState(() {
        _isLoadingExistingOrder = true;
        _existingOrderLoaded = false;
      });
    }

    try {
      final orderRef = _firestore
          .collection('companies')
          .doc(_companyId)
          .collection('raw_orders')
          .doc(orderId);
      final snapshot = await orderRef.get();
      if (!snapshot.exists) {
        if (!mounted) return;
        _showMessage('Molding order was not found.');
        Navigator.of(context).pop();
        return;
      }
      final data = snapshot.data();
      if (data == null) {
        if (!mounted) return;
        _showMessage('Unable to load molding order details.');
        Navigator.of(context).pop();
        return;
      }

      final process = _stringValue(data['process']);
      if (process.isNotEmpty && process != 'Molding') {
        if (!mounted) return;
        _showMessage('This order is not a molding order.');
        Navigator.of(context).pop();
        return;
      }
      final status = _stringValue(data['status']);
      if (status.isNotEmpty && status != 'Ordered') {
        if (!mounted) return;
        _showMessage(
          'Only Ordered molding orders can be edited. Current status: $status.',
        );
        Navigator.of(context).pop();
        return;
      }

      final supplierId = _stringValue(data['supplierId']);
      final supplierName = _stringValue(data['supplierName']);
      final rawItems =
          data['items'] is List
              ? List<Map<String, dynamic>>.from(
                (data['items'] as List).whereType<Map>().map(
                  (item) => Map<String, dynamic>.from(item),
                ),
              )
              : <Map<String, dynamic>>[];

      final moldBlocks = <Map<String, dynamic>>[];
      if (data['molds'] is List && (data['molds'] as List).isNotEmpty) {
        for (final item in (data['molds'] as List).whereType<Map>()) {
          moldBlocks.add(Map<String, dynamic>.from(item));
        }
      } else {
        final moldId = _stringValue(data['moldId']);
        if (moldId.isNotEmpty) {
          moldBlocks.add({
            'moldId': moldId,
            'moldName': _stringValue(data['moldName']),
            'items': rawItems,
            'cavityCount': _intValue(data['moldCount']),
          });
        }
      }

      final loadedMolds = <_MoldingMoldEntry>[];
      for (final block in moldBlocks) {
        final moldId = _stringValue(block['moldId'] ?? block['id']);
        if (moldId.isEmpty) continue;
        final mold = _moldDefinition(moldId);
        if (mold == null) {
          throw Exception(
            'The mold "${_stringValue(block['moldName'])}" is no longer available in the product list.',
          );
        }

        final cavityModelIds = <String, String?>{};
        final cavityNames = <String>[];
        for (final item in ((mold['cavities'] as List?) ?? const [])) {
          final cavity =
              item is Map
                  ? _stringValue(item['cavity'])
                  : item.toString().trim();
          if (cavity.isEmpty) continue;
          cavityNames.add(cavity);
          cavityModelIds[cavity] =
              item is Map
                  ? (_stringValue(item['modelId']).isEmpty
                      ? null
                      : _stringValue(item['modelId']))
                  : null;
        }

        final entry = _MoldingMoldEntry(
          moldId: moldId,
          moldName: _stringValue(mold['displayName']),
          moldCavities: List<String>.from(cavityNames),
          moldCavityModelIds: Map<String, String?>.from(cavityModelIds),
          rawProducts: <_MoldingProduct>[],
          cavityEntries: <_MoldingCavityEntry>[],
          isLoadingProducts: true,
        );
        entry.rawProducts = await _fetchRawProductsForMold(
          moldId,
          cavityModelIds,
        );

        final blockItems =
            block['items'] is List
                ? List<Map<String, dynamic>>.from(
                  (block['items'] as List).whereType<Map>().map(
                    (item) => Map<String, dynamic>.from(item),
                  ),
                )
                : rawItems
                    .where(
                      (item) => _stringValue(item['moldProductId']) == moldId,
                    )
                    .toList();

        final selectedCavities = <String>[];
        final byCavity = <String, List<Map<String, dynamic>>>{};
        for (final item in blockItems) {
          final cavity = _resolveSavedCavityName(
            item['cavityNumber'],
            cavityNames,
          );
          if (cavity == null) continue;
          byCavity.putIfAbsent(cavity, () => []).add(item);
          if (!selectedCavities.contains(cavity)) selectedCavities.add(cavity);
        }
        final savedCavityCount = _intValue(
          block['cavityCount'] ?? block['moldCount'],
        );
        if (savedCavityCount > selectedCavities.length) {
          for (final cavity in cavityNames) {
            if (selectedCavities.length >= savedCavityCount) break;
            if (!selectedCavities.contains(cavity))
              selectedCavities.add(cavity);
          }
        }
        selectedCavities.sort(
          (a, b) => cavityNames.indexOf(a).compareTo(cavityNames.indexOf(b)),
        );

        for (final cavity in selectedCavities) {
          final savedItems = byCavity[cavity] ?? const <Map<String, dynamic>>[];
          final linkedModelId = cavityModelIds[cavity];
          final savedModelId = savedItems
              .map((item) => _stringValue(item['modelId']))
              .firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => linkedModelId ?? '',
              );
          final cavityEntry = _MoldingCavityEntry(
            cavity,
            linkedModelId: linkedModelId,
          );
          final product = _productById(entry, savedModelId);
          if (product != null) {
            cavityEntry.productId = product.id;
            for (final variant in product.variants) {
              cavityEntry.quantityControllers[variant] = TextEditingController(
                text: '0',
              );
              cavityEntry.virginRatioControllers[variant] =
                  TextEditingController(text: '10');
              cavityEntry.grindingRatioControllers[variant] =
                  TextEditingController(text: '3');
            }
            for (final item in savedItems) {
              final variant = _stringValue(item['variantType']);
              final quantityController = cavityEntry.quantityControllers[variant];
              final virginRatioController = cavityEntry.virginRatioControllers[variant];
              final grindingRatioController = cavityEntry.grindingRatioControllers[variant];
              if (quantityController != null) {
                quantityController.text = _intValue(item['orderedQuantity']).toString();
              }
              if (virginRatioController != null && item.containsKey('virginRatio')) {
                virginRatioController.text = _decimalValue(item['virginRatio'], fallback: 10);
              }
              if (grindingRatioController != null && item.containsKey('grindingRatio')) {
                grindingRatioController.text = _decimalValue(item['grindingRatio'], fallback: 3);
              }
            }
          }
          entry.cavityEntries.add(cavityEntry);
        }
        entry.isLoadingProducts = false;
        loadedMolds.add(entry);
      }

      if (loadedMolds.isEmpty)
        throw Exception('No valid molds were found in this molding order.');
      if (!mounted) {
        for (final entry in loadedMolds) entry.dispose();
        return;
      }
      setState(() {
        for (final entry in moldEntries) entry.dispose();
        moldEntries = loadedMolds;
        _existingOrderData = Map<String, dynamic>.from(data);
        _editingOrderNumber = _getOrderNumber(data);
        _editingOrderStatus = status.isEmpty ? 'Ordered' : status;
        selectedSupplierId = supplierId.isEmpty ? null : supplierId;
        selectedSupplier = supplierName.isEmpty ? null : supplierName;
        _isLoadingExistingOrder = false;
        _existingOrderLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to load molding order for editing: $e');
      Navigator.of(context).pop();
    }
  }

  String? _resolveSavedCavityName(
    dynamic savedCavityNumber,
    List<String> cavityNames,
  ) {
    if (cavityNames.isEmpty || savedCavityNumber == null) return null;

    final saved = _stringValue(savedCavityNumber);

    if (saved.isEmpty) return null;

    for (final cavity in cavityNames) {
      if (cavity == saved) return cavity;
    }

    final savedNumber = int.tryParse(saved);

    if (savedNumber != null) {
      for (var index = 0; index < cavityNames.length; index++) {
        final cavity = cavityNames[index];

        final match = RegExp(r'\d+').firstMatch(cavity);

        final cavityNumber =
            match == null ? null : int.tryParse(match.group(0)!);

        if (cavityNumber == savedNumber ||
            (cavityNumber == null && index + 1 == savedNumber))
          return cavity;
      }
    }

    return null;
  }

  Future<void> _loadMoldingSuppliers() async {
    if (_companyId == null || _companyId!.isEmpty) return;

    try {
      final snapshot =
          await _firestore
              .collection('companies')
              .doc(_companyId)
              .collection('suppliers')
              .where('role', isEqualTo: 'Molding')
              .get();

      final suppliers =
          snapshot.docs.map((doc) {
            final data = doc.data();

            return {'id': doc.id, ...data};
          }).toList();

      suppliers.sort(
        (a, b) => _supplierDisplayName(
          a,
        ).toLowerCase().compareTo(_supplierDisplayName(b).toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _moldingSuppliers = suppliers;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to load molding suppliers: $e');
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

  List<Map<String, String?>> _extractCavityDefinitions(
    Map<String, dynamic> data,
  ) {
    final raw = data['cavities'];

    if (raw is List && raw.isNotEmpty) {
      final values = <Map<String, String?>>[];

      for (var index = 0; index < raw.length; index++) {
        final item = raw[index];

        if (item is Map) {
          final rawCavity =
              item['cavityNumber'] ??
              item['name'] ??
              item['cavityName'] ??
              item['cavity'];

          final cavity =
              rawCavity is num
                  ? 'Cavity ${rawCavity.toInt()}'
                  : _stringValue(rawCavity ?? 'Cavity ${index + 1}');

          final modelId = _stringValue(
            item['modelId'] ?? item['rawModelId'] ?? item['productModelId'],
          );

          values.add({
            'cavity': cavity.isEmpty ? 'Cavity ${index + 1}' : cavity,

            'modelId': modelId.isEmpty ? null : modelId,
          });
        } else {
          final cavity = item?.toString().trim() ?? '';

          if (cavity.isNotEmpty) {
            values.add({'cavity': cavity, 'modelId': null});
          }
        }
      }

      if (values.isNotEmpty) return values;
    }

    final cavityCount = _intValue(
      data['cavityCount'] ?? data['numberOfCavities'] ?? data['cavitiesCount'],
    );

    if (cavityCount > 0) {
      return List.generate(
        cavityCount,

        (index) => {'cavity': 'Cavity ${index + 1}', 'modelId': null},
      );
    }

    return const [];
  }

  Future<List<_MoldingProduct>> _fetchRawProductsForMold(
    String moldId,
    Map<String, String?> cavityModelIds,
  ) async {
    if (_companyId == null) return const [];
    final modelIds =
        cavityModelIds.values
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toSet();
    if (modelIds.isEmpty) return const [];

    final snapshot =
        await _firestore
            .collection('companies')
            .doc(_companyId)
            .collection('products')
            .where('category', isEqualTo: 'Raw')
            .get();

    final grouped = <String, _RawProductAccumulator>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final modelId = _stringValue(data['modelId'] ?? data['productModelId']);
      if (!modelIds.contains(modelId)) continue;
      final modelName = _stringValue(
        data['modelName'] ?? data['name'] ?? data['productName'] ?? modelId,
      );
      final productCode = _stringValue(data['productCode']);
      final variant = _stringValue(
        data['type'] ?? data['variant'] ?? data['productVariant'],
      );
      if (variant.isEmpty) continue;

      final accumulator = grouped.putIfAbsent(
        modelId,
        () => _RawProductAccumulator(
          id: modelId,
          modelId: modelId,
          modelName: modelName,
          productCode: productCode,
        ),
      );
      accumulator.variants.add(variant);
      accumulator.variantProductIds[variant] = doc.id;
    }

    return grouped.values
        .map(
          (item) => _MoldingProduct(
            id: item.modelId,
            modelId: item.modelId,
            modelName: item.modelName,
            productCode: item.productCode,
            variants: item.variants.toList()..sort(),
            variantProductIds: Map<String, String>.from(item.variantProductIds),
          ),
        )
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Map<String, dynamic>? _moldDefinition(String? moldId) {
    if (moldId == null || moldId.isEmpty) return null;
    for (final mold in molds) {
      if (mold['id']?.toString() == moldId) return mold;
    }
    return null;
  }

  Future<void> _addMoldEntry() async {
    final available =
        molds.where((mold) {
          final id = mold['id']?.toString() ?? '';
          return id.isNotEmpty &&
              !moldEntries.any((entry) => entry.moldId == id);
        }).toList();
    if (available.isEmpty) {
      _showMessage(
        'All available molds have already been added to this order.',
      );
      return;
    }

    final entry = _MoldingMoldEntry(moldId: '', moldName: '');
    setState(() => moldEntries.add(entry));
  }

  Future<void> _selectMoldForEntry(
    _MoldingMoldEntry entry, {
    String? moldId,
  }) async {
    final id = moldId ?? entry.moldId;
    final mold = _moldDefinition(id);
    if (mold == null) return;

    final cavityModelIds = <String, String?>{};
    final cavityNames = <String>[];
    for (final item in ((mold['cavities'] as List?) ?? const [])) {
      final cavity =
          item is Map ? _stringValue(item['cavity']) : item.toString().trim();
      if (cavity.isEmpty) continue;
      cavityNames.add(cavity);
      cavityModelIds[cavity] =
          item is Map
              ? (_stringValue(item['modelId']).isEmpty
                  ? null
                  : _stringValue(item['modelId']))
              : null;
    }

    for (final cavityEntry in entry.cavityEntries) cavityEntry.dispose();
    entry.moldId = id;
    entry.moldName = _stringValue(mold['displayName']);
    entry.moldCavities = cavityNames;
    entry.moldCavityModelIds = cavityModelIds;
    entry.rawProducts = [];
    entry.cavityEntries = [];
    entry.isLoadingProducts = true;
    if (mounted) setState(() {});

    try {
      entry.rawProducts = await _fetchRawProductsForMold(id, cavityModelIds);
    } catch (e) {
      if (mounted) _showMessage('Unable to load raw products: $e');
    } finally {
      entry.isLoadingProducts = false;
      if (mounted) setState(() {});
    }
  }

  void _onMoldChanged(_MoldingMoldEntry entry, String? moldId) {
    if (moldId == null) return;
    if (moldEntries.any((item) => item != entry && item.moldId == moldId)) {
      _showMessage('This mold is already added to the order.');
      return;
    }
    _selectMoldForEntry(entry, moldId: moldId);
  }

  void _removeMoldEntry(_MoldingMoldEntry entry) {
    if (moldEntries.length <= 1) {
      _showMessage('At least one mold is required.');
      return;
    }
    entry.dispose();
    setState(() => moldEntries.remove(entry));
  }

  void _onCavitiesChanged(_MoldingMoldEntry moldEntry, List<String> cavities) {
    final existingByCavity = {
      for (final entry in moldEntry.cavityEntries) entry.cavity: entry,
    };
    for (final entry in moldEntry.cavityEntries) {
      if (!cavities.contains(entry.cavity)) entry.dispose();
    }
    moldEntry.cavityEntries =
        cavities.map((cavity) {
          return existingByCavity[cavity] ??
              _MoldingCavityEntry(
                cavity,
                linkedModelId: moldEntry.moldCavityModelIds[cavity],
              );
        }).toList();
    setState(() {});
  }

  void _onProductChanged(
    _MoldingMoldEntry moldEntry,
    _MoldingCavityEntry entry,
    String? productId,
  ) {
    for (final controller in entry.quantityControllers.values)
      controller.dispose();
    for (final controller in entry.virginRatioControllers.values)
      controller.dispose();
    for (final controller in entry.grindingRatioControllers.values)
      controller.dispose();
    entry.quantityControllers.clear();
    entry.virginRatioControllers.clear();
    entry.grindingRatioControllers.clear();
    final product = _productById(moldEntry, productId);
    if (product != null) {
      for (final variant in product.variants) {
        entry.quantityControllers[variant] = TextEditingController(text: '0');
        entry.virginRatioControllers[variant] = TextEditingController(text: '10');
        entry.grindingRatioControllers[variant] = TextEditingController(text: '3');
      }
    }
    setState(() => entry.productId = productId);
  }

  _MoldingProduct? _productById(
    _MoldingMoldEntry moldEntry,
    String? productId,
  ) {
    if (productId == null) return null;
    for (final product in moldEntry.rawProducts) {
      if (product.id == productId) return product;
    }
    return null;
  }

  List<_MoldingProduct> _availableProductsFor(
    _MoldingMoldEntry moldEntry,
    _MoldingCavityEntry current,
  ) {
    if (moldEntry.rawProducts.length <= 1) return moldEntry.rawProducts;
    final selectedByOthers =
        moldEntry.cavityEntries
            .where((entry) => entry != current && entry.productId != null)
            .map((entry) => entry.productId!)
            .toSet();
    return moldEntry.rawProducts
        .where(
          (product) =>
              product.id == current.productId ||
              !selectedByOthers.contains(product.id),
        )
        .toList();
  }

  int _totalQuantity() {
    return moldEntries.fold<int>(
      0,
      (total, entry) => total + entry.totalQuantity,
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';

    return value.toString().trim();
  }

  String _getOrderNumber(Map<String, dynamic> data) {
    final candidates = [
      data['orderNumber'],

      data['orderNo'],

      data['moldingOrderNumber'],

      data['order_number'],
    ];

    for (final value in candidates) {
      final orderNumber = _stringValue(value);

      if (orderNumber.isNotEmpty) {
        return orderNumber;
      }
    }

    return '';
  }

  int _intValue(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _decimalValue(dynamic value, {double fallback = 0}) {
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return fallback % 1 == 0 ? fallback.toInt().toString() : fallback.toString();
    }
    return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
  }

  List<Map<String, dynamic>> _buildMoldingOrderItemsForMold(
    _MoldingMoldEntry moldEntry,
  ) {
    final items = <Map<String, dynamic>>[];
    final selectedMold = _moldDefinition(moldEntry.moldId);
    final rawCavities =
        selectedMold?['cavities'] is List
            ? List<dynamic>.from(selectedMold!['cavities'] as List)
            : <dynamic>[];

    for (final entry in moldEntry.cavityEntries) {
      final product = _productById(moldEntry, entry.productId);
      if (product == null) continue;
      Map<String, dynamic>? cavityData;
      for (final item in rawCavities) {
        if (item is Map && _stringValue(item['cavity']) == entry.cavity) {
          cavityData = Map<String, dynamic>.from(item);
          break;
        }
      }
      final cavityNumber = cavityData?['cavityNumber'] ?? entry.cavity;
      final piecesPerCycle = _intValue(cavityData?['piecesPerCycle']);

      for (final variant in product.variants) {
        final quantity =
            int.tryParse(
              entry.quantityControllers[variant]?.text.trim() ?? '',
            ) ??
            0;
        if (quantity <= 0) continue;
        final variantProductId = product.productIdForVariant(variant);
        if (variantProductId == null || variantProductId.isEmpty) {
          throw Exception(
            'Unable to find Firestore product ID for ${product.displayName} - $variant.',
          );
        }
        final virginRatio = double.tryParse(
              entry.virginRatioControllers[variant]?.text.trim() ?? '',
            ) ??
            10;
        final grindingRatio = double.tryParse(
              entry.grindingRatioControllers[variant]?.text.trim() ?? '',
            ) ??
            3;
        items.add({
          'moldProductId': moldEntry.moldId,
          'moldName': moldEntry.moldName,
          'moldProductCode': '',
          'cavityNumber': cavityNumber,
          'modelId': product.modelId,
          'modelName': product.modelName,
          'variantType': variant,
          'productId': variantProductId,
          'productName': product.displayName,
          'productCode': product.productCode,
          'orderedQuantity': quantity,
          'virginRatio': virginRatio,
          'grindingRatio': grindingRatio,
          'receivedQuantity': _existingItemReceivedQuantity(
            moldId: moldEntry.moldId,
            cavityNumber: cavityNumber,
            modelId: product.modelId,
            variantType: variant,
            productId: variantProductId,
          ),
          'piecesPerCycle': piecesPerCycle,
        });
      }
    }
    return items;
  }

  List<Map<String, dynamic>> _buildAllMoldingOrderItems() {
    return moldEntries
        .expand((entry) => _buildMoldingOrderItemsForMold(entry))
        .toList();
  }

  int _existingItemReceivedQuantity({
    required dynamic moldId,
    required dynamic cavityNumber,
    required String modelId,
    required String variantType,
    required String productId,
  }) {
    if (!isEditMode || _existingOrderData == null) return 0;
    final rawItems = _existingOrderData!['items'];
    if (rawItems is! List) return 0;

    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final savedMoldId = _stringValue(rawItem['moldProductId']);
      final requestedMoldId = _stringValue(moldId);
      if (requestedMoldId.isNotEmpty &&
          savedMoldId.isNotEmpty &&
          savedMoldId != requestedMoldId) {
        continue;
      }
      if (_stringValue(rawItem['cavityNumber']) == _stringValue(cavityNumber) &&
          _stringValue(rawItem['modelId']) == modelId &&
          _stringValue(rawItem['variantType']) == variantType &&
          _stringValue(rawItem['productId']) == productId) {
        return _intValue(rawItem['receivedQuantity']);
      }
    }
    return 0;
  }

  Future<void> _createOrder() async {
    if (_companyId == null || _companyId!.trim().isEmpty) {
      _showMessage('Company information is not available.');
      return;
    }
    if (isEditMode &&
        (widget.orderId == null || widget.orderId!.trim().isEmpty)) {
      _showMessage('Order ID is missing for edit mode.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (selectedSupplierId == null) {
      _showMessage('Please select a molding supplier.');
      return;
    }
    if (moldEntries.isEmpty) {
      _showMessage('Please add at least one mold.');
      return;
    }

    final selectedMoldIds = <String>{};
    for (final moldEntry in moldEntries) {
      if (moldEntry.moldId.isEmpty) {
        _showMessage('Please select a mold.');
        return;
      }
      if (!selectedMoldIds.add(moldEntry.moldId)) {
        _showMessage(
          'The same mold cannot be added more than once to an order.',
        );
        return;
      }
      if (moldEntry.cavityEntries.isEmpty) {
        _showMessage(
          'Please select at least one cavity for ${moldEntry.moldName}.',
        );
        return;
      }

      for (final entry in moldEntry.cavityEntries) {
        final product = _productById(moldEntry, entry.productId);
        if (product == null) {
          _showMessage(
            'Please select a product for ${moldEntry.moldName} - ${entry.cavity}.',
          );
          return;
        }
        for (final variant in product.variants) {
          final text = entry.quantityControllers[variant]?.text.trim() ?? '';
          if (text.isEmpty) continue;
          final quantity = int.tryParse(text);
          if (quantity == null || quantity < 0) {
            _showMessage(
              'Enter a valid quantity for $variant in ${moldEntry.moldName} - ${entry.cavity}.',
            );
            return;
          }
          final virginRatio = double.tryParse(
            entry.virginRatioControllers[variant]?.text.trim() ?? '',
          );
          final grindingRatio = double.tryParse(
            entry.grindingRatioControllers[variant]?.text.trim() ?? '',
          );
          if (virginRatio == null || virginRatio < 0) {
            _showMessage(
              'Enter a valid virgin ratio for $variant in ${moldEntry.moldName} - ${entry.cavity}.',
            );
            return;
          }
          if (grindingRatio == null || grindingRatio < 0) {
            _showMessage(
              'Enter a valid grinding ratio for $variant in ${moldEntry.moldName} - ${entry.cavity}.',
            );
            return;
          }
          if (virginRatio == 0 && grindingRatio == 0) {
            _showMessage(
              'Virgin and grinding ratio cannot both be 0 for $variant in ${moldEntry.moldName} - ${entry.cavity}.',
            );
            return;
          }
        }
      }

      // A 2-cavity mold produces both cavities in the same cycle, so quantities
      // for the same variant must remain equal within this mold only.
      if (moldEntry.cavityEntries.length > 1) {
        final firstEntry = moldEntry.cavityEntries.first;
        final firstProduct = _productById(moldEntry, firstEntry.productId);
        if (firstProduct != null) {
          for (final variant in firstProduct.variants) {
            final firstQuantity =
                int.tryParse(
                  firstEntry.quantityControllers[variant]?.text.trim() ?? '',
                ) ??
                0;
            for (int i = 1; i < moldEntry.cavityEntries.length; i++) {
              final currentEntry = moldEntry.cavityEntries[i];
              final currentQuantity =
                  int.tryParse(
                    currentEntry.quantityControllers[variant]?.text.trim() ??
                        '',
                  ) ??
                  0;
              if (currentQuantity != firstQuantity) {
                _showMessage(
                  '$variant quantity must be equal for all cavities in ${moldEntry.moldName}.\n\n'
                  '${firstEntry.cavity}: $firstQuantity\n${currentEntry.cavity}: $currentQuantity',
                );
                return;
              }
            }
          }
        }
      }

      if (moldEntry.rawProducts.length > 1) {
        final selectedProductIds = <String>{};
        for (final entry in moldEntry.cavityEntries) {
          final productId = entry.productId;
          if (productId == null) continue;
          if (!selectedProductIds.add(productId)) {
            _showMessage(
              'The same raw product cannot be assigned to multiple cavities for ${moldEntry.moldName}.',
            );
            return;
          }
        }
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessage('User session has expired. Please login again.');
      return;
    }

    setState(() => isSaving = true);
    try {
      final companyRef = _firestore.collection('companies').doc(_companyId);
      final allItems = _buildAllMoldingOrderItems();
      if (allItems.isEmpty) {
        if (mounted) setState(() => isSaving = false);
        _showMessage('Add at least one quantity greater than 0.');
        return;
      }

      final moldBlocks =
          moldEntries.map((moldEntry) {
            final moldItems = _buildMoldingOrderItemsForMold(moldEntry);
            return <String, dynamic>{
              'moldId': moldEntry.moldId,
              'moldName': moldEntry.moldName,
              'cavityCount': moldEntry.cavityEntries.length,
              'orderedPieces': moldItems.fold<int>(
                0,
                (total, item) => total + _intValue(item['orderedQuantity']),
              ),
              'items': moldItems,
            };
          }).toList();

      final orderedPieces = allItems.fold<int>(
        0,
        (total, item) => total + _intValue(item['orderedQuantity']),
      );
      final receivedPieces = allItems.fold<int>(
        0,
        (total, item) => total + _intValue(item['receivedQuantity']),
      );

      final payload = <String, dynamic>{
        'process': 'Molding',
        'supplierId': selectedSupplierId,
        'supplierName': selectedSupplier ?? '',
        'molds': moldBlocks,
        'moldIds': moldEntries.map((entry) => entry.moldId).toList(),
        'moldNames': moldEntries.map((entry) => entry.moldName).toList(),
        // Keep these fields for compatibility with existing pages/documents.
        'moldId': moldEntries.first.moldId,
        'moldName': moldEntries.first.moldName,
        'items': allItems,
        'moldCount': moldEntries.length,
        'cavityCount': moldEntries.fold<int>(
          0,
          (total, entry) => total + entry.cavityEntries.length,
        ),
        'variantCount': allItems.length,
        'orderedPieces': orderedPieces,
        'receivedPieces': receivedPieces,
      };

      if (isEditMode) {
        final orderRef = companyRef
            .collection('raw_orders')
            .doc(widget.orderId!.trim());
        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(orderRef);
          if (!snapshot.exists)
            throw Exception('Molding order no longer exists.');
          final existing = snapshot.data();
          if (existing == null)
            throw Exception('Unable to read the existing molding order.');
          final status = _stringValue(existing['status']);
          if (status.isNotEmpty && status != 'Ordered') {
            throw Exception(
              'This order can no longer be edited because its status is "$status".',
            );
          }

          transaction.update(orderRef, {
            ...payload,
            'orderNumber':
                _getOrderNumber(existing).isNotEmpty
                    ? _getOrderNumber(existing)
                    : (_editingOrderNumber ?? ''),
            'receivedPieces': receivedPieces,
            'status': status.isEmpty ? 'Ordered' : status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        if (!mounted) return;
        setState(() => isSaving = false);
        _showMessage(
          'Molding order ${_editingOrderNumber ?? 'updated'} updated successfully.',
        );
        _closePage();
        return;
      }

      final orderRef = companyRef.collection('raw_orders').doc();
      final counterRef = companyRef
          .collection('metadata')
          .doc('molding_order_counter');
      String? generatedOrderNumber;

      await _firestore.runTransaction<void>((transaction) async {
        final counterSnapshot = await transaction.get(counterRef);
        int lastNumber = 0;
        if (counterSnapshot.exists) {
          final data = counterSnapshot.data();
          if (data != null && data['lastNumber'] != null) {
            lastNumber = int.tryParse(data['lastNumber'].toString()) ?? 0;
          }
        }
        final nextNumber = lastNumber + 1;
        generatedOrderNumber = 'MOLD-${nextNumber.toString().padLeft(5, '0')}';

        transaction.set(counterRef, {
          'lastNumber': nextNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(orderRef, {
          ...payload,
          'orderNumber': generatedOrderNumber,
          'receivedPieces': 0,
          'status': 'Ordered',
          'createdByUid': currentUser.uid,
          'createdByName': currentUser.displayName ?? '',
          'orderDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Molding order $generatedOrderNumber created successfully.');
      _closePage();
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage(
        isEditMode
            ? 'Failed to update molding order: $e'
            : 'Failed to create molding order: $e',
      );
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),

          icon: const Icon(Icons.arrow_back, color: Color(0xFF343741)),
        ),

        title: Text(
          isEditMode ? 'Edit Molding Order' : 'Create Molding Order',

          style: GoogleFonts.poppins(
            fontSize: 20,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),
          ),
        ),
      ),

      body: Form(
        key: _formKey,

        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : 16,

                vertical: 24,
              ),

              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),

                  child:
                      isEditMode && !_existingOrderLoaded
                          ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),

                            child: Center(child: CircularProgressIndicator()),
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              _buildPageHeader(),

                              const SizedBox(height: 24),

                              _buildOrderDetailsSection(),

                              const SizedBox(height: 18),

                              _buildSupplierSection(),

                              const SizedBox(height: 18),

                              _buildMoldDetailsSection(),

                              const SizedBox(height: 18),

                              _buildRawProductSection(),

                              const SizedBox(height: 18),

                              _buildSummarySection(),

                              const SizedBox(height: 24),

                              _buildBottomButtons(),
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

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          isEditMode ? 'Edit Molding Order' : 'Create Molding Order',

          style: GoogleFonts.poppins(
            fontSize: 22,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),
          ),
        ),

        const SizedBox(height: 5),

        Text(
          isEditMode
              ? 'Update the molding order details and quantities.'
              : 'Create an order for sending raw material to molding.',

          style: GoogleFonts.poppins(
            fontSize: 13,

            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsSection() {
    return _buildSectionCard(
      title: 'Order Details',

      icon: Icons.receipt_long_outlined,

      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 600;

          final fields = [
            Expanded(
              child: _buildReadOnlyField(
                label: 'Order Number',

                value:
                    !isEditMode
                        ? 'Auto Generated'
                        : _isLoadingExistingOrder
                        ? 'Loading...'
                        : (_editingOrderNumber?.trim().isNotEmpty == true
                            ? _editingOrderNumber!.trim()
                            : '-'),

                icon: Icons.tag_outlined,
              ),
            ),

            const SizedBox(width: 16, height: 16),

            Expanded(
              child: _buildReadOnlyField(
                label: 'Process',

                value: 'Molding',

                icon: Icons.precision_manufacturing_outlined,
              ),
            ),
          ];

          return horizontal
              ? Row(children: fields)
              : Column(
                children: [
                  _buildReadOnlyField(
                    label: 'Order Number',

                    value:
                        isEditMode
                            ? (_editingOrderNumber ?? '-')
                            : 'Auto Generated',

                    icon: Icons.tag_outlined,
                  ),

                  const SizedBox(height: 16),

                  _buildReadOnlyField(
                    label: 'Process',

                    value: 'Molding',

                    icon: Icons.precision_manufacturing_outlined,
                  ),
                ],
              );
        },
      ),
    );
  }

  Widget _buildSupplierSection() {
    final supplierIds =
        _moldingSuppliers.map((supplier) => supplier['id'].toString()).toList();

    final supplierDisplayValues = {
      for (final supplier in _moldingSuppliers)
        supplier['id'].toString(): _supplierDisplayName(supplier),
    };

    return _buildSectionCard(
      title: 'Molding Supplier',

      icon: Icons.business_outlined,

      child: _buildDropdown(
        label: 'Supplier',

        hint:
            _moldingSuppliers.isEmpty
                ? 'No molding suppliers found'
                : 'Select molding supplier',

        value: selectedSupplierId,

        items: supplierIds,

        displayValues: supplierDisplayValues,

        icon: Icons.business_outlined,

        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Select a molding supplier';
          }

          return null;
        },

        onChanged: (value) {
          if (value == null) {
            setState(() {
              selectedSupplierId = null;

              selectedSupplier = null;
            });

            return;
          }

          final supplier = _moldingSuppliers.firstWhere(
            (item) => item['id'].toString() == value,
          );

          setState(() {
            selectedSupplierId = value;

            selectedSupplier = _supplierDisplayName(supplier);
          });
        },
      ),
    );
  }

  Widget _buildMoldDetailsSection() {
    return _buildSectionCard(
      title: 'Mold Details',
      icon: Icons.settings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add one or more molds to this molding order.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isSaving ? null : _addMoldEntry,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Add Mold',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (moldEntries.isEmpty)
            _buildInfoBox(
              icon: Icons.info_outline,
              text: 'Click "Add Mold" to add the first mold to this order.',
            )
          else
            ...moldEntries.asMap().entries.map(
              (item) => _buildMoldEntryCard(item.value, item.key),
            ),
        ],
      ),
    );
  }

  Widget _buildMoldEntryCard(_MoldingMoldEntry entry, int index) {
    final moldIds =
        molds
            .where((mold) {
              final id = mold['id'].toString();
              return id == entry.moldId ||
                  !moldEntries.any(
                    (other) => other != entry && other.moldId == id,
                  );
            })
            .map((mold) => mold['id'].toString())
            .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3F51B5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.moldName.isEmpty ? 'Mold ${index + 1}' : entry.moldName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
              if (moldEntries.length > 1)
                IconButton(
                  tooltip: 'Remove mold',
                  onPressed: isSaving ? null : () => _removeMoldEntry(entry),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDropdown(
            label: 'Mold',
            hint: isLoadingMolds ? 'Loading molds...' : 'Select mold',
            value: entry.moldId.isEmpty ? null : entry.moldId,
            items: moldIds,
            displayValues: {
              for (final mold in molds)
                mold['id'].toString(): mold['displayName'].toString(),
            },
            icon: Icons.settings_outlined,
            validator: (value) => value == null ? 'Select a mold' : null,
            onChanged: (value) => _onMoldChanged(entry, value),
          ),
          const SizedBox(height: 16),
          if (entry.moldCavities.isEmpty)
            _buildInfoBox(
              icon: Icons.warning_amber_outlined,
              text: 'No cavities were found for this mold.',
            )
          else
            _buildCavitySelector(entry),
        ],
      ),
    );
  }

  Widget _buildCavitySelector(_MoldingMoldEntry moldEntry) {
    final selected =
        moldEntry.cavityEntries.map((entry) => entry.cavity).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cavities',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              moldEntry.moldCavities.map((cavity) {
                final isSelected = selected.contains(cavity);
                return FilterChip(
                  selected: isSelected,
                  label: Text(cavity, style: GoogleFonts.poppins(fontSize: 12)),
                  onSelected: (value) {
                    final next = <String>{...selected};
                    if (value)
                      next.add(cavity);
                    else
                      next.remove(cavity);
                    final ordered =
                        moldEntry.moldCavities.where(next.contains).toList();
                    _onCavitiesChanged(moldEntry, ordered);
                  },
                );
              }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the cavities that this mold will produce.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildRawProductSection() {
    return _buildSectionCard(
      title: 'Raw Product',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (moldEntries.isEmpty)
            _buildInfoBox(
              icon: Icons.info_outline,
              text: 'Add a mold first to load its raw models.',
            )
          else
            ...moldEntries.asMap().entries.map(
              (item) => _buildRawProductMoldBlock(item.value, item.key),
            ),
        ],
      ),
    );
  }

  Widget _buildRawProductMoldBlock(_MoldingMoldEntry moldEntry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${moldEntry.moldName}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF343741),
            ),
          ),
          const SizedBox(height: 12),
          if (moldEntry.isLoadingProducts)
            _buildLoadingBox('Loading raw products...')
          else if (moldEntry.rawProducts.isEmpty)
            _buildInfoBox(
              icon: Icons.warning_amber_outlined,
              text: "No raw models are configured for this mold's cavities.",
            )
          else if (moldEntry.cavityEntries.isEmpty)
            _buildInfoBox(
              icon: Icons.info_outline,
              text: 'Select at least one cavity above to assign products.',
            )
          else
            ...moldEntry.cavityEntries.map(
              (entry) => _buildCavityProductCard(moldEntry, entry),
            ),
        ],
      ),
    );
  }

  Widget _buildCavityProductCard(
    _MoldingMoldEntry moldEntry,
    _MoldingCavityEntry entry,
  ) {
    final productItems = _availableProductsFor(moldEntry, entry);
    final productIds = productItems.map((product) => product.id).toList();
    final product = _productById(moldEntry, entry.productId);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_outlined,
                size: 18,
                color: Color(0xFF3F51B5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.cavity,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDropdown(
            label: 'Raw Product',
            hint: 'Select product for ${entry.cavity}',
            value: entry.productId,
            items: productIds,
            displayValues: {
              for (final item in productItems) item.id: item.displayName,
            },
            icon: Icons.inventory_2_outlined,
            validator: (value) => value == null ? 'Select a raw product' : null,
            onChanged: (value) => _onProductChanged(moldEntry, entry, value),
          ),
          if (product != null) ...[
            const SizedBox(height: 18),
            _buildVariantQuantityTable(entry, product),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantQuantityTable(
    _MoldingCavityEntry entry,
    _MoldingProduct product,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Variant Quantities & Material Ratio',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF343741),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMobile
                  ? 'Enter quantity and Virgin : Grinding ratio for each variant.'
                  : 'Enter quantity and the Virgin : Grinding ratio for each variant.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 10),
            if (isMobile)
              _buildMobileVariantCards(entry, product)
            else
              _buildDesktopVariantTable(entry, product),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Cavity total: ${entry.totalQuantity}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileVariantCards(
    _MoldingCavityEntry entry,
    _MoldingProduct product,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.swipe_vertical_rounded,
                size: 18,
                color: Color(0xFF3F51B5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Swipe down to enter each variant',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...product.variants.asMap().entries.map((item) {
          final index = item.key;
          final variant = item.value;
          final quantityController = entry.quantityControllers[variant]!;
          final virginRatioController =
              entry.virginRatioControllers[variant]!;
          final grindingRatioController =
              entry.grindingRatioControllers[variant]!;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E4F2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                        color: const Color(0xFFE8EAF6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F51B5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        variant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF343741),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');
                    if (quantity == null || quantity < 0) {
                      return 'Enter quantity';
                    }
                    return null;
                  },
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: _inputDecoration(
                    label: 'Quantity',
                    hint: '0',
                    icon: Icons.numbers_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: virginRatioController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final ratio = double.tryParse(value?.trim() ?? '');
                          if (ratio == null || ratio < 0) {
                            return 'Enter ratio';
                          }
                          return null;
                        },
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: _inputDecoration(
                          label: 'Virgin',
                          hint: '10',
                          icon: Icons.science_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: grindingRatioController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final ratio = double.tryParse(value?.trim() ?? '');
                          if (ratio == null || ratio < 0) {
                            return 'Enter ratio';
                          }
                          return null;
                        },
                        style: GoogleFonts.poppins(fontSize: 13),
                        decoration: _inputDecoration(
                          label: 'Grinding',
                          hint: '3',
                          icon: Icons.recycling_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Ratio: ${virginRatioController.text.trim().isEmpty ? '10' : virginRatioController.text.trim()} : ${grindingRatioController.text.trim().isEmpty ? '3' : grindingRatioController.text.trim()}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDesktopVariantTable(
    _MoldingCavityEntry entry,
    _MoldingProduct product,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F6FA),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        'Variant',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text(
                        'Quantity',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: Text(
                        'Virgin Ratio',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: Text(
                        'Grinding Ratio',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...product.variants.map((variant) {
                final quantityController =
                    entry.quantityControllers[variant]!;
                final virginRatioController =
                    entry.virginRatioControllers[variant]!;
                final grindingRatioController =
                    entry.grindingRatioControllers[variant]!;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            variant,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF343741),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final quantity =
                                int.tryParse(value?.trim() ?? '');
                            if (quantity == null || quantity < 0) {
                              return 'Enter quantity';
                            }
                            return null;
                          },
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: _inputDecoration(
                            label: 'Quantity',
                            hint: '0',
                            icon: Icons.numbers_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: TextFormField(
                          controller: virginRatioController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final ratio =
                                double.tryParse(value?.trim() ?? '');
                            if (ratio == null || ratio < 0) {
                              return 'Enter ratio';
                            }
                            return null;
                          },
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: _inputDecoration(
                            label: 'Virgin',
                            hint: '10',
                            icon: Icons.science_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: TextFormField(
                          controller: grindingRatioController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final ratio =
                                double.tryParse(value?.trim() ?? '');
                            if (ratio == null || ratio < 0) {
                              return 'Enter ratio';
                            }
                            return null;
                          },
                          style: GoogleFonts.poppins(fontSize: 13),
                          decoration: _inputDecoration(
                            label: 'Grinding',
                            hint: '3',
                            icon: Icons.recycling_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return _buildSectionCard(
      title: 'Order Summary',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Molds', moldEntries.length.toString()),
          _summaryRow('Molding Supplier', selectedSupplier ?? '-'),
          const Divider(height: 20),
          if (moldEntries.isEmpty)
            _summaryRow('Assignments', '-')
          else
            ...moldEntries.asMap().entries.map((item) {
              final index = item.key;
              final moldEntry = item.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${moldEntry.moldName}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343741),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _summaryRow(
                      'Selected Cavities',
                      moldEntry.cavityEntries.isEmpty
                          ? '-'
                          : moldEntry.cavityEntries
                              .map((entry) => entry.cavity)
                              .join(', '),
                    ),
                    for (final entry in moldEntry.cavityEntries) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.cavity,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      _summaryRow(
                        'Product',
                        _productById(moldEntry, entry.productId)?.displayName ??
                            '-',
                      ),
                      for (final variant
                          in _productById(
                                moldEntry,
                                entry.productId,
                              )?.variants ??
                              const <String>[])
                        if (_intValue(
                              entry.quantityControllers[variant]?.text,
                            ) >
                            0) ...[
                          _summaryRow(
                            variant,
                            entry.quantityControllers[variant]!.text.trim(),
                          ),
                          _summaryRow(
                            '$variant Ratio',
                            '${entry.virginRatioControllers[variant]?.text.trim() ?? '10'} : ${entry.grindingRatioControllers[variant]?.text.trim() ?? '3'}',
                          ),
                        ],
                    ],
                    _summaryRow(
                      'Mold Total',
                      moldEntry.totalQuantity.toString(),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 20),
          _summaryRow('Total Molding Quantity', _totalQuantity().toString()),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Expanded(
            child: Text(
              label,

              style: GoogleFonts.poppins(
                fontSize: 13,

                color: const Color(0xFF6B7280),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,

              textAlign: TextAlign.right,

              style: GoogleFonts.poppins(
                fontSize: 13,

                fontWeight: FontWeight.w600,

                color: const Color(0xFF343741),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,

      children: [
        OutlinedButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),

          style: OutlinedButton.styleFrom(
            minimumSize: const Size(120, 46),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),

          child: Text(
            'Cancel',

            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(width: 12),

        ElevatedButton.icon(
          onPressed: isSaving ? null : _createOrder,

          icon:
              isSaving
                  ? const SizedBox(
                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Colors.white,
                    ),
                  )
                  : Icon(
                    isEditMode ? Icons.save_outlined : Icons.add,
                    size: 19,
                  ),

          label: Text(
            isSaving
                ? (isEditMode ? 'Saving...' : 'Creating...')
                : (isEditMode ? 'Save Changes' : 'Create Order'),

            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),

          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3F51B5),

            foregroundColor: Colors.white,

            minimumSize: const Size(160, 46),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),

            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,

    required IconData icon,

    required Widget child,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: const Color(0xFFE5E7EB)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 34,

                height: 34,

                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FF),

                  borderRadius: BorderRadius.circular(8),
                ),

                child: Icon(icon, size: 18, color: const Color(0xFF3F51B5)),
              ),

              const SizedBox(width: 10),

              Text(
                title,

                style: GoogleFonts.poppins(
                  fontSize: 16,

                  fontWeight: FontWeight.w600,

                  color: const Color(0xFF343741),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,

    required String hint,

    required String? value,

    required List<String> items,

    required IconData icon,

    required ValueChanged<String?> onChanged,

    Map<String, String>? displayValues,

    String? Function(String?)? validator,
  }) {
    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,

      isExpanded: true,

      items:
          items.map((item) {
            return DropdownMenuItem<String>(
              value: item,

              child: Text(
                displayValues?[item] ?? item,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: GoogleFonts.poppins(fontSize: 13),
              ),
            );
          }).toList(),

      onChanged: onChanged,

      validator: validator,

      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  Widget _buildReadOnlyField({
    required String label,

    required String value,

    required IconData icon,
  }) {
    return TextFormField(
      initialValue: value,

      readOnly: true,

      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF343741)),

      decoration: _inputDecoration(label: label, hint: value, icon: icon),
    );
  }

  Widget _buildInfoBox({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),

        borderRadius: BorderRadius.circular(9),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              text,

              style: GoogleFonts.poppins(
                fontSize: 12,

                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBox(String text) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),

        borderRadius: BorderRadius.circular(9),
      ),

      child: Row(
        children: [
          const SizedBox(
            width: 17,

            height: 17,

            child: CircularProgressIndicator(strokeWidth: 2),
          ),

          const SizedBox(width: 10),

          Text(
            text,

            style: GoogleFonts.poppins(
              fontSize: 12,

              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,

    required String hint,

    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      labelStyle: GoogleFonts.poppins(
        fontSize: 12,

        color: const Color(0xFF6B7280),
      ),

      hintStyle: GoogleFonts.poppins(
        fontSize: 13,

        color: const Color(0xFF9CA3AF),
      ),

      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF6B7280)),

      filled: true,

      fillColor: const Color(0xFFF9FAFB),

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !messenger.mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RawProductAccumulator {
  final String id;

  final String modelId;

  final String modelName;

  final String productCode;

  final Set<String> variants = {};

  final Map<String, String> variantProductIds = {};

  _RawProductAccumulator({
    required this.id,

    required this.modelId,

    required this.modelName,

    required this.productCode,
  });
}
