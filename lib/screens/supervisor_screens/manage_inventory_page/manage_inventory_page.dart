import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageInventoryPage extends StatefulWidget {
  const ManageInventoryPage({super.key});

  @override
  State<ManageInventoryPage> createState() => _ManageInventoryPageState();
}

class _ManageInventoryPageState extends State<ManageInventoryPage> {
  String? _companyId;

  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _products = [];

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortOption = 'name';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');

    if (!mounted) return;

    if (companyId == null || companyId.isEmpty) {
      setState(() {
        _companyId = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _companyId = companyId;
    });

    await _loadInventory();
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products');
  }

  // ---------------------------------------------------------------------------
  // LOAD INVENTORY
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

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final companyId = _companyId;

      if (companyId == null || companyId.isEmpty) {
        throw Exception('Company ID not found');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('products')
          .get();

      final products = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          'name': data['displayName']?.toString() ?? 'Unnamed Product',
          'category': data['category']?.toString() ?? 'Uncategorized',

          // Supports both Firestore numbers and strings.
          'stock': _toInt(data['stock']),
          'minimumStock': _toInt(data['minimumStock']),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to loadInventory: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inventory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SORTING
  // ---------------------------------------------------------------------------

  void _sortProducts(List<Map<String, dynamic>> products) {
    switch (_sortOption) {
      case 'low_stock':
        products.sort(
          (a, b) {
            final aStock = (a['stock'] as num?)?.toInt() ?? 0;
            final bStock = (b['stock'] as num?)?.toInt() ?? 0;

            return aStock.compareTo(bStock);
          },
        );
        break;

      case 'high_stock':
        products.sort(
          (a, b) {
            final aStock = (a['stock'] as num?)?.toInt() ?? 0;
            final bStock = (b['stock'] as num?)?.toInt() ?? 0;

            return bStock.compareTo(aStock);
          },
        );
        break;

      case 'name':
      default:
        products.sort(
          (a, b) {
            return a['name']
                .toString()
                .toLowerCase()
                .compareTo(
                  b['name'].toString().toLowerCase(),
                );
          },
        );
    }
  }

  // ---------------------------------------------------------------------------
  // FILTERED PRODUCTS
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _products.where((product) {
      final name = product['name'].toString().toLowerCase();
      final category = product['category'].toString();

      final matchesSearch =
          query.isEmpty || name.contains(query);

      final matchesCategory =
          _selectedCategory == 'All' ||
          category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    _sortProducts(filtered);

    return filtered;
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  List<String> get _categories {
    final categories = _products
        .map(
          (product) => product['category'].toString(),
        )
        .where(
          (category) => category.isNotEmpty,
        )
        .toSet()
        .toList();

    categories.sort();

    return [
      'All',
      ...categories,
    ];
  }

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------

  int get _totalProducts {
    return _products.length;
  }

  int get _totalStock {
    return _products.fold<int>(
      0,
      (total, product) {
        return total +
            ((product['stock'] as num?)?.toInt() ?? 0);
      },
    );
  }

  int get _lowStockCount {
    return _products.where((product) {
      final stock =
          (product['stock'] as num?)?.toInt() ?? 0;

      final minimumStock =
          (product['minimumStock'] as num?)?.toInt() ?? 0;

      return stock > 0 && stock <= minimumStock;
    }).length;
  }

  int get _outOfStockCount {
    return _products.where((product) {
      final stock =
          (product['stock'] as num?)?.toInt() ?? 0;

      return stock <= 0;
    }).length;
  }

  // ---------------------------------------------------------------------------
  // STOCK STATUS
  // ---------------------------------------------------------------------------

  bool _isStockAlert(Map<String, dynamic> product) {
    final stock =
        (product['stock'] as num?)?.toInt() ?? 0;

    final minimumStock =
        (product['minimumStock'] as num?)?.toInt() ?? 0;

    return stock <= minimumStock;
  }

  String _stockStatus(Map<String, dynamic> product) {
    final stock =
        (product['stock'] as num?)?.toInt() ?? 0;

    final minimumStock =
        (product['minimumStock'] as num?)?.toInt() ?? 0;

    if (stock <= 0) {
      return 'OUT OF STOCK';
    }

    if (stock <= minimumStock) {
      return 'LOW STOCK';
    }

    return 'HEALTHY';
  }

  Color _stockBackgroundColor(
    Map<String, dynamic> product,
  ) {
    final stock =
        (product['stock'] as num?)?.toInt() ?? 0;

    if (stock <= 0) {
      return Colors.red.shade100;
    }

    if (_isStockAlert(product)) {
      return Colors.red.shade50;
    }

    return Colors.green.shade50;
  }

  Color _stockTextColor(
    Map<String, dynamic> product,
  ) {
    if (_isStockAlert(product)) {
      return Colors.red.shade700;
    }

    return Colors.green.shade700;
  }

  // ---------------------------------------------------------------------------
  // EDIT PRODUCT INVENTORY
  // ---------------------------------------------------------------------------

  Future<void> _editStock(
    Map<String, dynamic> product,
  ) async {
    final productId = product['id'] as String;

    final productName =
        product['name'].toString();

    final currentStock =
        (product['stock'] as num?)?.toInt() ?? 0;

    final currentMinimumStock =
        (product['minimumStock'] as num?)?.toInt() ?? 0;

    final stockController = TextEditingController(
      text: currentStock.toString(),
    );

    final minimumStockController = TextEditingController(
      text: currentMinimumStock.toString(),
    );

    int? newStock;
    int? newMinimumStock;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final enteredStock =
                int.tryParse(
              stockController.text.trim(),
            );

            final enteredMinimum =
                int.tryParse(
              minimumStockController.text.trim(),
            );

            final previewStock =
                enteredStock ?? currentStock;

            final previewMinimum =
                enteredMinimum ??
                    currentMinimumStock;

            final isAlert =
                previewStock <= previewMinimum;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit Inventory',
                      style: GoogleFonts.inter(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style:
                            GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Update stock and minimum required quantity.',
                        style:
                            GoogleFonts.inter(
                          color:
                              Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // CURRENT STOCK
                      TextField(
                        controller:
                            stockController,
                        autofocus: true,
                        keyboardType:
                            TextInputType.number,
                        onChanged: (_) {
                          setDialogState(
                            () {},
                          );
                        },
                        decoration:
                            InputDecoration(
                          labelText:
                              'Current Stock',
                          prefixIcon:
                              const Icon(
                            Icons
                                .inventory_2_outlined,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // MINIMUM REQUIRED STOCK
                      TextField(
                        controller:
                            minimumStockController,
                        keyboardType:
                            TextInputType.number,
                        onChanged: (_) {
                          setDialogState(
                            () {},
                          );
                        },
                        decoration:
                            InputDecoration(
                          labelText:
                              'Minimum Required Stock',
                          prefixIcon:
                              const Icon(
                            Icons
                                .warning_amber_rounded,
                          ),
                          helperText:
                              'Alert appears when stock is at or below this value.',
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PREVIEW
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color: isAlert
                              ? Colors.red.shade50
                              : Colors.green
                                  .shade50,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          border:
                              Border.all(
                            color: isAlert
                                ? Colors.red
                                    .shade200
                                : Colors.green
                                    .shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(
                                  'New Stock',
                                  style:
                                      GoogleFonts
                                          .inter(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                                Text(
                                  previewStock
                                      .toString(),
                                  style:
                                      GoogleFonts
                                          .inter(
                                    fontSize:
                                        20,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color: isAlert
                                        ? Colors
                                            .red
                                            .shade700
                                        : Colors
                                            .green
                                            .shade700,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(
                                  'Minimum Required',
                                  style:
                                      GoogleFonts
                                          .inter(
                                    color: Colors
                                        .grey[700],
                                  ),
                                ),
                                Text(
                                  previewMinimum
                                      .toString(),
                                  style:
                                      GoogleFonts
                                          .inter(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            const Divider(),

                            const SizedBox(
                              height: 8,
                            ),

                            Row(
                              children: [
                                Icon(
                                  isAlert
                                      ? Icons
                                          .warning_amber_rounded
                                      : Icons
                                          .check_circle_outline,
                                  color: isAlert
                                      ? Colors.red
                                          .shade700
                                      : Colors
                                          .green
                                          .shade700,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child: Text(
                                    previewStock <= 0
                                        ? 'OUT OF STOCK'
                                        : isAlert
                                            ? 'LOW STOCK ALERT'
                                            : 'STOCK LEVEL IS HEALTHY',
                                    style:
                                        GoogleFonts
                                            .inter(
                                      color: isAlert
                                          ? Colors
                                              .red
                                              .shade700
                                          : Colors
                                              .green
                                              .shade700,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed:
                      enteredStock == null ||
                              enteredStock < 0 ||
                              enteredMinimum ==
                                  null ||
                              enteredMinimum < 0
                          ? null
                          : () {
                              newStock =
                                  enteredStock;

                              newMinimumStock =
                                  enteredMinimum;

                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blueAccent,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    stockController.dispose();
    minimumStockController.dispose();

    if (newStock == null ||
        newMinimumStock == null) {
      return;
    }

    if (newStock == currentStock &&
        newMinimumStock ==
            currentMinimumStock) {
      return;
    }

    await _updateInventory(
      productId: productId,
      productName: productName,
      newStock: newStock!,
      newMinimumStock:
          newMinimumStock!,
      previousStock: currentStock,
      previousMinimumStock:
          currentMinimumStock,
    );
  }

  // ---------------------------------------------------------------------------
  // UPDATE INVENTORY
  // ---------------------------------------------------------------------------

  Future<void> _updateInventory({
    required String productId,
    required String productName,
    required int newStock,
    required int newMinimumStock,
    required int previousStock,
    required int previousMinimumStock,
  }) async {
    if (_companyId == null ||
        _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final productRef =
        _productsCollection.doc(productId);

    try {
      await FirebaseFirestore.instance
          .runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(
            productRef,
          );

          if (!snapshot.exists) {
            throw Exception(
              'Product no longer exists.',
            );
          }

          final data =
              snapshot.data();

          final firestoreStock =
              (data?['stock'] as num?)
                      ?.toInt() ??
                  0;

          if (firestoreStock < 0) {
            throw Exception(
              'Invalid stock value in Firestore.',
            );
          }

          transaction.update(
            productRef,
            {
              'stock': newStock,

              'minimumStock':
                  newMinimumStock,

              'inventoryUpdatedAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return;

      setState(() {
        final index =
            _products.indexWhere(
          (product) =>
              product['id'] ==
              productId,
        );

        if (index != -1) {
          _products[index]['stock'] =
              newStock;

          _products[index]
                  ['minimumStock'] =
              newMinimumStock;
        }
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.green,
          content: Text(
            '$productName updated successfully.\n'
            'Stock: $previousStock → $newStock\n'
            'Minimum: $previousMinimumStock → '
            '$newMinimumStock',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor:
              Colors.red,
          content: Text(
            'Failed to update inventory: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PRODUCT DETAILS
  // ---------------------------------------------------------------------------

  void _showProductDetails(
    Map<String, dynamic> product,
  ) {
    final stock =
        (product['stock'] as num?)
                ?.toInt() ??
            0;

    final minimumStock =
        (product['minimumStock']
                    as num?)
                ?.toInt() ??
            0;

    final isAlert =
        stock <= minimumStock;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            8,
            24,
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                product['name'].toString(),
                style:
                    GoogleFonts.inter(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                product['category']
                    .toString(),
                style:
                    GoogleFonts.inter(
                  color:
                      Colors.grey[600],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color: isAlert
                      ? Colors.red
                          .shade50
                      : Colors.green
                          .shade50,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current Stock',
                      style:
                          GoogleFonts.inter(
                        color: isAlert
                            ? Colors.red
                                .shade700
                            : Colors.green
                                .shade700,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      '$stock',
                      style:
                          GoogleFonts.inter(
                        fontSize: 38,
                        fontWeight:
                            FontWeight.w800,
                        color: isAlert
                            ? Colors.red
                                .shade700
                            : Colors.green
                                .shade700,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      _stockStatus(
                        product,
                      ),
                      style:
                          GoogleFonts.inter(
                        color: isAlert
                            ? Colors.red
                                .shade700
                            : Colors.green
                                .shade700,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 12,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        Text(
                          'Minimum Required',
                          style:
                              GoogleFonts
                                  .inter(
                            color: Colors
                                .grey[700],
                          ),
                        ),
                        Text(
                          '$minimumStock',
                          style:
                              GoogleFonts
                                  .inter(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),

                    if (isAlert) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(
                          10,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.red
                              .shade100,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .warning_amber_rounded,
                              size: 20,
                              color: Colors
                                  .red
                                  .shade700,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                stock <= 0
                                    ? 'This product is out of stock.'
                                    : 'Stock has reached the minimum required quantity.',
                                style:
                                    GoogleFonts
                                        .inter(
                                  color: Colors
                                      .red
                                      .shade700,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    _editStock(
                      product,
                    );
                  },
                  icon: const Icon(
                    Icons.edit_rounded,
                  ),
                  label: const Text(
                    'Edit Inventory',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blueAccent,
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_companyId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No company context found. Please log in again.',
          ),
        ),
      );
    }

    final products =
        _filteredProducts;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,
        surfaceTintColor:
            Colors.white,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Inventory',
              style:
                  GoogleFonts.inter(
                color:
                    const Color(
                  0xFF1F2937,
                ),
                fontWeight:
                    FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              'View and update product stock',
              style:
                  GoogleFonts.inter(
                color:
                    Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isSaving
                    ? null
                    : _loadInventory,
            icon: const Icon(
              Icons.refresh_rounded,
              color:
                  Colors.blueAccent,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh:
            _loadInventory,

        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            // Important:
            // 850 prevents the filter dropdowns from becoming
            // too narrow on tablets/small browser windows.
            final isMobile =
                constraints.maxWidth <
                    850;

            return ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  EdgeInsets.all(
                isMobile
                    ? 12
                    : 24,
              ),

              children: [
                _buildSummaryCards(
                  isMobile,
                ),

                const SizedBox(
                  height: 20,
                ),

                _buildFilters(
                  isMobile,
                ),

                const SizedBox(
                  height: 16,
                ),

                if (_isSaving)
                  const LinearProgressIndicator(
                    minHeight: 2,
                  ),

                _buildInventoryContent(
                  products,
                  isMobile,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARDS
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(
    bool isMobile,
  ) {
    final cards = [
      _SummaryCardData(
        title: 'Products',
        value:
            '$_totalProducts',
        icon:
            Icons.inventory_2_rounded,
        background:
            Colors.blue.shade50,
        foreground:
            Colors.blue.shade700,
      ),
      _SummaryCardData(
        title: 'Total Stock',
        value:
            '$_totalStock',
        icon:
            Icons.warehouse_rounded,
        background:
            Colors.green.shade50,
        foreground:
            Colors.green.shade700,
      ),
      _SummaryCardData(
        title: 'Low Stock',
        value:
            '$_lowStockCount',
        icon:
            Icons.warning_amber_rounded,
        background:
            Colors.red.shade50,
        foreground:
            Colors.red.shade700,
      ),
      _SummaryCardData(
        title: 'Out of Stock',
        value:
            '$_outOfStockCount',
        icon:
            Icons.remove_circle_outline_rounded,
        background:
            Colors.red.shade100,
        foreground:
            Colors.red.shade800,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child:
                    _buildSummaryCard(
                  card,
                ),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: cards
          .map(
            (card) => Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 12,
                ),
                child:
                    _buildSummaryCard(
                  card,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSummaryCard(
    _SummaryCardData card,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .04,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color:
                  card.background,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              card.icon,
              color:
                  card.foreground,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                card.title,
                style:
                    GoogleFonts.inter(
                  color:
                      Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                card.value,
                style:
                    GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters(
    bool isMobile,
  ) {
    final categoryDropdown =
        DropdownButtonFormField<
            String>(
      isExpanded: true,

      value: _categories
              .contains(
        _selectedCategory,
      )
          ? _selectedCategory
          : 'All',

      decoration:
          InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(
          Icons.category_outlined,
        ),
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),

      items: _categories
          .map(
            (category) =>
                DropdownMenuItem<String>(
              value: category,
              child: Text(
                category,
                overflow:
                    TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),

      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory =
                value;
          });
        }
      },
    );

    final sortDropdown =
        DropdownButtonFormField<
            String>(
      isExpanded: true,

      value: _sortOption,

      decoration:
          InputDecoration(
        labelText: 'Sort',
        prefixIcon: const Icon(
          Icons.sort_rounded,
        ),
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),

      items: const [
        DropdownMenuItem(
          value: 'name',
          child: Text(
            'Name',
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: 'low_stock',
          child: Text(
            'Low → High Stock',
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: 'high_stock',
          child: Text(
            'High → Low Stock',
            overflow:
                TextOverflow.ellipsis,
          ),
        ),
      ],

      onChanged: (value) {
        if (value != null) {
          setState(() {
            _sortOption =
                value;
          });
        }
      },
    );

    final search =
        TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery =
              value;
        });
      },

      decoration:
          InputDecoration(
        hintText:
            'Search products...',
        prefixIcon:
            const Icon(
          Icons.search_rounded,
        ),
        filled: true,
        fillColor:
            Colors.white,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          search,

          const SizedBox(
            height: 10,
          ),

          categoryDropdown,

          const SizedBox(
            height: 10,
          ),

          sortDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: search,
        ),

        const SizedBox(
          width: 12,
        ),

        SizedBox(
          width: 210,
          child:
              categoryDropdown,
        ),

        const SizedBox(
          width: 12,
        ),

        SizedBox(
          width: 210,
          child: sortDropdown,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildInventoryContent(
    List<Map<String, dynamic>>
        products,
    bool isMobile,
  ) {
    if (products.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.all(
          40,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons
                  .inventory_2_outlined,
              size: 52,
              color:
                  Colors.grey[400],
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              _products.isEmpty
                  ? 'No inventory items found.'
                  : 'No products match your search.',
              style:
                  GoogleFonts.inter(
                color:
                    Colors.grey[600],
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: products
            .map(
              (product) =>
                  Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 10,
                ),
                child:
                    _buildMobileProductCard(
                  product,
                ),
              ),
            )
            .toList(),
      );
    }

    return _buildDesktopTable(
      products,
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP TABLE
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable(
    List<Map<String, dynamic>>
        products,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              .04,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: DataTable(
            headingRowHeight:
                54,
            dataRowMinHeight:
                72,
            dataRowMaxHeight:
                90,

            headingRowColor:
                WidgetStatePropertyAll(
              Colors.grey.shade50,
            ),

            columns: const [
              DataColumn(
                label:
                    Text('Product'),
              ),
              DataColumn(
                label:
                    Text('Category'),
              ),
              DataColumn(
                label:
                    Text('Stock'),
              ),
              DataColumn(
                label:
                    Text('Minimum'),
              ),
              DataColumn(
                label:
                    Text('Status'),
              ),
              DataColumn(
                label:
                    Text('Action'),
              ),
            ],

            rows: products
                .map(
                  (product) {
                    final stock =
                        (product['stock']
                                    as num?)
                                ?.toInt() ??
                            0;

                    final minimumStock =
                        (product[
                                    'minimumStock']
                                as num?)
                            ?.toInt() ??
                        0;

                    return DataRow(
                      cells: [
                        // PRODUCT
                        DataCell(
                          InkWell(
                            onTap: () =>
                                _showProductDetails(
                              product,
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                _productIcon(
                                  product,
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(
                                    maxWidth:
                                        240,
                                  ),
                                  child:
                                      Text(
                                    product[
                                            'name']
                                        .toString(),
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        GoogleFonts
                                            .inter(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // CATEGORY
                        DataCell(
                          Text(
                            product[
                                    'category']
                                .toString(),
                            style:
                                GoogleFonts
                                    .inter(),
                          ),
                        ),

                        // STOCK
                        DataCell(
                          Text(
                            '$stock',
                            style:
                                GoogleFonts
                                    .inter(
                              fontWeight:
                                  FontWeight
                                      .w800,
                              fontSize: 16,
                              color:
                                  _stockTextColor(
                                product,
                              ),
                            ),
                          ),
                        ),

                        // MINIMUM
                        DataCell(
                          Text(
                            '$minimumStock',
                            style:
                                GoogleFonts
                                    .inter(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),

                        // STATUS
                        DataCell(
                          _stockBadge(
                            product,
                          ),
                        ),

                        // ACTION
                        DataCell(
                          IconButton(
                            tooltip:
                                'Edit inventory',
                            onPressed:
                                _isSaving
                                    ? null
                                    : () =>
                                        _editStock(
                                      product,
                                    ),
                            icon:
                                const Icon(
                              Icons
                                  .edit_rounded,
                            ),
                            color:
                                Colors
                                    .blueAccent,
                          ),
                        ),
                      ],
                    );
                  },
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE CARD
  // ---------------------------------------------------------------------------

  Widget _buildMobileProductCard(
    Map<String, dynamic> product,
  ) {
    final stock =
        (product['stock'] as num?)
                ?.toInt() ??
            0;

    final minimumStock =
        (product['minimumStock']
                    as num?)
                ?.toInt() ??
            0;

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      onTap: () =>
          _showProductDetails(
        product,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                .04,
              ),
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _productIcon(
              product,
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    product['name']
                        .toString(),
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        GoogleFonts.inter(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    product[
                            'category']
                        .toString(),
                    style:
                        GoogleFonts.inter(
                      color:
                          Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _stockBadge(
                        product,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.grey
                                  .shade100,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                        ),
                        child: Text(
                          'Min: $minimumStock',
                          style:
                              GoogleFonts
                                  .inter(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w600,
                            color:
                                Colors.grey
                                    .shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            IconButton(
              onPressed:
                  _isSaving
                      ? null
                      : () =>
                          _editStock(
                        product,
                      ),
              icon: const Icon(
                Icons.edit_rounded,
              ),
              color:
                  Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCT ICON
  // ---------------------------------------------------------------------------

  Widget _productIcon(
    Map<String, dynamic> product,
  ) {
    return Container(
      width: 44,
      height: 44,
      decoration:
          BoxDecoration(
        color:
            _stockBackgroundColor(
          product,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Icon(
        _isStockAlert(product)
            ? Icons
                .warning_amber_rounded
            : Icons
                .inventory_2_rounded,
        color:
            _stockTextColor(
          product,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK BADGE
  // ---------------------------------------------------------------------------

  Widget _stockBadge(
    Map<String, dynamic> product,
  ) {
    final stock =
        (product['stock'] as num?)
                ?.toInt() ??
            0;

    final isAlert =
        _isStockAlert(product);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            _stockBackgroundColor(
          product,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color: isAlert
              ? Colors.red.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            isAlert
                ? Icons
                    .warning_amber_rounded
                : Icons
                    .check_circle_outline,
            size: 16,
            color:
                _stockTextColor(
              product,
            ),
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            stock <= 0
                ? 'OUT OF STOCK'
                : isAlert
                    ? 'LOW STOCK'
                    : '$stock units',
            style:
                GoogleFonts.inter(
              color:
                  _stockTextColor(
                product,
              ),
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SUMMARY CARD MODEL
// -----------------------------------------------------------------------------

class _SummaryCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.background,
    required this.foreground,
  });
}