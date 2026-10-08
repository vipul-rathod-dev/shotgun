import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

class EditDrummingOrderPage extends StatefulWidget {
  final String orderId;

  final Map<String, dynamic>? order;

  const EditDrummingOrderPage({super.key, required this.orderId, this.order});

  @override
  State<EditDrummingOrderPage> createState() => _EditDrummingOrderPageState();
}

class _EditDrummingOrderPageState extends State<EditDrummingOrderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  String? _companyId;

  Map<String, dynamic>? _order;

  bool _isLoading = true;

  bool _isSaving = false;

  List<Map<String, dynamic>> _suppliers = [];

  String? _selectedSupplierId;

  String? _selectedSupplierName;

  final Map<String, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _productId(Map<String, dynamic> item) =>
      _stringValue(item['productId']);

  String _materialType(Map<String, dynamic> item) {
    return _stringValue(
      item['materialType'] ??
          item['material'] ??
          item['rawMaterialType'] ??
          item['variantType'],
    );
  }

  String _componentType(Map<String, dynamic> item) =>
      _stringValue(item['componentType']).toLowerCase();

  String _side(Map<String, dynamic> item) => _stringValue(item['side']);

  String _variantKey(Map<String, dynamic> item) {
    final productId = _productId(item);
    final material = _materialType(item).toLowerCase();
    final component = _componentType(item);
    final isTemple = component == 'temple' || component.contains('temple');

    // Focus: productId + material.
    // Temple: productId + material + side.
    if (productId.isNotEmpty) {
      if (isTemple) {
        return 'product:$productId|material:$material|side:${_side(item).toLowerCase()}';
      }
      return 'product:$productId|material:$material';
    }

    // Safe fallback for legacy rows without productId.
    final productCode = _stringValue(item['productCode']).toLowerCase();
    final productName = _stringValue(item['productName']).toLowerCase();

    if (isTemple) {
      return 'fallback:$productCode|name:$productName|material:$material|side:${_side(item).toLowerCase()}';
    }
    return 'fallback:$productCode|name:$productName|material:$material';
  }

  List<Map<String, dynamic>> _groupVariantItems(
    List<Map<String, dynamic>> source,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final raw in source) {
      final item = Map<String, dynamic>.from(raw);
      final key = _variantKey(item);

      if (!grouped.containsKey(key)) {
        grouped[key] = item;
        continue;
      }

      final existing = grouped[key]!;
      existing['orderedQuantity'] =
          _toInt(existing['orderedQuantity']) + _toInt(item['orderedQuantity']);
      existing['receivedQuantity'] =
          _toInt(existing['receivedQuantity']) +
          _toInt(item['receivedQuantity']);
    }

    return grouped.values.toList();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.trim().isEmpty) {
        throw Exception('Company information is not available.');
      }

      final orderRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('raw_orders')
          .doc(widget.orderId);

      final orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists) {
        throw Exception('Drumming order not found.');
      }

      final supplierSnapshot =
          await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('suppliers')
              .where('role', isEqualTo: 'Drumming')
              .get();

      final suppliers =
          supplierSnapshot.docs
              .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
              .toList();

      final order = <String, dynamic>{
        ...orderSnapshot.data()!,

        'id': orderSnapshot.id,
      };

      final rawItems = order['items'];

      final rawItemList =
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

      // One editable row per logical variant:
      // Focus  -> productId + material
      // Temple -> productId + material + side
      final items = _groupVariantItems(rawItemList);

      order['items'] = items;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final ordered = _toInt(item['orderedQuantity']);
        final received = _toInt(item['receivedQuantity']);
        final minimum = ordered < received ? received : ordered;

        _quantityControllers['$i'] = TextEditingController(
          text: minimum.toString(),
        );
      }

      String? supplierId = order['supplierId']?.toString();

      String? supplierName = order['supplierName']?.toString();

      if (supplierId != null &&
          !suppliers.any(
            (supplier) => supplier['id']?.toString() == supplierId,
          )) {
        supplierId = null;
      }

      if (supplierId != null) {
        final matching = suppliers.firstWhere(
          (supplier) => supplier['id']?.toString() == supplierId,

          orElse: () => <String, dynamic>{},
        );

        if (matching.isNotEmpty) {
          supplierName = _supplierDisplayName(matching);
        }
      }

      if (!mounted) return;

      setState(() {
        _companyId = companyId;

        _order = order;

        _suppliers = suppliers;

        _selectedSupplierId = supplierId;

        _selectedSupplierName = supplierName;

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

  List<Map<String, dynamic>> _items() {
    final raw = _order?['items'];
    if (raw is! List) return <Map<String, dynamic>>[];

    final items =
        raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

    return _groupVariantItems(items);
  }

  int _calculateShots(List<Map<String, dynamic>> items) {
    return items.fold<int>(0, (total, item) {
      final quantity = _toInt(item['orderedQuantity']);

      final piecesPerCycle = _toInt(
        item['piecesPerCycle'] ?? item['piecesPerShot'] ?? 1,
      );

      return total +
          (piecesPerCycle > 0 ? (quantity / piecesPerCycle).ceil() : quantity);
    });
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final companyId = _companyId;

    final orderId = widget.orderId;

    if (companyId == null || companyId.isEmpty || orderId.isEmpty) {
      _showMessage('Unable to update this order.', error: true);

      return;
    }

    if (_selectedSupplierId == null || _selectedSupplierId!.isEmpty) {
      _showMessage('Please select a Drumming supplier.', error: true);

      return;
    }

    final items = _items();
    final updatedItems = <Map<String, dynamic>>[];

    for (var i = 0; i < items.length; i++) {
      final item = Map<String, dynamic>.from(items[i]);
      final received = _toInt(item['receivedQuantity']);

      final quantity =
          int.tryParse(_quantityControllers['$i']!.text.trim()) ?? -1;

      if (quantity < 0) {
        _showMessage(
          'Enter a valid quantity for ${item['productName'] ?? 'variant ${i + 1}'}.',
          error: true,
        );
        return;
      }

      if (quantity < received) {
        _showMessage(
          '${item['productName'] ?? 'Variant ${i + 1}'} cannot be below the received quantity ($received).',
          error: true,
        );
        return;
      }

      item['orderedQuantity'] = quantity;
      item['receivedQuantity'] = received;
      updatedItems.add(item);
    }

    final orderedPieces = updatedItems.fold<int>(
      0,

      (total, item) => total + _toInt(item['orderedQuantity']),
    );

    final receivedPieces = updatedItems.fold<int>(
      0,

      (total, item) => total + _toInt(item['receivedQuantity']),
    );

    final status =
        receivedPieces <= 0
            ? 'Pending'
            : receivedPieces >= orderedPieces
            ? 'Received'
            : 'Partially Received';

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('raw_orders')
          .doc(orderId)
          .update({
            'supplierId': _selectedSupplierId,

            'supplierName': _selectedSupplierName ?? '',

            'items': updatedItems,

            'orderedPieces': orderedPieces,

            'receivedPieces': receivedPieces,

            'orderedShots': _calculateShots(updatedItems),

            'status': status,

            'updatedAt': FieldValue.serverTimestamp(),

            'updatedByUid': user?.uid,

            'updatedByName': user?.displayName ?? '',
          });

      if (!mounted) return;

      _showMessage('Drumming order updated successfully.');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to update order: ${e.toString().replaceFirst('Exception: ', '')}',

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
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12)),

        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String _itemTitle(Map<String, dynamic> item, int index) {
    final name = item['productName']?.toString().trim() ?? '';

    if (name.isNotEmpty) return name;

    return 'Variant ${index + 1}';
  }

  String _itemSubtitle(Map<String, dynamic> item) {
    final values = <String>[];

    final component = item['componentType']?.toString().trim() ?? '';

    final side = item['side']?.toString().trim() ?? '';

    final variant = item['variantType']?.toString().trim() ?? '';

    final model = item['modelName']?.toString().trim() ?? '';

    if (component.isNotEmpty) values.add(component);

    if (side.isNotEmpty) values.add(side);

    if (variant.isNotEmpty) values.add(variant);

    if (model.isNotEmpty) values.add(model);

    return values.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = _order?['orderNumber']?.toString() ?? '-';

    final items = _items();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Edit Drumming Order',

              style: GoogleFonts.poppins(
                fontSize: 17,

                fontWeight: FontWeight.w600,

                color: const Color(0xFF343741),
              ),
            ),

            Text(
              orderNumber,

              style: GoogleFonts.poppins(
                fontSize: 11,

                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _order == null
              ? Center(
                child: Text(
                  'Unable to load order.',

                  style: GoogleFonts.poppins(),
                ),
              )
              : Form(
                key: _formKey,

                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),

                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),

                                decoration: BoxDecoration(
                                  color: Colors.white,

                                  borderRadius: BorderRadius.circular(12),

                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      'Drumming Supplier',

                                      style: GoogleFonts.poppins(
                                        fontSize: 13,

                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    DropdownButtonFormField<String>(
                                      value: _selectedSupplierId,

                                      isExpanded: true,

                                      decoration: InputDecoration(
                                        hintText:
                                            _suppliers.isEmpty
                                                ? 'No Drumming suppliers available'
                                                : 'Select Drumming supplier',

                                        filled: true,

                                        fillColor: const Color(0xFFF9FAFB),

                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                      ),

                                      items:
                                          _suppliers.map((supplier) {
                                            final id =
                                                supplier['id']?.toString() ??
                                                '';

                                            return DropdownMenuItem<String>(
                                              value: id,

                                              child: Text(
                                                _supplierDisplayName(supplier),

                                                overflow: TextOverflow.ellipsis,

                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            );
                                          }).toList(),

                                      onChanged:
                                          _isSaving
                                              ? null
                                              : (value) {
                                                Map<String, dynamic>? supplier;

                                                for (final item in _suppliers) {
                                                  if (item['id']?.toString() ==
                                                      value) {
                                                    supplier = item;

                                                    break;
                                                  }
                                                }

                                                setState(() {
                                                  _selectedSupplierId = value;

                                                  _selectedSupplierName =
                                                      supplier == null
                                                          ? null
                                                          : _supplierDisplayName(
                                                            supplier,
                                                          );
                                                });
                                              },

                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a Drumming supplier';
                                        }

                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Variant Quantities',

                                style: GoogleFonts.poppins(
                                  fontSize: 15,

                                  fontWeight: FontWeight.w600,

                                  color: const Color(0xFF343741),
                                ),
                              ),

                              const SizedBox(height: 10),

                              if (items.isEmpty)
                                Container(
                                  width: double.infinity,

                                  padding: const EdgeInsets.all(20),

                                  decoration: BoxDecoration(
                                    color: Colors.white,

                                    borderRadius: BorderRadius.circular(12),

                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),

                                  child: Text(
                                    'No variants found in this order.',

                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,

                                  physics: const NeverScrollableScrollPhysics(),

                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: wide ? 2 : 1,

                                        crossAxisSpacing: 12,

                                        mainAxisSpacing: 12,

                                        childAspectRatio: wide ? 4.0 : 3.2,
                                      ),

                                  itemCount: items.length,

                                  itemBuilder: (context, index) {
                                    final item = items[index];

                                    final received = _toInt(
                                      item['receivedQuantity'],
                                    );

                                    final subtitle = _itemSubtitle(item);

                                    return Container(
                                      padding: const EdgeInsets.all(12),

                                      decoration: BoxDecoration(
                                        color: Colors.white,

                                        borderRadius: BorderRadius.circular(10),

                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),

                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,

                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,

                                              children: [
                                                Text(
                                                  _itemTitle(item, index),

                                                  maxLines: 1,

                                                  overflow:
                                                      TextOverflow.ellipsis,

                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,

                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                if (subtitle.isNotEmpty)
                                                  Text(
                                                    subtitle,

                                                    maxLines: 1,

                                                    overflow:
                                                        TextOverflow.ellipsis,

                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,

                                                      color: const Color(
                                                        0xFF6B7280,
                                                      ),
                                                    ),
                                                  ),

                                                if (received > 0)
                                                  Text(
                                                    'Received: $received • minimum allowed',

                                                    style: GoogleFonts.poppins(
                                                      fontSize: 9,

                                                      color: Colors.orange[800],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 12),

                                          SizedBox(
                                            width: 105,

                                            child: TextFormField(
                                              controller:
                                                  _quantityControllers['$index'],

                                              enabled: !_isSaving,

                                              keyboardType:
                                                  TextInputType.number,

                                              decoration: InputDecoration(
                                                labelText: 'Quantity',

                                                filled: true,

                                                fillColor: const Color(
                                                  0xFFF9FAFB,
                                                ),

                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,

                                                      vertical: 8,
                                                    ),

                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),

                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                              ),

                                              validator: (value) {
                                                final quantity = int.tryParse(
                                                  value?.trim() ?? '',
                                                );

                                                if (quantity == null ||
                                                    quantity < received) {
                                                  return 'Min $received';
                                                }

                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,

                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        _isSaving
                                            ? null
                                            : () => Navigator.pop(context),

                                    child: Text(
                                      'Cancel',

                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _save,

                                    icon:
                                        _isSaving
                                            ? const SizedBox(
                                              width: 17,

                                              height: 17,

                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,

                                                color: Colors.white,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.save_outlined,

                                              size: 18,
                                            ),

                                    label: Text(
                                      'Save Changes',

                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3F51B5),

                                      foregroundColor: Colors.white,

                                      minimumSize: const Size(150, 44),
                                    ),
                                  ),
                                ],
                              ),
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
}
