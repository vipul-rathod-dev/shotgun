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

  State<CreateMoldingOrderPage> createState() =>

      _CreateMoldingOrderPageState();

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



  _MoldingCavityEntry(

    this.cavity, {

    this.linkedModelId,

  });



  void dispose() {

    for (final controller in quantityControllers.values) {

      controller.dispose();

    }

    quantityControllers.clear();

  }



  int get totalQuantity {

    return quantityControllers.values.fold<int>(

      0,

      (total, controller) => total + (int.tryParse(controller.text.trim()) ?? 0),

    );

  }

}



class _CreateMoldingOrderPageState extends State<CreateMoldingOrderPage> {

  final _formKey = GlobalKey<FormState>();



  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isEditMode => widget.isEditMode;



  String? _companyId;



  String? selectedMoldId;

  String? selectedMoldName;

  List<Map<String, dynamic>> _moldingSuppliers = [];



  String? selectedSupplierId;

  String? selectedSupplier;



  List<Map<String, dynamic>> molds = [];

  List<String> moldCavities = [];

  Map<String, String?> moldCavityModelIds = {};



  List<_MoldingProduct> rawProducts = [];

  List<_MoldingCavityEntry> cavityEntries = [];



  bool isLoadingMolds = true;

  bool isLoadingProducts = false;

  bool isSaving = false;

  // Edit-mode state.
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

    FocusManager.instance.primaryFocus?.unfocus();



    for (final entry in cavityEntries) {

      entry.dispose();

    }



    super.dispose();

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

      final snapshot = await _firestore

          .collection('companies')

          .doc(companyId)

          .collection('products')

          .where('category', isEqualTo: 'Other')

          .where('type', isEqualTo: 'Mold')

          .get();



      final loaded = snapshot.docs.map((doc) {

        final data = doc.data();

        return <String, dynamic>{

          'id': doc.id,

          'name': _stringValue(

            data['modelName'] ??

                data['name'] ??

                data['productName'] ??

                data['moldName'] ??

                doc.id,

          ),

          'cavities': _extractCavityDefinitions(data),

        };

      }).toList();



      loaded.sort(

        (a, b) => (a['name'] as String).compareTo(b['name'] as String),

      );



      if (!mounted) return;



      setState(() {

        molds = loaded;

        isLoadingMolds = false;

      });

      if (isEditMode && widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
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
        _showMessage('Only Ordered molding orders can be edited. Current status: $status.');
        Navigator.of(context).pop();
        return;
      }

      final supplierId = _stringValue(data['supplierId']);
      final supplierName = _stringValue(data['supplierName']);
      final moldId = _stringValue(data['moldId']);

