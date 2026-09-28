import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RawOrdersPage extends StatefulWidget {
  const RawOrdersPage({super.key});

  @override
  State<RawOrdersPage> createState() => _RawOrdersPageState();
}

class _RawOrdersPageState extends State<RawOrdersPage> {
  String? _companyId;

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _rawOrders = [];

  String _searchQuery = '';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _cavityOptions = [
    'Single',
    'Double',
  ];

  static const List<String> _componentTypes = [
    'Focus',
    'Temple',
  ];

  static const List<String> _materialTypes = [
    'Black',
    'Clear',
    'PC',
  ];

  static const List<String> _statuses = [
    'Pending',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.isEmpty) {
        throw Exception(
          'Company ID not found. Please log in again.',
        );
      }

      _companyId = companyId;

      await Future.wait([
        _loadSuppliers(),
        _loadProducts(),
        _loadRawOrders(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Raw Orders initialization error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showSnackBar(
          'Failed to load raw orders: $e',
          isError: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE REFERENCES
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _rawOrdersCollection {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('raw_orders');
  }

  CollectionReference<Map<String, dynamic>> get _suppliersCollection {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('suppliers');
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products');
  }

  // ---------------------------------------------------------------------------
  // SUPPLIERS
  // ---------------------------------------------------------------------------

  Future<void> _loadSuppliers() async {
    if (_companyId == null) return;

    final snapshot = await _suppliersCollection.get();

    final suppliers = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': _getSupplierName(data),
      };
    }).where((supplier) {
      final name = supplier['name']?.toString().trim() ?? '';
      return name.isNotEmpty;
    }).toList();

    suppliers.sort(
      (a, b) => a['name']
          .toString()
          .toLowerCase()
          .compareTo(b['name'].toString().toLowerCase()),
    );

    _suppliers = suppliers;
  }

  String _getSupplierName(Map<String, dynamic> data) {
    final possibleFields = [
      'supplierName',
      'name',
      'displayName',
      'companyName',
    ];

    for (final field in possibleFields) {
      final value = data[field];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return 'Unnamed Supplier';
  }

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  Future<void> _loadProducts() async {
    if (_companyId == null) return;

    final snapshot = await _productsCollection.get();

    final products = snapshot.docs
        .map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'name': data['displayName']?.toString() ??
                data['name']?.toString() ??
                'Unnamed Product',
            'category': data['category']?.toString() ?? '',
            'type': data['type']?.toString() ?? '',
            'productCode': data['productCode']?.toString() ?? '',
          };
        })
        .where((product) {
          final category =
              product['category']?.toString().trim().toLowerCase() ?? '';

          final type =
              product['type']?.toString().trim().toLowerCase() ?? '';

          return category == 'other' && type == 'mold';
        })
        .toList();

    products.sort(
      (a, b) => a['name']
          .toString()
          .toLowerCase()
          .compareTo(
            b['name'].toString().toLowerCase(),
          ),
    );

