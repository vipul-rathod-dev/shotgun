import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/screens/staff_screens/staff_page.dart';

// Focus library imports
import 'color_goods_pdf_generator.dart';
import 'focus_color_details_page/controllers/focus_table_controller.dart';
import 'focus_color_details_page/models/focus_row_state.dart';
import 'focus_color_details_page/models/product_cell_state.dart';
import 'focus_color_details_page/widgets/focus_table.dart';

// Temple library imports
import 'temple_color_details_page/controllers/temple_table_controller.dart';
import 'temple_color_details_page/models/temple_row_state.dart';
import 'temple_color_details_page/models/temple_product_cell_state.dart';
import 'temple_color_details_page/widgets/temple_table.dart';

class ColorGoodsTablePage extends StatefulWidget {
  final String companyId;
  final String orderId;
  final List products;

  const ColorGoodsTablePage({
    super.key,
    required this.companyId,
    required this.orderId,
    required this.products,
  });

  @override
  State<ColorGoodsTablePage> createState() => _ColorGoodsTablePageState();
}

class _ColorGoodsTablePageState extends State<ColorGoodsTablePage> {
  final FocusTableController _focusController = FocusTableController();
  final TempleTableController _templeController = TempleTableController();

  bool _focusBuilt = false;
  bool _focusHydrated = false;
  bool _templeBuilt = false;
  bool _templeHydrated = false;
  List<String> _productNames = [];
  List<String> _genders = [];
  
  // ---------------------------
  // Helpers
  // ---------------------------

