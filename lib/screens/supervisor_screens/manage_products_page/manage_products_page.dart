import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/paginated_product_list.dart';

// Product management implementation for the model/cavity structure:

//

// Raw model

//   Model A

//     ├─ Black

//     ├─ Clear

//     └─ PC

//

// Mold

//   Cavity 1 -> Model A -> Black/Clear/PC

//   Cavity 2 -> Model B -> Black/Clear/PC

class ManageProductPage extends StatefulWidget {
  const ManageProductPage({super.key});

  @override
  State<ManageProductPage> createState() => _ManageProductPageState();
}

class _ManageProductPageState extends State<ManageProductPage>
    with SingleTickerProviderStateMixin {
  final _modelNameController = TextEditingController();

  final _nameController = TextEditingController();

  final _priceController = TextEditingController();

  final _codeController = TextEditingController();

  final _minimumStockController = TextEditingController(text: '0');

  final _openingStockController = TextEditingController(text: '0');

  final _cavityCountController = TextEditingController(text: '1');

  final _blackOpeningController = TextEditingController(text: '0');

  final _clearOpeningController = TextEditingController(text: '0');

  final _pcOpeningController = TextEditingController(text: '0');

  final _blackLeftOpeningController = TextEditingController(text: '0');

  final _blackRightOpeningController = TextEditingController(text: '0');

  final _clearLeftOpeningController = TextEditingController(text: '0');

  final _clearRightOpeningController = TextEditingController(text: '0');

  final _pcLeftOpeningController = TextEditingController(text: '0');

  final _pcRightOpeningController = TextEditingController(text: '0');

  late final TabController _tabController;

  String selectedCategory = 'Raw';

  String? selectedFinishedType;

  String? selectedOtherType;

  String selectedRawComponentType = 'Focus';

  final rawComponentTypes = const ['Focus', 'Temple'];

  final finishedTypes = const ['Gents', 'Ladies', 'Baby'];

  final otherTypes = const ['Raw Material', 'Mold'];

  List<Map<String, dynamic>> _rawModels = [];

  List<String?> _cavityModelIds = [null];

  List<TextEditingController> _piecesPerCycleControllers = [
    TextEditingController(text: '1'),
  ];

  bool _expanded = true;

  bool _saving = false;

  int _reloadKey = 0;

  String? _companyId;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products');

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      final category = switch (_tabController.index) {
        0 => 'Raw',

        1 => 'Finished',

        _ => 'Other',
      };

      setState(() {
        selectedCategory = category;

        _resetForm(true);

        _clearCategorySelections();
      });

      if (category == 'Other') _loadRawModels();
    });

    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString('cachedCompanyId');

    if (!mounted) return;

    setState(() => _companyId = id);

    if (id != null && id.isNotEmpty) {
      _resetForm(true);

      await _loadRawModels();
    }
  }

  void _clearCategorySelections() {
    selectedFinishedType = null;

    selectedOtherType = null;

    selectedRawComponentType = 'Focus';

    _cavityCountController.text = '1';

    _cavityModelIds = [null];

    _replacePieceControllers(1);
  }

  void _replacePieceControllers(int count, {List<String>? values}) {
    for (final controller in _piecesPerCycleControllers) {
      controller.dispose();
    }

    _piecesPerCycleControllers = List.generate(
      count,

      (index) => TextEditingController(
        text: values != null && index < values.length ? values[index] : '1',
      ),
    );
  }

  Future<void> _loadRawModels() async {
    if (_companyId == null) return;

    try {
      final snapshot =
          await _productsRef.where('category', isEqualTo: 'Raw').get();

      final grouped = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final type = data['type']?.toString() ?? '';

        if (!const ['Black', 'Clear', 'PC'].contains(type)) continue;

        final modelId = data['modelId']?.toString() ?? '';

        final modelName = data['modelName']?.toString() ?? '';

        if (modelId.isEmpty || modelName.isEmpty) continue;

        // *Older Raw products did not have componentType.*

        // *Treat them as Focus for backward compatibility.*

        final componentType =
            data['componentType']?.toString() == 'Temple' ? 'Temple' : 'Focus';

        final model = grouped.putIfAbsent(
          modelId,

          () => {
            'modelId': modelId,

            'modelName': modelName,

            'productCode': data['productCode']?.toString() ?? '',

            'componentType': componentType,

            'variants': <String, dynamic>{},
          },
        );

        final variants = model['variants'] as Map<String, dynamic>;

        final product = {
          'productId': doc.id,

          'productName':
              data['displayName']?.toString() ?? data['name']?.toString() ?? '',

          'productCode': data['productCode']?.toString() ?? '',

          'type': type,

          'side': data['side']?.toString(),
        };

        if (componentType == 'Temple') {
          final side = data['side']?.toString();

          if (side != 'Left' && side != 'Right') continue;

          final sideVariants =
              variants.putIfAbsent(type, () => <String, dynamic>{})
                  as Map<String, dynamic>;

          sideVariants[side!] = product;
        } else {
          variants[type] = product;
        }
      }

      final models =
          grouped.values.where((model) {
            final componentType = model['componentType']?.toString() ?? 'Focus';

            final variants = model['variants'] as Map<String, dynamic>;

            if (!const ['Black', 'Clear', 'PC'].every(variants.containsKey)) {
              return false;
            }

            if (componentType == 'Temple') {
              return const ['Black', 'Clear', 'PC'].every((type) {
                final sides = variants[type];

                return sides is Map &&
                    sides.containsKey('Left') &&
                    sides.containsKey('Right');
              });
            }

            return true;
          }).toList();

      models.sort(
        (a, b) => a['modelName'].toString().toLowerCase().compareTo(
          b['modelName'].toString().toLowerCase(),
        ),
      );

      if (mounted) setState(() => _rawModels = models);
    } catch (e) {
      debugPrint('Failed to load Raw models: $e');
    }
  }

  void _setCavityCount(int value) {
    final count = value.clamp(1, 100);

    _cavityCountController.text = count.toString();

    if (_cavityModelIds.length < count) {
      _cavityModelIds.addAll(
        List<String?>.filled(count - _cavityModelIds.length, null),
      );
    } else if (_cavityModelIds.length > count) {
      _cavityModelIds = _cavityModelIds.sublist(0, count);
    }

    final existingValues =
        _piecesPerCycleControllers.map((e) => e.text).toList();

    _replacePieceControllers(count, values: existingValues);
  }

  Map<String, dynamic>? _findRawModel(String? modelId) {
    if (modelId == null || modelId.isEmpty) return null;

    for (final model in _rawModels) {
      if (model['modelId']?.toString() == modelId) return model;
    }

    return null;
  }

  bool _modelHasAllVariants(Map<String, dynamic> model) {
    final variants = model['variants'] as Map<String, dynamic>? ?? {};

    final componentType = model['componentType']?.toString() ?? 'Focus';

    if (!const ['Black', 'Clear', 'PC'].every(variants.containsKey)) {
      return false;
    }

    if (componentType == 'Temple') {
      return const ['Black', 'Clear', 'PC'].every((type) {
        final sides = variants[type];

        return sides is Map &&
            sides.containsKey('Left') &&
            sides.containsKey('Right');
      });
    }

    return true;
  }

  Future<void> _addProduct() async {
    if (_companyId == null || _saving) return;

    if (selectedCategory == 'Raw') {
      await _createRawModel();

      return;
    }

    final baseName = _nameController.text.trim();

    final price = double.tryParse(_priceController.text.trim());

    final minimumStock = int.tryParse(_minimumStockController.text.trim());

    final openingStock = int.tryParse(_openingStockController.text.trim());

    final productCode = _codeController.text.trim();

    if (baseName.isEmpty)
      return _message('Product name is required', error: true);

    if (price == null || price < 0)
      return _message('Enter a valid price', error: true);

    if (minimumStock == null || minimumStock < 0)
      return _message('Enter a valid minimum stock', error: true);

    if (openingStock == null || openingStock < 0)
      return _message('Enter a valid opening stock', error: true);

    if (selectedCategory == 'Finished' &&
        (selectedFinishedType == null || productCode.isEmpty)) {
      return _message(
        'Select Finished gender and enter product code',
        error: true,
      );
    }

    if (selectedCategory == 'Other' && selectedOtherType == null) {
      return _message('Select an Other product type', error: true);
    }

    if (selectedCategory == 'Other' && productCode.isEmpty) {
      return _message('Product code is required', error: true);
    }

    if (selectedCategory == 'Other' && selectedOtherType == 'Mold') {
      await _createMold(
        baseName: baseName,

        price: price,

        minimumStock: minimumStock,

        productCode: productCode,
      );

      return;
    }

    setState(() => _saving = true);

    try {
      final duplicate =
          await _productsRef
              .where('name', isEqualTo: baseName.toLowerCase())
              .where('category', isEqualTo: selectedCategory)
              .where('type', isEqualTo: selectedOtherType)
              .limit(1)
              .get();

      if (duplicate.docs.isNotEmpty) {
        _message('This product already exists.', error: true);

        return;
      }

      final data = <String, dynamic>{
        'name': baseName.toLowerCase(),

        'displayName': baseName,

        'price': price,

        'category': selectedCategory,

        'stock': openingStock,

        'minimumStock': minimumStock,

        'timestamp': FieldValue.serverTimestamp(),
      };

      if (selectedCategory == 'Finished') {
        data['productCode'] = productCode;

        data['modelGender'] = selectedFinishedType;
      } else {
        data['type'] = selectedOtherType;

        data['productCode'] = productCode;
      }

      await _productsRef.add(data);

      _resetForm(true);

      setState(() => _reloadKey++);

      _message('Product added successfully.');
    } catch (e) {
      _message('Failed to add product: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRawModel() async {
    final modelName = _modelNameController.text.trim();

    final productCode = _codeController.text.trim();

    final minimumStock = int.tryParse(_minimumStockController.text.trim());

    if (modelName.isEmpty) {
      return _message('Model name is required', error: true);
    }

    if (productCode.isEmpty) {
      return _message('Product code is required', error: true);
    }

    if (minimumStock == null || minimumStock < 0) {
      return _message('Enter a valid minimum stock', error: true);
    }

    final componentType = selectedRawComponentType;

    final openings = <String, int>{};

    if (componentType == 'Focus') {
      final black = int.tryParse(_blackOpeningController.text.trim());

      final clear = int.tryParse(_clearOpeningController.text.trim());

      final pc = int.tryParse(_pcOpeningController.text.trim());

      if (black == null ||
          black < 0 ||
          clear == null ||
          clear < 0 ||
          pc == null ||
          pc < 0) {
        return _message(
          'Enter valid opening stock for all three Focus variants',

          error: true,
        );
      }

      openings.addAll({'Black': black, 'Clear': clear, 'PC': pc});
    } else {
      final values = {
        'Black_Left': int.tryParse(_blackLeftOpeningController.text.trim()),

        'Black_Right': int.tryParse(_blackRightOpeningController.text.trim()),

        'Clear_Left': int.tryParse(_clearLeftOpeningController.text.trim()),

        'Clear_Right': int.tryParse(_clearRightOpeningController.text.trim()),

        'PC_Left': int.tryParse(_pcLeftOpeningController.text.trim()),

        'PC_Right': int.tryParse(_pcRightOpeningController.text.trim()),
      };

      if (values.values.any((value) => value == null || value < 0)) {
        return _message(
          'Enter valid opening stock for all Temple Left/Right variants',

          error: true,
        );
      }

      for (final entry in values.entries) {
        openings[entry.key] = entry.value!;
      }
    }

    setState(() => _saving = true);

    try {
      final duplicate =
          await _productsRef
              .where('category', isEqualTo: 'Raw')
              .where('modelName', isEqualTo: modelName)
              .get();

      final sameComponentExists = duplicate.docs.any(
        (doc) =>
            (doc.data()['componentType']?.toString() ?? 'Focus') ==
            componentType,
      );

      if (sameComponentExists) {
        _message('This $componentType Raw model already exists.', error: true);

        return;
      }

      final modelId = _productsRef.doc().id;

      final batch = FirebaseFirestore.instance.batch();

      for (final type in const ['Black', 'Clear', 'PC']) {
        if (componentType == 'Focus') {
          final displayName = '$modelName - $type';

          final ref = _productsRef.doc();

          batch.set(ref, {
            'name': displayName.toLowerCase(),

            'displayName': displayName,

            'category': 'Raw',

            'type': type,

            'componentType': 'Focus',

            'side': null,

            'modelId': modelId,

            'modelName': modelName,

            'productCode': productCode,

            'stock': openings[type],

            'openingStock': openings[type],

            'minimumStock': minimumStock,

            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          for (final side in const ['Left', 'Right']) {
            final displayName = '$modelName - $type - $side';

            final ref = _productsRef.doc();

            final opening = openings['${type}_$side']!;

            batch.set(ref, {
              'name': displayName.toLowerCase(),

              'displayName': displayName,

              'category': 'Raw',

              'type': type,

              'componentType': 'Temple',

              'side': side,

              'modelId': modelId,

              'modelName': modelName,

              'productCode': productCode,

              'stock': opening,

              'openingStock': opening,

              'minimumStock': minimumStock,

              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();

      await _loadRawModels();

      _resetForm(true);

      setState(() => _reloadKey++);

      _message(
        componentType == 'Focus'
            ? 'Focus Raw model created with Black, Clear and PC variants.'
            : 'Temple Raw model created with Left and Right Black, Clear and PC variants.',
      );
    } catch (e) {
      _message('Failed to create Raw model: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _copyRawVariant(dynamic rawVariant) {
    final variant =
        rawVariant is Map
            ? Map<String, dynamic>.from(rawVariant)
            : <String, dynamic>{};

    return {
      'productId': variant['productId']?.toString() ?? '',

      'productName': variant['productName']?.toString() ?? '',

      'productCode': variant['productCode']?.toString() ?? '',

      'side': variant['side']?.toString(),
    };
  }

  Future<void> _createMold({
    required String baseName,

    required double price,

    required int minimumStock,

    required String productCode,
  }) async {
    final cavityCount = int.tryParse(_cavityCountController.text.trim());

    if (cavityCount == null || cavityCount < 1) {
      return _message('Enter a valid cavity count', error: true);
    }

    if (_cavityModelIds.length != cavityCount) {
      return _message('Cavity configuration is incomplete', error: true);
    }

    final cavities = <Map<String, dynamic>>[];

    for (var i = 0; i < cavityCount; i++) {
      final modelId = _cavityModelIds[i];

      final model = _findRawModel(modelId);

      if (modelId == null || model == null) {
        return _message('Select a Raw model for Cavity ${i + 1}', error: true);
      }

      if (!_modelHasAllVariants(model)) {
        return _message(
          '${model['modelName']} must have Black, Clear and PC variants.',

          error: true,
        );
      }

      final piecesPerCycle = int.tryParse(
        _piecesPerCycleControllers[i].text.trim(),
      );

      if (piecesPerCycle == null || piecesPerCycle <= 0) {
        return _message(
          'Enter valid Pieces per Cycle for Cavity ${i + 1}',
          error: true,
        );
      }

      final rawVariants = model['variants'] as Map<String, dynamic>;

      final componentType = model['componentType']?.toString() ?? 'Focus';

      final variants = <String, dynamic>{};

      for (final type in const ['Black', 'Clear', 'PC']) {
        if (componentType == 'Temple') {
          final sideVariants = Map<String, dynamic>.from(
            rawVariants[type] as Map,
          );

          variants[type] = {
            'Left': _copyRawVariant(sideVariants['Left']),

            'Right': _copyRawVariant(sideVariants['Right']),
          };
        } else {
          variants[type] = _copyRawVariant(rawVariants[type]);
        }
      }

      cavities.add({
        'cavityNumber': i + 1,

        'modelId': modelId,

        'modelName': model['modelName'],

        'componentType': componentType,

        'variants': variants,

        'piecesPerCycle': piecesPerCycle,
      });
    }
    setState(() => _saving = true);

    try {
      final duplicate =
          await _productsRef
              .where('name', isEqualTo: baseName.toLowerCase())
              .where('category', isEqualTo: 'Other')
              .where('type', isEqualTo: 'Mold')
              .limit(1)
              .get();

      if (duplicate.docs.isNotEmpty) {
        _message('This mold already exists.', error: true);

        return;
      }

      await _productsRef.add({
        'name': baseName.toLowerCase(),

        'displayName': baseName,

        'price': price,

        'category': 'Other',

        'type': 'Mold',

        'productCode': productCode,

        'stock': 0,

        'minimumStock': minimumStock,

        'cavityCount': cavityCount,

        'cavities': cavities,

        'timestamp': FieldValue.serverTimestamp(),
      });

      _resetForm(true);

      setState(() => _reloadKey++);

      _message('Mold created successfully.');
    } catch (e) {
      _message('Failed to create mold: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm(bool collapse) {
    _modelNameController.clear();

    _nameController.clear();

    _priceController.clear();

    _codeController.clear();

    _minimumStockController.text = '0';

    _openingStockController.text = '0';

    _blackOpeningController.text = '0';

    _clearOpeningController.text = '0';

    _pcOpeningController.text = '0';

    _blackLeftOpeningController.text = '0';

    _blackRightOpeningController.text = '0';

    _clearLeftOpeningController.text = '0';

    _clearRightOpeningController.text = '0';

    _pcLeftOpeningController.text = '0';

    _pcRightOpeningController.text = '0';

    selectedRawComponentType = 'Focus';

    _cavityCountController.text = '1';

    _cavityModelIds = [null];

    _replacePieceControllers(1);

    selectedFinishedType = null;

    selectedOtherType = null;

    selectedRawComponentType = 'Focus';

    if (collapse) {
      _expanded = false;
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();

    for (final controller in _piecesPerCycleControllers) {
      controller.dispose();
    }

    _modelNameController.dispose();

    _nameController.dispose();

    _priceController.dispose();

    _codeController.dispose();

    _minimumStockController.dispose();

    _openingStockController.dispose();

    _cavityCountController.dispose();

    _blackOpeningController.dispose();

    _clearOpeningController.dispose();

    _pcOpeningController.dispose();

    _blackLeftOpeningController.dispose();

    _blackRightOpeningController.dispose();

    _clearLeftOpeningController.dispose();

    _clearRightOpeningController.dispose();

    _pcLeftOpeningController.dispose();

    _pcRightOpeningController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),

        bottom: TabBar(
          controller: _tabController,

          isScrollable: true,

          tabs: const [
            Tab(text: 'Raw'),

            Tab(text: 'Finished'),

            Tab(text: 'Other'),
          ],
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),

            child: Card(
              clipBehavior: Clip.antiAlias,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },

                    child: Padding(
                      padding: const EdgeInsets.all(14),

                      child: Row(
                        children: [
                          Icon(
                            Icons.add_box_outlined,

                            color: theme.colorScheme.primary,
                          ),

                          const SizedBox(width: 10),

                          const Expanded(
                            child: Text(
                              'Add Product / Raw Model / Mold',

                              style: TextStyle(
                                fontWeight: FontWeight.w700,

                                fontSize: 16,
                              ),
                            ),
                          ),

                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_expanded)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),

                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),

                        child: _buildForm(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,

              children: [
                PaginatedProductList(
                  key: ValueKey('Raw-$_reloadKey'),
                  category: 'Raw',
                ),

                PaginatedProductList(
                  key: ValueKey('Finished-$_reloadKey'),
                  category: 'Finished',
                ),

                PaginatedProductList(
                  key: ValueKey('Other-$_reloadKey'),
                  category: 'Other',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final fields = <Widget>[];

    if (selectedCategory == 'Raw') {
      fields.addAll([
        TextField(
          controller: _modelNameController,

          decoration: const InputDecoration(
            labelText: 'Model Name',

            hintText: 'Example: Model A',

            prefixIcon: Icon(Icons.style_outlined),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _codeController,

          textCapitalization: TextCapitalization.characters,

          decoration: const InputDecoration(
            labelText: 'Product Code',

            prefixIcon: Icon(Icons.qr_code_2_outlined),
          ),
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: selectedRawComponentType,

          decoration: const InputDecoration(
            labelText: 'Raw Product Type',

            prefixIcon: Icon(Icons.category_outlined),
          ),

          items:
              rawComponentTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),

          onChanged: (v) {
            if (v == null) return;

            setState(() => selectedRawComponentType = v);
          },
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _minimumStockController,

          keyboardType: TextInputType.number,

          decoration: const InputDecoration(
            labelText: 'Minimum Stock',

            prefixIcon: Icon(Icons.warning_amber_outlined),
          ),
        ),

        const SizedBox(height: 14),

        _buildSectionLabel(
          selectedRawComponentType == 'Temple'
              ? 'Opening Stock by Variant / Side'
              : 'Opening Stock by Variant',
        ),

        const SizedBox(height: 8),
      ]);

      if (selectedRawComponentType == 'Focus') {
        fields.addAll([
          _stockField('Black', _blackOpeningController),

          const SizedBox(height: 8),

          _stockField('Clear', _clearOpeningController),

          const SizedBox(height: 8),

          _stockField('PC', _pcOpeningController),
        ]);
      } else {
        fields.addAll([
          _stockField('Black - Left', _blackLeftOpeningController),

          const SizedBox(height: 8),

          _stockField('Black - Right', _blackRightOpeningController),

          const SizedBox(height: 8),

          _stockField('Clear - Left', _clearLeftOpeningController),

          const SizedBox(height: 8),

          _stockField('Clear - Right', _clearRightOpeningController),

          const SizedBox(height: 8),

          _stockField('PC - Left', _pcLeftOpeningController),

          const SizedBox(height: 8),

          _stockField('PC - Right', _pcRightOpeningController),
        ]);
      }
    } else {
      fields.addAll([
        TextField(
          controller: _nameController,

          decoration: const InputDecoration(
            labelText: 'Product / Mold Name',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),

        const SizedBox(height: 12),

        if (selectedCategory == 'Finished' || selectedCategory == 'Other') ...[
          TextField(
            controller: _codeController,

            textCapitalization: TextCapitalization.characters,

            decoration: const InputDecoration(
              labelText: 'Product Code',
              prefixIcon: Icon(Icons.qr_code_2_outlined),
            ),
          ),

          const SizedBox(height: 12),
        ],

        TextField(
          controller: _priceController,

          keyboardType: const TextInputType.numberWithOptions(decimal: true),

          decoration: const InputDecoration(
            labelText: 'Price',
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _minimumStockController,

          keyboardType: TextInputType.number,

          decoration: const InputDecoration(
            labelText: 'Minimum Stock',
            prefixIcon: Icon(Icons.warning_amber_outlined),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _openingStockController,

          keyboardType: TextInputType.number,

          decoration: const InputDecoration(
            labelText: 'Opening Stock',
            prefixIcon: Icon(Icons.inventory_outlined),
          ),
        ),
      ]);
    }

    fields.addAll([
      const SizedBox(height: 12),

      DropdownButtonFormField<String>(
        value: selectedCategory,

        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.category_outlined),
        ),

        items:
            const [
              'Raw',
              'Finished',
              'Other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),

        onChanged: (v) {
          if (v == null) return;

          setState(() {
            selectedCategory = v;

            _clearCategorySelections();
          });

          if (v == 'Other') _loadRawModels();
        },
      ),
    ]);

    if (selectedCategory == 'Finished') {
      fields.addAll([
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: selectedFinishedType,

          decoration: const InputDecoration(
            labelText: 'Gender',
            prefixIcon: Icon(Icons.people_outline),
          ),

          items:
              finishedTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),

          onChanged: (v) => setState(() => selectedFinishedType = v),
        ),
      ]);
    }

    if (selectedCategory == 'Other') {
      fields.addAll([
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: selectedOtherType,

          decoration: const InputDecoration(
            labelText: 'Product Type',
            prefixIcon: Icon(Icons.category_outlined),
          ),

          items:
              otherTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),

          onChanged: (v) {
            setState(() {
              selectedOtherType = v;

              if (v == 'Mold')
                _setCavityCount(int.tryParse(_cavityCountController.text) ?? 1);
            });

            if (v == 'Mold') _loadRawModels();
          },
        ),
      ]);

      if (selectedOtherType == 'Mold') {
        fields.addAll([
          const SizedBox(height: 12),

          TextField(
            controller: _cavityCountController,

            keyboardType: TextInputType.number,

            decoration: const InputDecoration(
              labelText: 'Cavity Count',
              prefixIcon: Icon(Icons.grid_view_outlined),
            ),

            onChanged: (v) {
              final count = int.tryParse(v);

              if (count != null &&
                  count >= 1 &&
                  count <= 100 &&
                  count != _cavityModelIds.length) {
                setState(() => _setCavityCount(count));
              }
            },
          ),

          const SizedBox(height: 12),

          if (_rawModels.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,

              child: Text(
                'No complete Raw models found. Create a model with Black, Clear and PC first.',
              ),
            )
          else
            ...List.generate(_cavityModelIds.length, _buildCavityEditor),
        ]);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),

      child: Column(
        children: [
          const Divider(),

          const SizedBox(height: 8),

          ...fields,

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,

            height: 46,

            child: FilledButton.icon(
              onPressed: _saving ? null : _addProduct,

              icon:
                  _saving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.add),

              label: Text(
                _saving
                    ? 'Saving...'
                    : selectedCategory == 'Raw'
                    ? 'Create Raw Model'
                    : selectedOtherType == 'Mold'
                    ? 'Create Mold'
                    : 'Add Product',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCavityEditor(int index) {
    final model = _findRawModel(_cavityModelIds[index]);

    final variants = model?['variants'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Cavity ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _cavityModelIds[index],

              isExpanded: true,

              decoration: const InputDecoration(
                labelText: 'Model',
                prefixIcon: Icon(Icons.style_outlined),
              ),

              items:
                  _rawModels.map((model) {
                    return DropdownMenuItem<String>(
                      value: model['modelId'].toString(),

                      child: Text(
                        '${model['modelName']} • ${model['productCode']}',
                      ),
                    );
                  }).toList(),

              onChanged:
                  (value) => setState(() => _cavityModelIds[index] = value),
            ),

            if (model != null) ...[
              const SizedBox(height: 10),

              if ((model['componentType']?.toString() ?? 'Focus') ==
                  'Temple') ...[
                _variantRow(
                  'Black - Left',
                  (variants['Black'] as Map?)?['Left'],
                ),

                _variantRow(
                  'Black - Right',
                  (variants['Black'] as Map?)?['Right'],
                ),

                _variantRow(
                  'Clear - Left',
                  (variants['Clear'] as Map?)?['Left'],
                ),

                _variantRow(
                  'Clear - Right',
                  (variants['Clear'] as Map?)?['Right'],
                ),

                _variantRow('PC - Left', (variants['PC'] as Map?)?['Left']),

                _variantRow('PC - Right', (variants['PC'] as Map?)?['Right']),
              ] else ...[
                _variantRow('Black', variants['Black']),

                _variantRow('Clear', variants['Clear']),

                _variantRow('PC', variants['PC']),
              ],
            ],

            const SizedBox(height: 10),

            TextField(
              controller: _piecesPerCycleControllers[index],

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Pieces Per Cycle',
                prefixIcon: Icon(Icons.repeat_one_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantRow(String type, dynamic rawVariant) {
    final variant =
        rawVariant is Map
            ? Map<String, dynamic>.from(rawVariant)
            : <String, dynamic>{};

    final name = variant['productName']?.toString() ?? 'Missing';

    final code = variant['productCode']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),

      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              type,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Expanded(
            child: Text(
              code.isEmpty ? name : '$name • $code',
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Icon(Icons.lock_outline, size: 16),
        ],
      ),
    );
  }

  Widget _stockField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,

      keyboardType: TextInputType.number,

      decoration: InputDecoration(
        labelText: '$label Opening Stock',
        prefixIcon: const Icon(Icons.inventory_outlined),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(
    alignment: Alignment.centerLeft,

    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