    _products = products;
  }

  // ---------------------------------------------------------------------------
  // RAW ORDERS
  // ---------------------------------------------------------------------------

  Future<void> _loadRawOrders() async {
    if (_companyId == null) return;

    final snapshot = await _rawOrdersCollection
        .orderBy('createdAt', descending: true)
        .get();

    _rawOrders = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        _loadSuppliers(),
        _loadProducts(),
        _loadRawOrders(),
      ]);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showSnackBar(
        'Failed to refresh raw orders: $e',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SAFE NUMBER CONVERSION
  // ---------------------------------------------------------------------------

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredOrders {
    final query = _searchQuery.trim().toLowerCase();

    return _rawOrders.where((order) {
      final supplierName =
          order['supplierName']?.toString().toLowerCase() ?? '';

      final productName =
          order['productName']?.toString().toLowerCase() ?? '';

      final componentType =
          order['componentType']?.toString().toLowerCase() ?? '';

      final materialType =
          order['materialType']?.toString().toLowerCase() ?? '';

      final status =
          order['status']?.toString() ?? 'Pending';

      final matchesSearch = query.isEmpty ||
          supplierName.contains(query) ||
          productName.contains(query) ||
          componentType.contains(query) ||
          materialType.contains(query);

      final matchesStatus =
          _selectedStatus == 'All' || status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------

  int get _totalOrders => _rawOrders.length;

  int get _pendingOrders {
    return _rawOrders
        .where((order) => order['status'] == 'Pending')
        .length;
  }

  int get _inProgressOrders {
    return _rawOrders
        .where((order) => order['status'] == 'In Progress')
        .length;
  }

  int get _completedOrders {
    return _rawOrders
        .where((order) => order['status'] == 'Completed')
        .length;
  }

  // ---------------------------------------------------------------------------
  // CREATE / EDIT RAW ORDER
  // ---------------------------------------------------------------------------

  Future<void> _showRawOrderDialog({
    Map<String, dynamic>? existingOrder,
  }) async {
    if (_companyId == null) return;

    final isEditing = existingOrder != null;

    String? selectedSupplierId =
        existingOrder?['supplierId']?.toString();

    String? selectedProductId =
        existingOrder?['productId']?.toString();

    String selectedCavity =
        existingOrder?['cavity']?.toString() ?? 'Single';

    String selectedComponentType =
        existingOrder?['componentType']?.toString() ?? 'Focus';

    String selectedMaterialType =
        existingOrder?['materialType']?.toString() ?? 'Black';

    String selectedRawMaterial =
        existingOrder?['rawMaterial']?.toString() ?? 'Black';

    String selectedStatus =
        existingOrder?['status']?.toString() ?? 'Pending';

    final quantityController = TextEditingController(
      text: existingOrder != null
          ? _toInt(existingOrder['quantity']).toString()
          : '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int enteredQuantity =
                _toInt(quantityController.text);

            int expectedPieces =
                selectedCavity == 'Double'
                    ? enteredQuantity * 2
                    : enteredQuantity;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              titlePadding: const EdgeInsets.fromLTRB(
                24,
                22,
                24,
                8,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                8,
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                18,
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit Raw Order'
                          : 'Create Raw Order',
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 550;

                        final fields = [
                          _buildDialogDropdown<String>(
                            label: 'Supplier',
                            icon: Icons.business_outlined,
                            value: selectedSupplierId,
                            items: _suppliers.map((supplier) {
                              return DropdownMenuItem<String>(
                                value: supplier['id'].toString(),
                                child: Text(
                                  supplier['name'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSupplierId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select supplier';
                              }
                              return null;
                            },
                          ),
                          _buildDialogDropdown<String>(
                            label: 'Product',
                            icon: Icons.inventory_2_outlined,
                            value: selectedProductId,
                            items: _products.map((product) {
                              return DropdownMenuItem<String>(
                                value: product['id'].toString(),
                                child: Text(
                                  product['name'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedProductId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select product';
                              }
                              return null;
                            },
                          ),
                          _buildDialogDropdown<String>(
                            label: 'Cavity',
                            icon: Icons.grid_view_outlined,
                            value: selectedCavity,
                            items: _cavityOptions.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedCavity = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setDialogState(() {});
                            },
                            validator: (value) {
                              final quantity =
                                  int.tryParse(value?.trim() ?? '');

                              if (quantity == null || quantity <= 0) {
                                return 'Enter valid shots';
                              }

                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Quantity (Shots)',
                              prefixIcon: const Icon(
                                Icons.numbers_outlined,
                              ),
                              suffixText: 'Shots',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          _buildDialogDropdown<String>(
                            label: 'Component Type',
                            icon: Icons.category_outlined,
                            value: selectedComponentType,
                            items: _componentTypes.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedComponentType = value;
                              });
                            },
                          ),
                          _buildDialogDropdown<String>(
                            label: 'Material Type',
                            icon: Icons.layers_outlined,
                            value: selectedMaterialType,
                            items: _materialTypes.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedMaterialType = value;
                              });
                            },
                          ),
                          _buildDialogDropdown<String>(
                            label: 'Raw Material',
                            icon: Icons.scatter_plot_outlined,
                            value: selectedRawMaterial,
                            items: _materialTypes.map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                selectedRawMaterial = value;
                              });
                            },
                          ),
                          if (isEditing)
                            _buildDialogDropdown<String>(
                              label: 'Status',
                              icon: Icons.flag_outlined,
                              value: selectedStatus,
                              items: _statuses.map((value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedStatus = value;
                                });
                              },
                            ),
                        ];

                        if (isMobile) {
                          return Column(
                            children: [
                              for (int i = 0; i < fields.length; i++) ...[
                                fields[i],
                                if (i != fields.length - 1)
                                  const SizedBox(height: 14),
                              ],
                              const SizedBox(height: 18),
                              _buildExpectedPiecesCard(
                                selectedCavity,
                                expectedPieces,
                              ),
                            ],
                          );
                        }

                        final rows = <Widget>[];

                        for (int i = 0; i < fields.length; i += 2) {
                          final first = fields[i];
                          final second =
                              i + 1 < fields.length
                                  ? fields[i + 1]
                                  : const SizedBox();

                          rows.add(
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(child: first),
                                const SizedBox(width: 14),
                                Expanded(child: second),
                              ],
                            ),
                          );

                          rows.add(
                            const SizedBox(height: 14),
                          );
                        }

                        rows.add(
                          _buildExpectedPiecesCard(
                            selectedCavity,
                            expectedPieces,
                          ),
                        );

                        return Column(
                          children: rows,
                        );
                      },
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ??
                              false)) {
                            return;
                          }

                          await _saveRawOrder(
                            dialogContext: dialogContext,
                            existingOrder: existingOrder,
                            supplierId: selectedSupplierId!,
                            productId: selectedProductId!,
                            cavity: selectedCavity,
                            quantity: int.parse(
                              quantityController.text.trim(),
                            ),
                            componentType: selectedComponentType,
                            materialType: selectedMaterialType,
                            rawMaterial: selectedRawMaterial,
                            status: selectedStatus,
                          );
                        },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : isEditing
                            ? 'Update Order'
                            : 'Create Order',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
  }

  // ---------------------------------------------------------------------------
  // DIALOG DROPDOWN
  // ---------------------------------------------------------------------------

  Widget _buildDialogDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPECTED PIECES
  // ---------------------------------------------------------------------------

  Widget _buildExpectedPiecesCard(
    String cavity,
    int expectedPieces,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calculate_outlined,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected Pieces',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$expectedPieces pieces',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$cavity cavity',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE RAW ORDER
  // ---------------------------------------------------------------------------

  Future<void> _saveRawOrder({
    required BuildContext dialogContext,
    required Map<String, dynamic>? existingOrder,
    required String supplierId,
    required String productId,
    required String cavity,
    required int quantity,
    required String componentType,
    required String materialType,
    required String rawMaterial,
    required String status,
  }) async {
    if (_companyId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final supplier = _suppliers.firstWhere(
        (item) => item['id'].toString() == supplierId,
        orElse: () => {
          'id': supplierId,
          'name': 'Unknown Supplier',
        },
      );

      final product = _products.firstWhere(
        (item) => item['id'].toString() == productId,
        orElse: () => {
          'id': productId,
          'name': 'Unknown Product',
        },
      );

      final expectedPieces =
          cavity == 'Double' ? quantity * 2 : quantity;

      final data = <String, dynamic>{
        'supplierId': supplierId,
        'supplierName': supplier['name']?.toString() ?? '',
        'productId': productId,
        'productName': product['name']?.toString() ?? '',
        'cavity': cavity,
        'quantity': quantity,
        'quantityUnit': 'shots',
        'expectedPieces': expectedPieces,
        'componentType': componentType,
        'materialType': materialType,
        'rawMaterial': rawMaterial,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingOrder == null) {
        data['createdAt'] = FieldValue.serverTimestamp();

        await _rawOrdersCollection.add(data);
      } else {
        await _rawOrdersCollection
            .doc(existingOrder['id'].toString())
            .update(data);
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      await _loadRawOrders();

      if (mounted) {
        setState(() {});

        _showSnackBar(
          existingOrder == null
              ? 'Raw order created successfully.'
              : 'Raw order updated successfully.',
        );
      }
    } catch (e) {
      debugPrint('Save raw order error: $e');

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        _showSnackBar(
          'Failed to save raw order: $e',
          isError: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> _deleteRawOrder(
    Map<String, dynamic> order,
  ) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Raw Order?'),
          content: Text(
            'Are you sure you want to delete the raw order for '
            '${order['productName'] ?? 'this product'}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _rawOrdersCollection.doc(orderId).delete();

      await _loadRawOrders();

      if (mounted) {
        setState(() {});

        _showSnackBar(
          'Raw order deleted successfully.',
        );
      }
    } catch (e) {
      _showSnackBar(
        'Failed to delete raw order: $e',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  Future<void> _updateStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    try {
      await _rawOrdersCollection.doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadRawOrders();

      if (mounted) {
        setState(() {});

        _showSnackBar(
          'Status updated to $status.',
        );
      }
    } catch (e) {
      _showSnackBar(
        'Failed to update status: $e',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DETAILS
  // ---------------------------------------------------------------------------

  void _showOrderDetails(Map<String, dynamic> order) {
    final quantity = _toInt(order['quantity']);
    final expectedPieces = _toInt(order['expectedPieces']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            30,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Raw Order Details',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildStatusBadge(
                        order['status']?.toString() ?? 'Pending',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow(
                    'Supplier',
                    order['supplierName']?.toString() ?? '-',
                  ),
                  _detailRow(
                    'Product',
                    order['productName']?.toString() ?? '-',
                  ),
                  _detailRow(
                    'Cavity',
                    order['cavity']?.toString() ?? '-',
                  ),
                  _detailRow(
                    'Quantity',
                    '$quantity shots',
                  ),
                  _detailRow(
                    'Expected Pieces',
                    '$expectedPieces pieces',
                  ),
                  _detailRow(
                    'Component',
                    order['componentType']?.toString() ?? '-',
                  ),
                  _detailRow(
                    'Material Type',
                    order['materialType']?.toString() ?? '-',
                  ),
                  _detailRow(
                    'Raw Material',
                    order['rawMaterial']?.toString() ?? '-',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRawOrderDialog(
                          existingOrder: order,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Order'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Raw Orders',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF20242A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading
            ? null
            : () {
                _showRawOrderDialog();
              },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Raw Order'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 700 ? 14 : 24,
                      20,
                      constraints.maxWidth < 700 ? 14 : 24,
                      100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(constraints.maxWidth),
                        const SizedBox(height: 20),
                        _buildFilters(constraints.maxWidth),
                        const SizedBox(height: 18),
                        if (_filteredOrders.isEmpty)
                          _buildEmptyState()
                        else if (constraints.maxWidth < 850)
                          _buildMobileOrders()
                        else
                          _buildDesktopTable(),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARDS
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(double width) {
    final isSmall = width < 650;

    final cards = [
      _summaryCard(
        title: 'Total Orders',
        value: _totalOrders.toString(),
        icon: Icons.assignment_outlined,
        color: Colors.blue,
      ),
      _summaryCard(
        title: 'Pending',
        value: _pendingOrders.toString(),
        icon: Icons.pending_actions_outlined,
        color: Colors.orange,
      ),
      _summaryCard(
        title: 'In Progress',
        value: _inProgressOrders.toString(),
        icon: Icons.sync_outlined,
        color: Colors.indigo,
      ),
      _summaryCard(
        title: 'Completed',
        value: _completedOrders.toString(),
        icon: Icons.check_circle_outline,
        color: Colors.green,
      ),
    ];

    if (isSmall) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1)
            const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters(double width) {
    final isMobile = width < 700;

    final search = TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search supplier, product, component...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final status = DropdownButtonFormField<String>(
      value: _selectedStatus,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        prefixIcon: const Icon(Icons.filter_alt_outlined),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        const DropdownMenuItem(
          value: 'All',
          child: Text('All Statuses'),
        ),
        ..._statuses.map(
          (status) => DropdownMenuItem(
            value: status,
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedStatus = value;
        });
      },
    );

    return isMobile
        ? Column(
            children: [
              search,
              const SizedBox(height: 12),
              status,
            ],
          )
        : Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              SizedBox(
                width: 230,
                child: status,
              ),
            ],
          );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP TABLE
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.withOpacity(0.10),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 54,
            dataRowMinHeight: 68,
            dataRowMaxHeight: 76,
            columnSpacing: 28,
            headingRowColor: MaterialStateProperty.all(
              const Color(0xFFF8F9FB),
            ),
            columns: [
              _dataColumn('Supplier'),
              _dataColumn('Product'),
              _dataColumn('Cavity'),
              _dataColumn('Shots'),
              _dataColumn('Expected Pieces'),
              _dataColumn('Component'),
              _dataColumn('Material'),
              _dataColumn('Raw Material'),
              _dataColumn('Status'),
              _dataColumn('Actions'),
            ],
            rows: _filteredOrders.map((order) {
              final quantity = _toInt(order['quantity']);
              final expectedPieces =
                  _toInt(order['expectedPieces']);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      order['supplierName']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    Text(
                      order['productName']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    Text(
                      order['cavity']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    Text('$quantity'),
                  ),
                  DataCell(
                    Text(
                      '$expectedPieces',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    _buildComponentBadge(
                      order['componentType']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    _buildMaterialBadge(
                      order['materialType']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    _buildMaterialBadge(
                      order['rawMaterial']?.toString() ?? '-',
                    ),
                  ),
                  DataCell(
                    _buildStatusBadge(
                      order['status']?.toString() ?? 'Pending',
                    ),
                  ),
                  DataCell(
                    _buildActionsMenu(order),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _dataColumn(String title) {
    return DataColumn(
      label: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE
  // ---------------------------------------------------------------------------

  Widget _buildMobileOrders() {
    return Column(
      children: _filteredOrders.map((order) {
        final quantity = _toInt(order['quantity']);
        final expectedPieces =
            _toInt(order['expectedPieces']);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showOrderDetails(order),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing_outlined,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['productName']?.toString() ??
                                'Unknown Product',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order['supplierName']?.toString() ??
                                'Unknown Supplier',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildActionsMenu(order),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      Icons.grid_view_outlined,
                      order['cavity']?.toString() ?? '-',
                    ),
                    _infoChip(
                      Icons.numbers_outlined,
                      '$quantity shots',
                    ),
                    _infoChip(
                      Icons.calculate_outlined,
                      '$expectedPieces pcs',
                    ),
                    _infoChip(
                      Icons.category_outlined,
                      order['componentType']?.toString() ?? '-',
                    ),
                    _infoChip(
                      Icons.layers_outlined,
                      order['materialType']?.toString() ?? '-',
                    ),
                    _infoChip(
                      Icons.scatter_plot_outlined,
                      order['rawMaterial']?.toString() ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge(
                      order['status']?.toString() ?? 'Pending',
                    ),
                    const Spacer(),
                    Text(
                      'Tap for details',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGES
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge(String status) {
    Color background;
    Color foreground;

    switch (status) {
      case 'Completed':
        background = Colors.green.withOpacity(0.10);
        foreground = Colors.green[700]!;
        break;

      case 'In Progress':
        background = Colors.blue.withOpacity(0.10);
        foreground = Colors.blue[700]!;
        break;

      case 'Cancelled':
        background = Colors.red.withOpacity(0.10);
        foreground = Colors.red[700]!;
        break;

      case 'Pending':
      default:
        background = Colors.orange.withOpacity(0.12);
        foreground = Colors.orange[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildComponentBadge(String component) {
    final isFocus = component == 'Focus';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isFocus
            ? Colors.deepPurple.withOpacity(0.09)
            : Colors.teal.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        component,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFocus
              ? Colors.deepPurple[700]
              : Colors.teal[700],
        ),
      ),
    );
  }

  Widget _buildMaterialBadge(String material) {
    Color color;

    switch (material) {
      case 'Clear':
        color = Colors.cyan;
        break;

      case 'PC':
        color = Colors.deepPurple;
        break;

      case 'Black':
      default:
        color = Colors.grey[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        material,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION MENU
  // ---------------------------------------------------------------------------

  Widget _buildActionsMenu(
    Map<String, dynamic> order,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'view':
            _showOrderDetails(order);
            break;

          case 'edit':
            _showRawOrderDialog(
              existingOrder: order,
            );
            break;

          case 'pending':
            _updateStatus(order, 'Pending');
            break;

          case 'in_progress':
            _updateStatus(order, 'In Progress');
            break;

          case 'completed':
            _updateStatus(order, 'Completed');
            break;

          case 'cancelled':
            _updateStatus(order, 'Cancelled');
            break;

          case 'delete':
            _deleteRawOrder(order);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: 'view',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_outlined),
              title: Text('View Details'),
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'pending',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.pending_outlined,
                color: Colors.orange,
              ),
              title: Text('Set Pending'),
            ),
          ),
          const PopupMenuItem(
            value: 'in_progress',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.sync,
                color: Colors.blue,
              ),
              title: Text('Set In Progress'),
            ),
          ),
          const PopupMenuItem(
            value: 'completed',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
              title: Text('Set Completed'),
            ),
          ),
          const PopupMenuItem(
            value: 'cancelled',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cancel_outlined,
                color: Colors.red,
              ),
              title: Text('Set Cancelled'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty || _selectedStatus != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 60,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              size: 34,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilters
                ? 'No raw orders found'
                : 'No raw orders yet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters
                ? 'Try changing your search or status filter.'
                : 'Create your first raw order to get started.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();

                setState(() {
                  _searchQuery = '';
                  _selectedStatus = 'All';
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}