  num _safeNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _productName(Map<String, dynamic> p) {
    final n = (p['productName'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return (p['modelGender'] ?? 'Product').toString();
  }

  // ---------------------------
  // Build Focus Controller ONCE
  // ---------------------------
  void _buildFocusController({
    required List<String> colors,
    required List<String> productNames,
    required Map<String, Map<String, num>> matrix,
  }) {

    // _focusController.rows.clear();

    for (final color in colors) {
      final productCells = <String, ProductCellState>{};

      for (final pn in productNames) {
        final qty = matrix[color]?[pn] ?? 0;
        productCells[pn] = ProductCellState(qty: qty);
      }

      _focusController.rows[color] =
          FocusRowState(color: color, products: productCells);
    }

    _focusController.initProducts(productNames);
    _focusController.recalcGrand();
  }

  void _hydrateFocusFromFirestore(Map<String, dynamic> focusSaved) {
    for (final entry in focusSaved.entries) {
      final color = entry.key;
      final rowData = entry.value;

      final row = _focusController.rows[color];
      if (row == null) continue;

      final products = rowData['products'] as Map<String, dynamic>? ?? {};

      for (final pEntry in products.entries) {
        final productName = pEntry.key;
        final cellData = pEntry.value as Map<String, dynamic>;

        final cell = row.products[productName];
        if (cell == null) continue;

        cell.hydrate(
          received: cellData['received'] ?? 0,
          repairing: cellData['repairing'] ?? 0,
        );
      }

      row.recalc();
    }

    _focusController.recalcGrand();
  }

  // ---------------------------
  // Build Temple Controller ONCE
  // ---------------------------
  void _buildTempleController({
    required List<String> colors,
    required List<String> genders,
    required Map<String, Map<String, num>> matrix,
  }) {
    _templeController.rows.clear();

    for (final color in colors) {
      final cells = <String, TempleProductCellState>{};

      for (final g in genders) {
        final qty = matrix[color]?[g] ?? 0;
        cells[g] = TempleProductCellState(qty: qty);
      }

      _templeController.rows[color] =
          TempleRowState(color: color, genders: cells);
    }

    _templeController.initGenders(genders);
    _templeController.recalcGrand();
  }

  void _hydrateTempleFromFirestore(
    Map<String, dynamic> templeSaved,
  ) {
    for (final entry in templeSaved.entries) {
      final color = entry.key;
      final rowData = entry.value as Map<String, dynamic>;

      final row = _templeController.rows[color];
      if (row == null) continue;

      final gendersData =
          (rowData['genders'] ?? {}) as Map<String, dynamic>;

      for (final gEntry in gendersData.entries) {
        final gender = gEntry.key;
        final cellData = gEntry.value as Map<String, dynamic>;

        final cell = row.genders[gender];
        if (cell == null) continue;

        cell.hydrate(
          recR: cellData['receivedR'] ?? 0,
          recL: cellData['receivedL'] ?? 0,
          repR: cellData['repairingR'] ?? 0,
          repL: cellData['repairingL'] ?? 0,
        );
      }

      row.recalc();
    }

    _templeController.recalcGrand();
  }

  // ---------------------------
  // Firestore Save
  // ---------------------------
  Future<void> _saveFocusToFirestore() async {
    final ref = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId);

    final Map<String, dynamic> focusData = {};

    for (final entry in _focusController.rows.entries) {
      final row = entry.value;

      final Map<String, dynamic> productData = {};
      for (final p in row.products.entries) {
        productData[p.key] = {
          'received': num.tryParse(p.value.recCtrl.text) ?? 0,
          'repairing': num.tryParse(p.value.repCtrl.text) ?? 0,
          'pending': p.value.pending.value,
        };
      }

      focusData[row.color] = {
        'products': productData,
        'receivedTotal': row.recTotal.value,
        'repairingTotal': row.repTotal.value,
        'pendingTotal': row.pendingTotal.value,
      };
    }

    await ref.update({
      'colorDetails.focus': focusData,
      'colorDetails.updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Color goods saved')),
      );
    }
  }

  Future<void> _saveTempleToFirestore() async {
    final ref = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId);

    final Map<String, dynamic> templeData = {};

    for (final entry in _templeController.rows.entries) {
      final row = entry.value;

      final Map<String, dynamic> genderData = {};

      for (final g in row.genders.entries) {
        final cell = g.value;

        debugPrint(num.tryParse(cell.recRCtrl.text).toString());

        genderData[g.key] = {
          'receivedR': num.tryParse(cell.recRCtrl.text) ?? 0,
          'receivedL': num.tryParse(cell.recLCtrl.text) ?? 0,
          'repairingR': num.tryParse(cell.repRCtrl.text) ?? 0,
          'repairingL': num.tryParse(cell.repLCtrl.text) ?? 0,
          'pendingR': cell.pendingR.value,
          'pendingL': cell.pendingL.value,
        };
      }

      templeData[row.color] = {
        'genders': genderData,
        'receivedRTotal': row.recRTotal.value,
        'receivedLTotal': row.recLTotal.value,
        'repairingRTotal': row.repRTotal.value,
        'repairingLTotal': row.repLTotal.value,
      };
    }

    await ref.update({
      'colorDetails.temple': templeData,
      'colorDetails.updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temple color goods saved')),
      );
    }
  }

  Future<void> _saveAllColorGoods() async {
    try {
      // 1️⃣ Save focus data
      await _saveFocusToFirestore();

      // 2️⃣ Save temple data (if you have this method)
      await _saveTempleToFirestore();

      await ColorGoodsPdfGenerator.generateAndShare(
        orderNumber: widget.orderId,
        productNames: _productNames,
        genders: _genders,
        focusController: _focusController,
        templeController: _templeController,
      );

      if (!mounted) return;

      // 3️⃣ Navigate to Home (clear back stack)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StaffDashboard()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save color goods: $e'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFocusCustomizations(
    Map<String, dynamic> product,
    Map<String, dynamic> productCustomizations,
  ) {
    final name = _productName(product);
    final gender = product['modelGender'];

    if (productCustomizations[name] is List) {
      return List<Map<String, dynamic>>.from(productCustomizations[name]);
    }

    if (productCustomizations[gender] is List) {
      return List<Map<String, dynamic>>.from(productCustomizations[gender]);
    }

    if (product['customizations'] is List) {
      return List<Map<String, dynamic>>.from(product['customizations']);
    }

    return [];
  }


  // ---------------------------
  // Dispose
  // ---------------------------
  @override
  void dispose() {
    for (final row in _focusController.rows.values) {
      row.dispose();
    }
    for (final row in _templeController.rows.values) {
      row.dispose();
    }
    super.dispose();
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Color Goods'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data()!;
          final boxQty = (data['boxQuantity'] ?? {}) as Map<String, dynamic>;
          final Map<String, dynamic> productCustomizations = (data['productCustomizations'] ?? {}) as Map<String, dynamic>;
          final Map<String, dynamic> colorDetails =
              (data['colorDetails'] ?? {}) as Map<String, dynamic>;

          final Map<String, dynamic> focusSaved =
              (colorDetails['focus'] ?? {}) as Map<String, dynamic>;

          final Map<String, dynamic> templeSaved =
              (colorDetails['temple'] ?? {}) as Map<String, dynamic>;

          // ---------------------------
          // Build focus matrix (simplified & stable)
          // ---------------------------
          final productNames = widget.products.map((p) => _productName(p)).toList();

          final Map<String, Map<String, num>> matrix = {};
          final Set<String> colorsSet = {};

          for (final p in widget.products) {
            final name = _productName(p);
            final qty = _safeNum(p['quantity']);
            final gender = p['modelGender'];
            final box = _safeNum(boxQty[gender]);
            final perModelQty = box == 0 ? qty : qty / box;

            final customs = _getFocusCustomizations(p, productCustomizations);

            for (final c in customs) {
              final focusColor = (c['focusColor'] ?? '').toString().trim();
              if (focusColor.isEmpty) continue;

              final base = (c['focusBaseMaterial'] ?? '').toString().trim();
              final color = base.isEmpty ? focusColor : '$focusColor - $base';

              final focusQty = _safeNum(c['focusQty']) * perModelQty;

              colorsSet.add(color);
              matrix.putIfAbsent(color, () => {});
              matrix[color]![name] =
                  (matrix[color]![name] ?? 0) + focusQty;
            }
          }

          final colors = colorsSet.toList();

          if (!_focusBuilt) {
            _buildFocusController(
              colors: colors,
              productNames: productNames,
              matrix: matrix,
            );
            _focusBuilt = true;
          }

          if (!_focusHydrated) {
            _hydrateFocusFromFirestore(focusSaved);
            _focusHydrated = true;
          }

          // ---------------------------
          // Build TEMPLE matrix
          // ---------------------------
          final Map<String, Map<String, num>> templeMatrix = {};
          final Set<String> templeColorsSet = {};
          final Set<String> genderSet = {};

          for (final p in widget.products) {
            final gender = (p['modelGender'] ?? '').toString();
            if (gender.isNotEmpty) genderSet.add(gender);

            final qty = _safeNum(p['quantity']);
            final box = _safeNum(boxQty[gender]);
            final perModelQty = box == 0 ? qty : qty / box;

            final customs = _getFocusCustomizations(p, productCustomizations);

            for (final c in customs) {
              final templeColor = (c['templeColor'] ?? '').toString().trim();
              if (templeColor.isEmpty) continue;

              final base = (c['templeBaseMaterial'] ?? '').toString().trim();
              final color = base.isEmpty ? templeColor : '$templeColor - $base';

              final templeQty = _safeNum(c['templeQty']) * perModelQty;

              templeColorsSet.add(color);
              templeMatrix.putIfAbsent(color, () => {});
              templeMatrix[color]![gender] =
                  (templeMatrix[color]![gender] ?? 0) + templeQty;
            }
          }

          final templeColors = templeColorsSet.toList();
          final genders = genderSet.toList();

          if (!_templeBuilt) {
            _buildTempleController(
              colors: templeColors,
              genders: genders,
              matrix: templeMatrix,
            );
            _templeBuilt = true;
          }

          if (!_templeHydrated) {
            _hydrateTempleFromFirestore(templeSaved);
            _templeHydrated = true;
          }

          _productNames = productNames;
          _genders = genders;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FocusTable(
                  productNames: productNames,
                  colors: colors,
                  matrix: matrix,
                  controller: _focusController,
                ),
                const SizedBox(height: 32),
                TempleTable(
                  genders: genders,
                  colors: templeColors,
                  matrix: templeMatrix,
                  controller: _templeController,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveAllColorGoods,
                  child: Text(
                    'Save & Share Color Details PDF',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