      final mold = molds.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id']?.toString() == moldId,
        orElse: () => null,
      );

      if (mold == null) {
        if (!mounted) return;
        _showMessage('The mold used by this order is no longer available in the product list.');
        Navigator.of(context).pop();
        return;
      }

      final rawCavities = (mold['cavities'] as List?) ?? const [];
      final cavityModelIds = <String, String?>{};
      final cavityNames = <String>[];

      for (final item in rawCavities) {
        final cavity = item is Map ? _stringValue(item['cavity']) : item.toString().trim();
        if (cavity.isEmpty) continue;
        cavityNames.add(cavity);
        cavityModelIds[cavity] = item is Map
            ? (_stringValue(item['modelId']).isEmpty ? null : _stringValue(item['modelId']))
            : null;
      }

      await _loadRawProductsForMold(moldId, cavityModelIds);

      final rawItems = data['items'] is List
          ? List<Map<String, dynamic>>.from(
              (data['items'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
            )
          : <Map<String, dynamic>>[];

      final selectedCavityNames = <String>[];
      final itemsByCavity = <String, List<Map<String, dynamic>>>{};

      for (final item in rawItems) {
        final cavityName = _resolveSavedCavityName(item['cavityNumber'], cavityNames);
        if (cavityName == null) continue;
        itemsByCavity.putIfAbsent(cavityName, () => []).add(item);
        if (!selectedCavityNames.contains(cavityName)) selectedCavityNames.add(cavityName);
      }

      final savedMoldCount = _intValue(data['moldCount']);
      if (savedMoldCount > selectedCavityNames.length) {
        for (final cavity in cavityNames) {
          if (selectedCavityNames.length >= savedMoldCount) break;
          if (!selectedCavityNames.contains(cavity)) selectedCavityNames.add(cavity);
        }
      }

      selectedCavityNames.sort((a, b) => cavityNames.indexOf(a).compareTo(cavityNames.indexOf(b)));

      final entries = <_MoldingCavityEntry>[];

      for (final cavity in selectedCavityNames) {
        final savedItems = itemsByCavity[cavity] ?? const <Map<String, dynamic>>[];
        final linkedModelId = cavityModelIds[cavity];
        final savedModelId = savedItems
            .map((item) => _stringValue(item['modelId']))
            .firstWhere((value) => value.isNotEmpty, orElse: () => linkedModelId ?? '');

        final entry = _MoldingCavityEntry(cavity, linkedModelId: linkedModelId);
        final product = _productById(savedModelId);

        if (product != null) {
          entry.productId = product.id;
          for (final variant in product.variants) {
            entry.quantityControllers[variant] = TextEditingController(text: '0');
          }
          for (final item in savedItems) {
            final variant = _stringValue(item['variantType']);
            final controller = entry.quantityControllers[variant];
            if (controller != null) {
              controller.text = _intValue(item['orderedQuantity']).toString();
            }
          }
        } else if (savedModelId.isNotEmpty) {
          entry.productId = savedModelId;
        }
        entries.add(entry);
      }

      final loadedOrderNumber = _getOrderNumber(data);

      if (!mounted) {
        for (final entry in entries) {
          entry.dispose();
        }
        return;
      }

      setState(() {
        _existingOrderData = Map<String, dynamic>.from(data);

        _editingOrderNumber = loadedOrderNumber;

        _editingOrderStatus = status.isEmpty ? 'Ordered' : status;

        selectedSupplierId = supplierId.isEmpty ? null : supplierId;
        selectedSupplier = supplierName.isEmpty ? null : supplierName;

        selectedMoldId = moldId.isEmpty ? null : moldId;
        selectedMoldName = _stringValue(mold['name']);

        moldCavities = cavityNames;
        moldCavityModelIds = cavityModelIds;
        cavityEntries = entries;

        _isLoadingExistingOrder = false;
        _existingOrderLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to load molding order for editing: $e');
      Navigator.of(context).pop();
    }
  }

  String? _resolveSavedCavityName(dynamic savedCavityNumber, List<String> cavityNames) {
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
        final cavityNumber = match == null ? null : int.tryParse(match.group(0)!);
        if (cavityNumber == savedNumber || (cavityNumber == null && index + 1 == savedNumber)) return cavity;
      }
    }
    return null;
  }

  Future<void> _loadMoldingSuppliers() async {

    if (_companyId == null || _companyId!.isEmpty) return;



    try {

      final snapshot = await _firestore

          .collection('companies')

          .doc(_companyId)

          .collection('suppliers')

          .where('role', isEqualTo: 'Molding')

          .get();



      final suppliers = snapshot.docs.map((doc) {

        final data = doc.data();



        return {

          'id': doc.id,

          ...data,

        };

      }).toList();



      suppliers.sort(

        (a, b) => _supplierDisplayName(a)

            .toLowerCase()

            .compareTo(_supplierDisplayName(b).toLowerCase()),

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

          final rawCavity = item['cavityNumber'] ??

              item['name'] ??

              item['cavityName'] ??

              item['cavity'];



          final cavity = rawCavity is num

              ? 'Cavity ${rawCavity.toInt()}'

              : _stringValue(

                  rawCavity ?? 'Cavity ${index + 1}',

                );



          final modelId = _stringValue(

            item['modelId'] ??

                item['rawModelId'] ??

                item['productModelId'],

          );



          values.add({

            'cavity': cavity.isEmpty ? 'Cavity ${index + 1}' : cavity,

            'modelId': modelId.isEmpty ? null : modelId,

          });

        } else {

          final cavity = item?.toString().trim() ?? '';

          if (cavity.isNotEmpty) {

            values.add({

              'cavity': cavity,

              'modelId': null,

            });

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

        (index) => {

          'cavity': 'Cavity ${index + 1}',

          'modelId': null,

        },

      );

    }



    return const [];

  }



  Future<void> _loadRawProductsForMold(

    String moldId,

    Map<String, String?> cavityModelIds,

  ) async {

    if (_companyId == null) return;



    setState(() {

      isLoadingProducts = true;

      rawProducts = [];

    });



    try {

      final modelIds = cavityModelIds.values

          .whereType<String>()

          .where((id) => id.trim().isNotEmpty)

          .toSet();



      if (modelIds.isEmpty) {

        if (!mounted) return;

        setState(() {

          isLoadingProducts = false;

        });

        return;

      }



      // Raw products are linked to a Mold through the Mold's cavity*

      // \`modelId\`. Raw product documents themselves do not contain moldId.*

      final snapshot = await _firestore

          .collection('companies')

          .doc(_companyId)

          .collection('products')

          .where('category', isEqualTo: 'Raw')

          .get();



      final grouped = <String, _RawProductAccumulator>{};



      for (final doc in snapshot.docs) {

        final data = doc.data();



        final modelId = _stringValue(

          data['modelId'] ?? data['productModelId'],

        );



        if (!modelIds.contains(modelId)) continue;



        final modelName = _stringValue(

          data['modelName'] ??

              data['name'] ??

              data['productName'] ??

              modelId,

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



      final products = grouped.values

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



      if (!mounted) return;



      setState(() {

        rawProducts = products;

        isLoadingProducts = false;

      });

    } catch (e) {

      if (!mounted) return;



      setState(() {

        isLoadingProducts = false;

      });



      _showMessage('Unable to load raw products: $e');

    }

  }



  void _onMoldChanged(String? moldId) {

    for (final entry in cavityEntries) {

      entry.dispose();

    }



    final mold = molds.cast<Map<String, dynamic>?>().firstWhere(

          (item) => item?['id'] == moldId,

          orElse: () => null,

        );



    final rawCavities = (mold?['cavities'] as List?) ?? const [];



    final cavityModelIds = <String, String?>{};

    final cavityNames = <String>[];



    for (final item in rawCavities) {

      final cavity = item is Map

          ? _stringValue(item['cavity'])

          : item.toString().trim();



      if (cavity.isEmpty) continue;



      cavityNames.add(cavity);

      cavityModelIds[cavity] = item is Map

          ? _stringValue(item['modelId']).isEmpty

              ? null

              : _stringValue(item['modelId'])

          : null;

    }



    setState(() {

      selectedMoldId = moldId;

      selectedMoldName = mold?['name'] as String?;

      moldCavities = cavityNames;

      moldCavityModelIds = cavityModelIds;

      cavityEntries = [];

      rawProducts = [];

    });



    if (moldId != null) {

      _loadRawProductsForMold(moldId, cavityModelIds);

    }

  }



  void _onCavitiesChanged(List<String> cavities) {

    for (final entry in cavityEntries) {

      entry.dispose();

    }



    setState(() {

      cavityEntries = cavities

          .map(

            (cavity) => _MoldingCavityEntry(

              cavity,

              linkedModelId: moldCavityModelIds[cavity],

            ),

          )

          .toList();

    });

  }



  void _onProductChanged(_MoldingCavityEntry entry, String? productId) {

    for (final controller in entry.quantityControllers.values) {

      controller.dispose();

    }

    entry.quantityControllers.clear();



    final product = _productById(productId);



    if (product != null) {

      for (final variant in product.variants) {

        entry.quantityControllers[variant] = TextEditingController(text: '0');

      }

    }



    setState(() {

      entry.productId = productId;

    });

  }



  _MoldingProduct? _productById(String? productId) {

    if (productId == null) return null;



    for (final product in rawProducts) {

      if (product.id == productId) return product;

    }



    return null;

  }



  List<_MoldingProduct> _availableProductsFor(

    _MoldingCavityEntry current,

  ) {

    if (rawProducts.length <= 1) return rawProducts;



    final selectedByOthers = cavityEntries

        .where((entry) => entry != current && entry.productId != null)

        .map((entry) => entry.productId!)

        .toSet();



    return rawProducts

        .where(

          (product) =>

              product.id == current.productId ||

              !selectedByOthers.contains(product.id),

        )

        .toList();

  }



  int _totalQuantity() {

    return cavityEntries.fold<int>(

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



  List<Map<String, dynamic>> _buildMoldingOrderItems() {

    final items = <Map<String, dynamic>>[];



    Map<String, dynamic>? selectedMold;



    for (final mold in molds) {

      if (mold['id']?.toString() == selectedMoldId) {

        selectedMold = mold;

        break;

      }

    }



    final rawCavities = selectedMold?['cavities'] is List

        ? List<dynamic>.from(selectedMold!['cavities'] as List)

        : <dynamic>[];



    for (final entry in cavityEntries) {

      final product = _productById(entry.productId);



      if (product == null) {

        continue;

      }



      Map<String, dynamic>? cavityData;



      for (final item in rawCavities) {

        if (item is Map) {

          final cavityName = item['cavity']?.toString() ?? '';



          if (cavityName == entry.cavity) {

            cavityData = Map<String, dynamic>.from(item);

            break;

          }

        }

      }



      final cavityNumber =

          cavityData?['cavityNumber'] ?? entry.cavity;



      final piecesPerCycle =

          int.tryParse(

            cavityData?['piecesPerCycle']?.toString() ?? '',

          ) ??

          0;



      for (final variant in product.variants) {

        final quantity =

            int.tryParse(

              entry.quantityControllers[variant]?.text.trim() ?? '',

            ) ??

            0;



        // Only positive quantities become order items.*

        if (quantity <= 0) {

          continue;

        }



        final variantProductId = product.productIdForVariant(variant);



        if (variantProductId == null ||

            variantProductId.isEmpty) {

          throw Exception(

            'Unable to find Firestore product ID for '

            '${product.displayName} - $variant.',

          );

        }



        items.add({

          'moldProductId': selectedMoldId,

          'moldName': selectedMoldName ?? '',

          'moldProductCode': '',

          'cavityNumber': cavityNumber,

          'modelId': product.modelId,

          'modelName': product.modelName,

          'variantType': variant,



          // Current _MoldingProduct.id represents the model/raw-product*

          // grouping ID.*

          'productId': variantProductId,



          'productName': product.displayName,

          'productCode': product.productCode,



          'orderedQuantity': quantity,

          'receivedQuantity': _existingItemReceivedQuantity(
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



  int _existingItemReceivedQuantity({
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
      if (_stringValue(rawItem['cavityNumber']) == _stringValue(cavityNumber) &&
          _stringValue(rawItem['modelId']) == modelId &&
          _stringValue(rawItem['variantType']) == variantType &&
          _stringValue(rawItem['productId']) == productId) {
        return _intValue(rawItem['receivedQuantity']);
      }
    }
    return 0;
  }

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(

        backgroundColor: Colors.white,

        elevation: 0,

        leading: IconButton(

          onPressed: () => Navigator.of(context).pop(),

          icon: const Icon(

            Icons.arrow_back,

            color: Color(0xFF343741),

          ),

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

                  child: isEditMode && !_existingOrderLoaded
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
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

                value: !isEditMode
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

              : Column(children: [

                  _buildReadOnlyField(

                    label: 'Order Number',

                    value: isEditMode ? (_editingOrderNumber ?? '-') : 'Auto Generated',

                    icon: Icons.tag_outlined,

                  ),

                  const SizedBox(height: 16),

                  _buildReadOnlyField(

                    label: 'Process',

                    value: 'Molding',

                    icon: Icons.precision_manufacturing_outlined,

                  ),

                ]);

        },

      ),

    );

  }



  Widget _buildSupplierSection() {

    final supplierIds = _moldingSuppliers

        .map((supplier) => supplier['id'].toString())

        .toList();



    final supplierDisplayValues = {

      for (final supplier in _moldingSuppliers)

        supplier['id'].toString(): _supplierDisplayName(supplier),

    };



    return _buildSectionCard(

      title: 'Molding Supplier',

      icon: Icons.business_outlined,

      child: _buildDropdown(

        label: 'Supplier',

        hint: _moldingSuppliers.isEmpty

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

    final moldNames = molds

        .map((mold) => mold['id'].toString())

        .toList();



    return _buildSectionCard(

      title: 'Mold Details',

      icon: Icons.settings_outlined,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _buildDropdown(

            label: 'Mold',

            hint: isLoadingMolds ? 'Loading molds...' : 'Select mold',

            value: selectedMoldId,

            items: moldNames,

            displayValues: {

              for (final mold in molds)

                mold['id'].toString(): mold['name'].toString(),

            },

            icon: Icons.settings_outlined,

            validator: (value) =>

                value == null ? 'Select a mold' : null,

            onChanged: _onMoldChanged,

          ),

          const SizedBox(height: 18),

          if (selectedMoldId == null)

            _buildInfoBox(

              icon: Icons.info_outline,

              text: 'Select a mold first. Its cavities and linked raw models will then be loaded.',

            )

          else if (moldCavities.isEmpty)

            _buildInfoBox(

              icon: Icons.warning_amber_outlined,

              text: 'No cavities were found for this mold.',

            )

          else

            _buildCavitySelector(),

        ],

      ),

    );

  }



  Widget _buildCavitySelector() {

    final selected = cavityEntries.map((entry) => entry.cavity).toSet();



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

          children: moldCavities.map((cavity) {

            final isSelected = selected.contains(cavity);



            return FilterChip(

              selected: isSelected,

              label: Text(

                cavity,

                style: GoogleFonts.poppins(fontSize: 12),

              ),

              onSelected: (value) {

                final next = <String>{...selected};



                if (value) {

                  next.add(cavity);

                } else {

                  next.remove(cavity);

                }



                final ordered = moldCavities

                    .where(next.contains)

                    .toList();



                _onCavitiesChanged(ordered);

              },

            );

          }).toList(),

        ),

        const SizedBox(height: 8),

        Text(

          'Select the cavities that this molding order will produce.',

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

          if (selectedMoldId == null)

            _buildInfoBox(

              icon: Icons.info_outline,

              text: 'Select a mold to load the raw models configured in its cavities.',

            )

          else if (isLoadingProducts)

            _buildLoadingBox('Loading raw products...')

          else if (rawProducts.isEmpty)

            _buildInfoBox(

              icon: Icons.warning_amber_outlined,

              text: "No raw models are configured for the selected mold's cavities.",

            )

          else if (cavityEntries.isEmpty)

            _buildInfoBox(

              icon: Icons.info_outline,

              text: 'Select at least one cavity above to assign products.',

            )

          else

            ...cavityEntries.map(_buildCavityProductCard),

        ],

      ),

    );

  }



  Widget _buildCavityProductCard(_MoldingCavityEntry entry) {

    final productItems = _availableProductsFor(entry);

    final productIds = productItems.map((product) => product.id).toList();



    final product = _productById(entry.productId);



    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: const Color(0xFFFAFBFF),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(

          color: const Color(0xFFE0E4F2),

        ),

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

              for (final item in productItems)

                item.id: item.displayName,

            },

            icon: Icons.inventory_2_outlined,

            validator: (value) =>

                value == null ? 'Select a raw product' : null,

            onChanged: (value) => _onProductChanged(entry, value),

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

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          'Variant Quantities',

          style: GoogleFonts.poppins(

            fontSize: 13,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),

          ),

        ),

        const SizedBox(height: 10),

        Container(

          decoration: BoxDecoration(

            border: Border.all(color: const Color(0xFFE0E0E0)),

            borderRadius: BorderRadius.circular(9),

          ),

          child: Column(

            children: [

              Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 12,

                  vertical: 10,

                ),

                decoration: const BoxDecoration(

                  color: Color(0xFFF5F6FA),

                  borderRadius: BorderRadius.vertical(

                    top: Radius.circular(9),

                  ),

                ),

                child: Row(

                  children: [

                    Expanded(

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

                  ],

                ),

              ),

              ...product.variants.map((variant) {

                final controller =

                    entry.quantityControllers[variant]!;



                return Padding(

                  padding: const EdgeInsets.symmetric(

                    horizontal: 12,

                    vertical: 8,

                  ),

                  child: Row(

                    children: [

                      Expanded(

                        child: Text(

                          variant,

                          style: GoogleFonts.poppins(

                            fontSize: 13,

                            color: const Color(0xFF343741),

                          ),

                        ),

                      ),

                      SizedBox(

                        width: 180,

                        child: TextFormField(

                          controller: controller,

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

                    ],

                  ),

                );

              }),

            ],

          ),

        ),

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

  }



  Widget _buildSummarySection() {

    return _buildSectionCard(

      title: 'Order Summary',

      icon: Icons.summarize_outlined,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _summaryRow('Mold', selectedMoldName ?? '-'),

          _summaryRow(

            'Selected Cavities',

            cavityEntries.isEmpty

                ? '-'

                : cavityEntries.map((e) => e.cavity).join(', '),

          ),

          const Divider(height: 20),

          if (cavityEntries.isEmpty)

            _summaryRow('Assignments', '-')

          else

            ...cavityEntries.map((entry) {

              final product = _productById(entry.productId);



              return Padding(

                padding: const EdgeInsets.only(bottom: 14),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      entry.cavity,

                      style: GoogleFonts.poppins(

                        fontSize: 13,

                        fontWeight: FontWeight.w600,

                        color: const Color(0xFF343741),

                      ),

                    ),

                    const SizedBox(height: 4),

                    _summaryRow(

                      'Product',

                      product?.displayName ?? '-',

                    ),

                    for (final variant in product?.variants ?? const <String>[])

                      if ((int.tryParse(

                                entry.quantityControllers[variant]

                                        ?.text

                                        .trim() ??

                                    '',

                              ) ??

                              0) >

                          0)

                        _summaryRow(

                          variant,

                          entry.quantityControllers[variant]!.text.trim(),

                        ),

                  ],

                ),

              );

            }),

          const Divider(height: 20),

          _summaryRow(

            'Total Molding Quantity',

            _totalQuantity().toString(),

          ),

          _summaryRow(

            'Molding Supplier',

            selectedSupplier ?? '-',

          ),

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

          icon: isSaving

              ? const SizedBox(

                  width: 18,

                  height: 18,

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                    color: Colors.white,

                  ),

                )

              : Icon(isEditMode ? Icons.save_outlined : Icons.add, size: 19),

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

                child: Icon(

                  icon,

                  size: 18,

                  color: const Color(0xFF3F51B5),

                ),

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

      items: items.map((item) {

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

      decoration: _inputDecoration(

        label: label,

        hint: hint,

        icon: icon,

      ),

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

      style: GoogleFonts.poppins(

        fontSize: 13,

        color: const Color(0xFF343741),

      ),

      decoration: _inputDecoration(

        label: label,

        hint: value,

        icon: icon,

      ),

    );

  }



  Widget _buildInfoBox({

    required IconData icon,

    required String text,

  }) {

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

          Icon(

            icon,

            size: 18,

            color: const Color(0xFF6B7280),

          ),

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

      prefixIcon: Icon(

        icon,

        size: 19,

        color: const Color(0xFF6B7280),

      ),

      filled: true,

      fillColor: const Color(0xFFF9FAFB),

      contentPadding: const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 14,

      ),

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(

          color: Color(0xFFE0E0E0),

        ),

      ),

      enabledBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(

          color: Color(0xFFE0E0E0),

        ),

      ),

      focusedBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(9),

        borderSide: const BorderSide(

          color: Color(0xFF3F51B5),

          width: 1.5,

        ),

      ),

    );

  }



  Future<void> _createOrder() async {
    if (_companyId == null || _companyId!.trim().isEmpty) {
      _showMessage('Company information is not available.');
      return;
    }

    if (isEditMode && (widget.orderId == null || widget.orderId!.trim().isEmpty)) {
      _showMessage('Order ID is missing for edit mode.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (selectedMoldId == null) { _showMessage('Please select a mold.'); return; }
    if (selectedSupplierId == null) { _showMessage('Please select a molding supplier.'); return; }
    if (cavityEntries.isEmpty) { _showMessage('Please select at least one cavity.'); return; }

    for (final entry in cavityEntries) {
      final product = _productById(entry.productId);
      if (product == null) {
        _showMessage('Please select a product for ${entry.cavity}.');
        return;
      }
      for (final variant in product.variants) {
        final text = entry.quantityControllers[variant]?.text.trim() ?? '';
        if (text.isEmpty) continue;
        final quantity = int.tryParse(text);
        if (quantity == null || quantity < 0) {
          _showMessage('Enter a valid quantity for $variant in ${entry.cavity}.');
          return;
        }
      }
    }

    if (cavityEntries.length > 1) {
      final firstEntry = cavityEntries.first;
      final firstProduct = _productById(firstEntry.productId);
      if (firstProduct != null) {
        for (final variant in firstProduct.variants) {
          final firstQuantity = int.tryParse(firstEntry.quantityControllers[variant]?.text.trim() ?? '') ?? 0;
          for (int i = 1; i < cavityEntries.length; i++) {
            final currentEntry = cavityEntries[i];
            final currentQuantity = int.tryParse(currentEntry.quantityControllers[variant]?.text.trim() ?? '') ?? 0;
            if (currentQuantity != firstQuantity) {
              _showMessage('$variant quantity must be equal for all cavities.\n\n${firstEntry.cavity}: $firstQuantity\n${currentEntry.cavity}: $currentQuantity');
              return;
            }
          }
        }
      }
    }

    if (rawProducts.length > 1) {
      final selectedProductIds = <String>{};
      for (final entry in cavityEntries) {
        final productId = entry.productId;
        if (productId == null) continue;
        if (!selectedProductIds.add(productId)) {
          _showMessage('The same raw product cannot be assigned to multiple cavities for this mold.');
          return;
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
      final items = _buildMoldingOrderItems();
      if (items.isEmpty) {
        if (mounted) setState(() => isSaving = false);
        _showMessage('Add at least one quantity greater than 0.');
        return;
      }

      final orderedPieces = items.fold<int>(0, (total, item) => total + _intValue(item['orderedQuantity']));

      if (isEditMode) {
        final orderRef = companyRef.collection('raw_orders').doc(widget.orderId!.trim());
        await _firestore.runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(orderRef);
          if (!snapshot.exists) throw Exception('Molding order no longer exists.');
          final existing = snapshot.data();
          if (existing == null) throw Exception('Unable to read the existing molding order.');
          final status = _stringValue(existing['status']);
          if (status.isNotEmpty && status != 'Ordered') {
            throw Exception('This order can no longer be edited because its status is "$status".');
          }

          transaction.update(orderRef, {
            'orderNumber': _getOrderNumber(existing).isNotEmpty
              ? _getOrderNumber(existing)
              : (_editingOrderNumber ?? ''),
            'process': 'Molding',
            'supplierId': selectedSupplierId,
            'supplierName': selectedSupplier ?? '',
            'moldId': selectedMoldId,
            'moldName': selectedMoldName ?? '',
            'items': items,
            'moldCount': cavityEntries.length,
            'variantCount': items.length,
            'orderedPieces': orderedPieces,
            'receivedPieces': _intValue(existing['receivedPieces']),
            'status': status.isEmpty ? 'Ordered' : status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        if (!mounted) return;
        setState(() => isSaving = false);
        _showMessage('Molding order ${_editingOrderNumber ?? 'updated'} updated successfully.');
        Navigator.of(context).pop(true);
        return;
      }

      final orderRef = companyRef.collection('raw_orders').doc();
      final counterRef = companyRef.collection('metadata').doc('molding_order_counter');
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
          'orderNumber': generatedOrderNumber,
          'process': 'Molding',
          'supplierId': selectedSupplierId,
          'supplierName': selectedSupplier ?? '',
          'moldId': selectedMoldId,
          'moldName': selectedMoldName ?? '',
          'items': items,
          'moldCount': cavityEntries.length,
          'variantCount': items.length,
          'orderedPieces': orderedPieces,
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
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage(isEditMode ? 'Failed to update molding order: $e' : 'Failed to create molding order: $e');
    }
  }

  void _showMessage(String message) {

    if (!mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

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
