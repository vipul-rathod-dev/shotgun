import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/paginated_product_list.dart';

/// Product management implementation for the model/cavity structure:
///
/// Raw model
///   Model A
///     ├─ Black
///     ├─ Clear
///     └─ PC
///
/// Mold
///   Cavity 1 -> Model A -> Black/Clear/PC
///   Cavity 2 -> Model B -> Black/Clear/PC
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

  late final TabController _tabController;

  String selectedCategory = 'Raw';
  String? selectedFinishedType;
  String? selectedOtherType;

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
      await _loadRawModels();
    }
  }

  void _clearCategorySelections() {
    selectedFinishedType = null;
    selectedOtherType = null;
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
      final snapshot = await _productsRef
          .where('category', isEqualTo: 'Raw')
          .get();

      final grouped = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        if (!const ['Black', 'Clear', 'PC'].contains(type)) continue;

        final modelId = data['modelId']?.toString() ?? '';
        final modelName = data['modelName']?.toString() ?? '';
        if (modelId.isEmpty || modelName.isEmpty) continue;

        final model = grouped.putIfAbsent(
          modelId,
          () => {
            'modelId': modelId,
            'modelName': modelName,
            'productCode': data['productCode']?.toString() ?? '',
            'variants': <String, Map<String, dynamic>>{},
          },
        );

        final variants = model['variants'] as Map<String, Map<String, dynamic>>;
        variants[type] = {
          'productId': doc.id,
          'productName': data['displayName']?.toString() ?? data['name']?.toString() ?? '',
          'productCode': data['productCode']?.toString() ?? '',
          'type': type,
        };
      }

      final models = grouped.values.where((model) {
        final variants = model['variants'] as Map<String, Map<String, dynamic>>;
        return const ['Black', 'Clear', 'PC'].every(variants.containsKey);
      }).toList();

      models.sort((a, b) => a['modelName']
          .toString()
          .toLowerCase()
          .compareTo(b['modelName'].toString().toLowerCase()));

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

    final existingValues = _piecesPerCycleControllers.map((e) => e.text).toList();
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
    return const ['Black', 'Clear', 'PC'].every(variants.containsKey);
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

    if (baseName.isEmpty) return _message('Product name is required', error: true);
    if (price == null || price < 0) return _message('Enter a valid price', error: true);
    if (minimumStock == null || minimumStock < 0) return _message('Enter a valid minimum stock', error: true);
    if (openingStock == null || openingStock < 0) return _message('Enter a valid opening stock', error: true);

    if (selectedCategory == 'Finished' &&
        (selectedFinishedType == null || productCode.isEmpty)) {
      return _message('Select Finished gender and enter product code', error: true);
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
      final duplicate = await _productsRef
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
      _resetForm();
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
    final price = double.tryParse(_priceController.text.trim());
    final minimumStock = int.tryParse(_minimumStockController.text.trim());
    final blackOpening = int.tryParse(_blackOpeningController.text.trim());
    final clearOpening = int.tryParse(_clearOpeningController.text.trim());
    final pcOpening = int.tryParse(_pcOpeningController.text.trim());

    if (modelName.isEmpty) return _message('Model name is required', error: true);
    if (productCode.isEmpty) return _message('Product code is required', error: true);
    if (price == null || price < 0) return _message('Enter a valid price', error: true);
    if (minimumStock == null || minimumStock < 0) return _message('Enter a valid minimum stock', error: true);
    if (blackOpening == null || blackOpening < 0 ||
        clearOpening == null || clearOpening < 0 ||
        pcOpening == null || pcOpening < 0) {
      return _message('Enter valid opening stock for all three variants', error: true);
    }

    setState(() => _saving = true);
    try {
      final duplicate = await _productsRef
          .where('category', isEqualTo: 'Raw')
          .where('modelName', isEqualTo: modelName)
          .limit(1)
          .get();

      if (duplicate.docs.isNotEmpty) {
        _message('This Raw model already exists.', error: true);
        return;
      }

      final modelId = _productsRef.doc().id;
      final batch = FirebaseFirestore.instance.batch();
      final openings = {
        'Black': blackOpening,
        'Clear': clearOpening,
        'PC': pcOpening,
      };

      for (final type in const ['Black', 'Clear', 'PC']) {
        final displayName = '$modelName - $type';
        final ref = _productsRef.doc();
        batch.set(ref, {
          'name': displayName.toLowerCase(),
          'displayName': displayName,
          'price': price,
          'category': 'Raw',
          'type': type,
          'modelId': modelId,
          'modelName': modelName,
          'productCode': productCode,
          'stock': openings[type],
          'openingStock': openings[type],
          'minimumStock': minimumStock,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _loadRawModels();
      _resetForm();
      setState(() => _reloadKey++);
      _message('Raw model created with Black, Clear and PC variants.');
    } catch (e) {
      _message('Failed to create Raw model: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final usedModelIds = <String>{};

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
      if (!usedModelIds.add(modelId)) {
        return _message(
          '${model['modelName']} is already assigned to another cavity.',
          error: true,
        );
      }

      final piecesPerCycle = int.tryParse(_piecesPerCycleControllers[i].text.trim());
      if (piecesPerCycle == null || piecesPerCycle <= 0) {
        return _message('Enter valid Pieces per Cycle for Cavity ${i + 1}', error: true);
      }

      final rawVariants = model['variants'] as Map<String, dynamic>;
      final variants = <String, dynamic>{};
      for (final type in const ['Black', 'Clear', 'PC']) {
        final variant = Map<String, dynamic>.from(rawVariants[type] as Map);
        variants[type] = {
          'productId': variant['productId']?.toString() ?? '',
          'productName': variant['productName']?.toString() ?? '',
          'productCode': variant['productCode']?.toString() ?? '',
        };
      }

      cavities.add({
        'cavityNumber': i + 1,
        'modelId': modelId,
        'modelName': model['modelName'],
        'variants': variants,
        'piecesPerCycle': piecesPerCycle,
      });
    }

    setState(() => _saving = true);
    try {
      final duplicate = await _productsRef
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

      _resetForm();
      setState(() => _reloadKey++);
      _message('Mold created successfully.');
    } catch (e) {
      _message('Failed to create mold: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    _modelNameController.clear();
    _nameController.clear();
    _priceController.clear();
    _codeController.clear();
    _minimumStockController.text = '0';
    _openingStockController.text = '0';
    _blackOpeningController.text = '0';
    _clearOpeningController.text = '0';
    _pcOpeningController.text = '0';
    _cavityCountController.text = '1';
    _cavityModelIds = [null];
    _replacePieceControllers(1);
    selectedFinishedType = null;
    selectedOtherType = null;
    _expanded = false;
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
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.add_box_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Add Product / Raw Model / Mold',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded) _buildForm(),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PaginatedProductList(key: ValueKey('Raw-$_reloadKey'), category: 'Raw'),
                PaginatedProductList(key: ValueKey('Finished-$_reloadKey'), category: 'Finished'),
                PaginatedProductList(key: ValueKey('Other-$_reloadKey'), category: 'Other'),
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
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(Icons.currency_rupee)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minimumStockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minimum Stock', prefixIcon: Icon(Icons.warning_amber_outlined)),
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('Opening Stock by Variant'),
        const SizedBox(height: 8),
        _stockField('Black', _blackOpeningController),
        const SizedBox(height: 8),
        _stockField('Clear', _clearOpeningController),
        const SizedBox(height: 8),
        _stockField('PC', _pcOpeningController),
      ]);
    } else {
      fields.addAll([
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Product / Mold Name', prefixIcon: Icon(Icons.inventory_2_outlined)),
        ),
        const SizedBox(height: 12),
        if (selectedCategory == 'Finished' || selectedCategory == 'Other') ...[
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Product Code', prefixIcon: Icon(Icons.qr_code_2_outlined)),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(Icons.currency_rupee)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minimumStockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minimum Stock', prefixIcon: Icon(Icons.warning_amber_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _openingStockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Opening Stock', prefixIcon: Icon(Icons.inventory_outlined)),
        ),
      ]);
    }

    fields.addAll([
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: selectedCategory,
        decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
        items: const ['Raw', 'Finished', 'Other']
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
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
          decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.people_outline)),
          items: finishedTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => selectedFinishedType = v),
        ),
      ]);
    }

    if (selectedCategory == 'Other') {
      fields.addAll([
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedOtherType,
          decoration: const InputDecoration(labelText: 'Product Type', prefixIcon: Icon(Icons.category_outlined)),
          items: otherTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) {
            setState(() {
              selectedOtherType = v;
              if (v == 'Mold') _setCavityCount(int.tryParse(_cavityCountController.text) ?? 1);
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
            decoration: const InputDecoration(labelText: 'Cavity Count', prefixIcon: Icon(Icons.grid_view_outlined)),
            onChanged: (v) {
              final count = int.tryParse(v);
              if (count != null && count >= 1 && count <= 100 && count != _cavityModelIds.length) {
                setState(() => _setCavityCount(count));
              }
            },
          ),
          const SizedBox(height: 12),
          if (_rawModels.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No complete Raw models found. Create a model with Black, Clear and PC first.'),
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
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Saving...' : selectedCategory == 'Raw' ? 'Create Raw Model' : selectedOtherType == 'Mold' ? 'Create Mold' : 'Add Product'),
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
            Text('Cavity ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _cavityModelIds[index],
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(Icons.style_outlined)),
              items: _rawModels.map((model) {
                return DropdownMenuItem<String>(
                  value: model['modelId'].toString(),
                  child: Text('${model['modelName']} • ${model['productCode']}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _cavityModelIds[index] = value),
            ),
            if (model != null) ...[
              const SizedBox(height: 10),
              _variantRow('Black', variants['Black']),
              _variantRow('Clear', variants['Clear']),
              _variantRow('PC', variants['PC']),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _piecesPerCycleControllers[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pieces Per Cycle', prefixIcon: Icon(Icons.repeat_one_outlined)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantRow(String type, dynamic rawVariant) {
    final variant = rawVariant is Map ? Map<String, dynamic>.from(rawVariant) : <String, dynamic>{};
    final name = variant['productName']?.toString() ?? 'Missing';
    final code = variant['productCode']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 62, child: Text(type, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(code.isEmpty ? name : '$name • $code', overflow: TextOverflow.ellipsis)),
          const Icon(Icons.lock_outline, size: 16),
        ],
      ),
    );
  }

  Widget _stockField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '$label Opening Stock', prefixIcon: const Icon(Icons.inventory_outlined)),
    );
  }

  Widget _buildSectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
