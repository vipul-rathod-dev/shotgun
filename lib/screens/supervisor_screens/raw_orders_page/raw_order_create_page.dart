import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RawOrderCreatePage extends StatefulWidget {
  const RawOrderCreatePage({super.key});

  @override
  State<RawOrderCreatePage> createState() => _RawOrderCreatePageState();
}

class _RawOrderCreatePageState extends State<RawOrderCreatePage> {
  String? _companyId;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _molds = [];
  List<Map<String, dynamic>> _suppliers = [];
  final List<_OrderMoldSelection> _selectedMolds = [];

  String? _supplierId;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDate;
  final _notesController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _products =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('raw_orders');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final mold in _selectedMolds) {
      mold.dispose();
    }
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
      await Future.wait([_loadMolds(), _loadSuppliers()]);
    } catch (e) {
      if (mounted) _showMessage('Failed to load order data: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuppliers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('suppliers')
        .get();

    _suppliers = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['supplierName']?.toString() ??
            data['name']?.toString() ??
            data['displayName']?.toString() ??
            data['companyName']?.toString() ??
            'Unnamed Supplier',
      };
    }).toList();
    _suppliers.sort((a, b) =>
        a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
  }

  Future<void> _loadMolds() async {
    final snapshot = await _products
        .where('category', isEqualTo: 'Other')
        .where('type', isEqualTo: 'Mold')
        .get();

    _molds = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['displayName']?.toString() ?? data['name']?.toString() ?? 'Unnamed Mold',
        'productCode': data['productCode']?.toString() ?? '',
        'cavities': _normalizeCavities(data['cavities']),
      };
    }).where((mold) => (mold['cavities'] as List).isNotEmpty).toList();

    _molds.sort((a, b) =>
        a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
  }

  List<Map<String, dynamic>> _normalizeCavities(dynamic value) {
    if (value is! List) return [];

    return value.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final rawVariants = map['variants'];
      final variants = <String, Map<String, dynamic>>{};

      if (rawVariants is Map) {
        for (final type in const ['Black', 'Clear', 'PC']) {
          final value = rawVariants[type];
          if (value is Map) {
            variants[type] = Map<String, dynamic>.from(value);
          }
        }
      }

      return {
        'cavityNumber': _toInt(map['cavityNumber']),
        'modelId': map['modelId']?.toString() ?? '',
        'modelName': map['modelName']?.toString() ?? '',
        'variants': variants,
        'piecesPerCycle': _toInt(map['piecesPerCycle']) < 1
            ? 1
            : _toInt(map['piecesPerCycle']),
      };
    }).toList();
  }

  void _addMold() {
    if (_molds.isEmpty) {
      _showMessage('No valid molds are available.', error: true);
      return;
    }

    setState(() {
      _selectedMolds.add(_OrderMoldSelection());
    });
  }

  void _removeMold(int index) {
    setState(() {
      final removed = _selectedMolds.removeAt(index);
      removed.dispose();
    });
  }

  void _selectMold(int index, String? moldId) {
    final selection = _selectedMolds[index];
    final mold = _molds.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['id'] == moldId,
          orElse: () => null,
        );

    if (mold == null) return;

    final alreadyUsed = _selectedMolds.asMap().entries.any(
          (entry) => entry.key != index && entry.value.moldId == moldId,
        );

    if (alreadyUsed) {
      _showMessage('This mold is already added to the order.', error: true);
      return;
    }

    setState(() {
      selection.setMold(mold);
    });
  }

  int get _selectedVariantCount {
    var count = 0;
    for (final mold in _selectedMolds) {
      for (final cavity in mold.cavities) {
        for (final variant in cavity.variants.values) {
          if (variant.selected && variant.quantity > 0) count++;
        }
      }
    }
    return count;
  }

  int get _totalPieces {
    var total = 0;
    for (final mold in _selectedMolds) {
      for (final cavity in mold.cavities) {
        for (final variant in cavity.variants.values) {
          total += variant.quantity;
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _buildItems() {
    final items = <Map<String, dynamic>>[];

    for (final mold in _selectedMolds) {
      for (final cavity in mold.cavities) {
        for (final entry in cavity.variants.entries) {
          final type = entry.key;
          final variant = entry.value;
          if (!variant.selected || variant.quantity <= 0) continue;

          items.add({
            'moldProductId': mold.moldId,
            'moldName': mold.moldName,
            'moldProductCode': mold.moldProductCode,
            'cavityNumber': cavity.cavityNumber,
            'modelId': cavity.modelId,
            'modelName': cavity.modelName,
            'variantType': type,
            'productId': variant.productId,
            'productName': variant.productName,
            'productCode': variant.productCode,
            'orderedQuantity': variant.quantity,
            'receivedQuantity': 0,
            'piecesPerCycle': cavity.piecesPerCycle,
          });
        }
      }
    }

    return items;
  }

  Future<void> _saveOrder() async {
    if (_companyId == null || _saving) return;

    if (_supplierId == null || _supplierId!.isEmpty) {
      _showMessage('Please select a supplier.', error: true);
      return;
    }

    if (_selectedMolds.isEmpty) {
      _showMessage('Add at least one mold to the order.', error: true);
      return;
    }

    final items = _buildItems();
    if (items.isEmpty) {
      _showMessage('Select at least one variant and enter a quantity greater than 0.', error: true);
      return;
    }

    Map<String, dynamic>? supplier;

    for (final item in _suppliers) {
      if (item['id']?.toString() == _supplierId) {
        supplier = item;
        break;
      }
    }

    supplier ??= <String, dynamic>{
      'id': _supplierId,
      'name': '',
    };

    setState(() => _saving = true);

    try {
      final orderRef = _ordersRef.doc();
      final orderNumber = 'RM-${DateTime.now().millisecondsSinceEpoch}';

      await orderRef.set({
        'orderNumber': orderNumber,
        'supplierId': _supplierId,
        'supplierName': supplier['name']?.toString() ?? '',
        'items': items,
        'moldCount': _selectedMolds.length,
        'variantCount': items.length,
        'orderedPieces': _totalPieces,
        'receivedPieces': 0,
        'status': 'Ordered',
        'orderDate': Timestamp.fromDate(_orderDate),
        'expectedDate': _expectedDate == null ? null : Timestamp.fromDate(_expectedDate!),
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to create raw order: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Raw Mold Order'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(wide),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mold & Variant Requirements',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _addMold,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Mold'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedMolds.isEmpty)
                            _buildEmptyMolds()
                          else
                            ..._selectedMolds.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildMoldCard(entry.key, entry.value, wide),
                                  ),
                                ),
                          const SizedBox(height: 8),
                          _buildSummaryCard(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveOrder,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Create Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool wide) {
    final supplierItems = _suppliers
        .map(
          (supplier) => DropdownMenuItem<String>(
            value: supplier['id'].toString(),
            child: Text(supplier['name'].toString(), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 700;
            final fields = [
              DropdownButtonFormField<String>(
                value: _supplierId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: supplierItems,
                onChanged: (value) => setState(() => _supplierId = value),
              ),
              _dateField(
                label: 'Order Date',
                value: _orderDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _orderDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _orderDate = picked);
                },
              ),
              _dateField(
                label: 'Expected Date',
                value: _expectedDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expectedDate ?? _orderDate,
                    firstDate: _orderDate,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _expectedDate = picked);
                },
              ),
              TextField(
                controller: _notesController,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Order Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ];

            if (!twoColumns) {
              return Column(
                children: fields
                    .map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ))
                    .toList(),
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: fields[2]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[3]),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? 'Not set' : _formatDate(value)),
      ),
    );
  }

  Widget _buildEmptyMolds() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.precision_manufacturing_outlined,
                  size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              const Text('No molds added to this order yet.'),
              const SizedBox(height: 8),
              const Text(
                'Add a mold and then choose the exact Raw variants and quantities required.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoldCard(int index, _OrderMoldSelection selection, bool wide) {
    final moldItems = _molds
        .map(
          (mold) => DropdownMenuItem<String>(
            value: mold['id'].toString(),
            child: Text(
              '${mold['name']}${(mold['productCode']?.toString() ?? '').isEmpty ? '' : ' • ${mold['productCode']}'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mold ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove mold',
                  onPressed: _saving ? null : () => _removeMold(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selection.moldId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Mold',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
              items: moldItems,
              onChanged: (value) => _selectMold(index, value),
            ),
            if (selection.moldId != null) ...[
              const SizedBox(height: 16),
              ...selection.cavities.asMap().entries.map(
                    (entry) => _buildCavity(index, entry.key, entry.value, wide),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCavity(
    int moldIndex,
    int cavityIndex,
    _CavitySelection cavity,
    bool wide,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cavity ${cavity.cavityNumber} • ${cavity.modelName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('1 cycle = ${cavity.piecesPerCycle} pcs',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Select the variants you want to order and enter each quantity.'),
          const SizedBox(height: 10),
          ...const ['Black', 'Clear', 'PC'].map(
            (type) => _buildVariantRow(cavity, type),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantRow(_CavitySelection cavity, String type) {
    final variant = cavity.variants[type];
    if (variant == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$type variant is not configured for this model.',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: variant.selected,
            onChanged: (value) {
              setState(() => variant.selected = value ?? false);
            },
          ),
          SizedBox(
            width: 64,
            child: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              variant.productName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: variant.controller,
              enabled: variant.selected,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                suffixText: 'pcs',
              ),
              onChanged: (value) {
                variant.quantity = int.tryParse(value.trim()) ?? 0;
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 30,
          runSpacing: 12,
          children: [
            _summaryItem('Molds', '${_selectedMolds.length}'),
            _summaryItem('Variant Lines', '$_selectedVariantCount'),
            _summaryItem('Total Pieces', '$_totalPieces'),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

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

class _OrderMoldSelection {
  String? moldId;
  String moldName = '';
  String moldProductCode = '';
  List<_CavitySelection> cavities = [];

  void setMold(Map<String, dynamic> mold) {
    moldId = mold['id']?.toString();
    moldName = mold['name']?.toString() ?? '';
    moldProductCode = mold['productCode']?.toString() ?? '';
    dispose();
    cavities = (mold['cavities'] as List)
        .map((e) => _CavitySelection.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void dispose() {
    for (final cavity in cavities) {
      cavity.dispose();
    }
  }
}

class _CavitySelection {
  final int cavityNumber;
  final String modelId;
  final String modelName;
  final int piecesPerCycle;
  final Map<String, _VariantSelection> variants;

  _CavitySelection({
    required this.cavityNumber,
    required this.modelId,
    required this.modelName,
    required this.piecesPerCycle,
    required this.variants,
  });

  factory _CavitySelection.fromMap(Map<String, dynamic> map) {
    final rawVariants = map['variants'];
    final variants = <String, _VariantSelection>{};

    if (rawVariants is Map) {
      for (final type in const ['Black', 'Clear', 'PC']) {
        final value = rawVariants[type];
        if (value is Map) {
          final v = Map<String, dynamic>.from(value);
          variants[type] = _VariantSelection(
            productId: v['productId']?.toString() ?? '',
            productName: v['productName']?.toString() ?? '',
            productCode: v['productCode']?.toString() ?? '',
          );
        }
      }
    }

    return _CavitySelection(
      cavityNumber: _parseInt(map['cavityNumber']),
      modelId: map['modelId']?.toString() ?? '',
      modelName: map['modelName']?.toString() ?? '',
      piecesPerCycle: _parseInt(map['piecesPerCycle']) < 1
          ? 1
          : _parseInt(map['piecesPerCycle']),
      variants: variants,
    );
  }

  void dispose() {
    for (final variant in variants.values) {
      variant.dispose();
    }
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _VariantSelection {
  final String productId;
  final String productName;
  final String productCode;
  bool selected = false;
  int quantity = 0;
  final TextEditingController controller = TextEditingController();

  _VariantSelection({
    required this.productId,
    required this.productName,
    required this.productCode,
  });

  void dispose() => controller.dispose();
}
