// raw_process_section.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class RawProcessSection extends StatefulWidget {
  final List products;
  final String companyId;
  final Map order; // must contain orderId or id
  final String orderId;

  const RawProcessSection({
    super.key,
    required this.products,
    required this.companyId,
    required this.order,
    required this.orderId,
  });

  @override
  State<RawProcessSection> createState() => _RawProcessSectionState();
}

class _RawProcessSectionState extends State<RawProcessSection> {
  List<Map<String, dynamic>> sortedProducts = [];
  bool isLoading = true;
  bool isSaving = false;

  // controllers: productId -> material -> controller
  final Map<String, Map<String, TextEditingController>> focusControllers = {};
  final Map<String, Map<String, TextEditingController>> templeControllers = {};

  // cached existing saved rawUsed from order doc (productId -> {focusUsed:..., templeUsed:...})
  final Map<String, dynamic> rawUsedFromOrder = {};

  @override
  void initState() {
    super.initState();
    _sortProductsByCode();
  }

  @override
  void dispose() {
    // dispose controllers
    for (var map in focusControllers.values) {
      for (var c in map.values) c.dispose();
    }
    for (var map in templeControllers.values) {
      for (var c in map.values) c.dispose();
    }
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  // ---------------------------------------------------------------------
  // Load productCode and sort; then init controllers
  // ---------------------------------------------------------------------
  Future<void> _sortProductsByCode() async {
    setState(() => isLoading = true);

    final List<Map<String, dynamic>> temp = [];

    // Build list of futures to fetch product docs in parallel
    final List<Future<void>> fetches = [];

    for (var raw in widget.products) {
      final p = Map<String, dynamic>.from(raw as Map? ?? {});
      final productId = (p['productId'] ?? '').toString();

      final f = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products')
          .doc(productId)
          .get()
          .then((doc) {
        final data = doc.data() ?? {};
        temp.add({
          ...p,
          'productCode': (data['productCode'] ?? '').toString(),
        });
      }).catchError((e) {
        // If fetch fails, still add product with empty productCode so it doesn't vanish
        temp.add({...p, 'productCode': ''});
        debugPrint('product fetch failed for $productId : $e');
      });

      fetches.add(f);
    }

    await Future.wait(fetches);

    temp.sort((a, b) {
      final A = (a['productCode'] ?? '').toString();
      final B = (b['productCode'] ?? '').toString();
      return A.compareTo(B);
    });

    sortedProducts = temp.map((e) => Map<String, dynamic>.from(e)).toList();

    // init controllers with existing saved values (if any)
    await _initControllersAndLoadValues();

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _initControllersAndLoadValues() async {
    // collect all material keys across products (global columns)
    final Set<String> focusMaterials = {};
    final Set<String> templeMaterials = {};

    for (var p in sortedProducts) {
      final f = p['focusBaseMaterialQuantities'];
      final t = p['templeBaseMaterialQuantities'];

      if (f is Map) focusMaterials.addAll(f.keys.map((k) => k?.toString() ?? ''));
      if (t is Map) templeMaterials.addAll(t.keys.map((k) => k?.toString() ?? ''));
    }

    // load saved rawUsed map from order doc (if orderId present)
    rawUsedFromOrder.clear();
    if (widget.orderId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('orders')
            .doc(widget.orderId)
            .get();
        final data = snap.data() ?? {};
        final rawUsed = (data['rawUsed'] is Map)
            ? Map<String, dynamic>.from(data['rawUsed'])
            : <String, dynamic>{};

        rawUsedFromOrder.addAll(rawUsed);
      } catch (e) {
        debugPrint('Failed to load existing rawUsed: $e');
      }
    }

    // create controllers for every product x every global material (so columns are stable)
    for (var p in sortedProducts) {
      final productId = (p['productId'] ?? '').toString();

      focusControllers[productId] = {};
      templeControllers[productId] = {};

      // product-specific saved usage (if any)
      final productUsed = (rawUsedFromOrder[productId] is Map)
          ? Map<String, dynamic>.from(rawUsedFromOrder[productId])
          : <String, dynamic>{};

      final savedFocusUsed = (productUsed['focusUsed'] is Map)
          ? Map<String, dynamic>.from(productUsed['focusUsed'])
          : <String, dynamic>{};

      final savedTempleUsed = (productUsed['templeUsed'] is Map)
          ? Map<String, dynamic>.from(productUsed['templeUsed'])
          : <String, dynamic>{};

      // For each global focus material, create controller (use saved value if present)
      for (var m in focusMaterials) {
        final controller = TextEditingController(
          text: savedFocusUsed.containsKey(m) ? savedFocusUsed[m].toString() : '',
        );
        focusControllers[productId]![m] = controller;
      }

      // For each global temple material, create controller
      for (var m in templeMaterials) {
        final controller = TextEditingController(
          text: savedTempleUsed.containsKey(m) ? savedTempleUsed[m].toString() : '',
        );
        templeControllers[productId]![m] = controller;
      }
    }
  }

  // ---------------------------------------------------------------------
  // PDF generation (use latest saved values if present)
  // ---------------------------------------------------------------------
  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    // Collect materials (global columns)
    final Set<String> focusMaterials = {};
    final Set<String> templeMaterials = {};

    for (var p in sortedProducts) {
      final fm = p['focusBaseMaterialQuantities'];
      final tm = p['templeBaseMaterialQuantities'];
      if (fm is Map) focusMaterials.addAll(fm.keys.map((k) => k.toString()));
      if (tm is Map) templeMaterials.addAll(tm.keys.map((k) => k.toString()));
    }

    final headers = <String>[
      'Model',
      'Total Qty',
      ...focusMaterials.map((m) => 'F $m'),
      ...templeMaterials.map((m) => 'T $m'),
    ];

    final List<List<String>> rows = [];

    final genders = sortedProducts.map((p) => (p['modelGender'] ?? 'Unknown').toString()).toSet().toList();
    for (var gender in genders) {
      rows.add([gender.toUpperCase(), ...List.filled(headers.length - 1, '')]);
      final groupProducts = sortedProducts.where((p) => (p['modelGender'] ?? '').toString() == gender).toList();
      for (var p in groupProducts) {
        final productId = (p['productId'] ?? '').toString();

        // Prefer saved used values (rawUsedFromOrder) for pdf; fallback to base quantities in product spec
        final saved = (rawUsedFromOrder[productId] is Map) ? Map<String, dynamic>.from(rawUsedFromOrder[productId]) : <String, dynamic>{};
        final savedFocus = (saved['focusUsed'] is Map) ? Map<String, dynamic>.from(saved['focusUsed']) : <String, dynamic>{};
        final savedTemple = (saved['templeUsed'] is Map) ? Map<String, dynamic>.from(saved['templeUsed']) : <String, dynamic>{};

        final focusMap = (p['focusBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['focusBaseMaterialQuantities']) : <String, dynamic>{};
        final templeMap = (p['templeBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['templeBaseMaterialQuantities']) : <String, dynamic>{};

        // Total should reflect actual used if available, else base spec totals
        final totalFocus = focusMaterials.fold<int>(0, (acc, m) {
          if (savedFocus.containsKey(m)) return acc + _toInt(savedFocus[m]);
          return acc + _toInt(focusMap[m]);
        });
        final totalTemple = templeMaterials.fold<int>(0, (acc, m) {
          if (savedTemple.containsKey(m)) return acc + _toInt(savedTemple[m]);
          return acc + _toInt(templeMap[m]);
        });

        final totalQty = totalFocus + totalTemple;

        rows.add([
          (p['productName'] ?? '-').toString(),
          totalQty.toString(),
          ...focusMaterials.map((m) => _toInt(savedFocus.containsKey(m) ? savedFocus[m] : focusMap[m]).toString()),
          ...templeMaterials.map((m) => _toInt(savedTemple.containsKey(m) ? savedTemple[m] : templeMap[m]).toString()),
        ]);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Text('Raw Process Sheet', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Customer Name: ${widget.order['customerName'] ?? '-'}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Order Number: ${widget.order['orderNumber'] ?? '-'}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFF000000)),
          )
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    // optionally save to temp and share
    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/raw_process_${widget.order['orderNumber'] ?? DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
    } catch (e) {
      debugPrint('Failed to write pdf file to temp: $e');
    }

    await Printing.sharePdf(bytes: pdfBytes, filename: 'raw_process_${widget.order['orderNumber'] ?? DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    // collect dynamic materials for headers and for the input table (global columns)
    final Set<String> focusMaterials = {};
    final Set<String> templeMaterials = {};

    for (var p in sortedProducts) {
      final fm = p['focusBaseMaterialQuantities'];
      final tm = p['templeBaseMaterialQuantities'];
      if (fm is Map) focusMaterials.addAll(fm.keys.map((k) => k.toString()));
      if (tm is Map) templeMaterials.addAll(tm.keys.map((k) => k.toString()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Raw Process', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export'),
              ),
            ])
          ],
        ),
        const SizedBox(height: 12),

        // ---------- SUMMARY TABLE (read-only) ----------
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
            columnSpacing: 16,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            headingRowHeight: 40,
            columns: [
              DataColumn(label: Text('Model', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Total Qty', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              ...focusMaterials.map((m) => DataColumn(label: Text('F $m', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
              ...templeMaterials.map((m) => DataColumn(label: Text('T $m', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
            ],
            rows: _buildSummaryRows(sortedProducts, focusMaterials, templeMaterials),
          ),
        ),
        const SizedBox(height: 18),

        // ---------- INPUT TABLE (editable) ----------
        Text('Enter Actual Raw Used', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
            columnSpacing: 12,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 72,
            headingRowHeight: 44,
            columns: [
              DataColumn(label: Text('Model', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Total Qty', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
              ...focusMaterials.map((m) => DataColumn(label: Text('F $m', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
              ...templeMaterials.map((m) => DataColumn(label: Text('T $m', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)))),
            ],
            rows: _buildInputRows(sortedProducts, focusMaterials, templeMaterials),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: ElevatedButton.icon(
            onPressed: () async {
              await _executeFullProcess(widget.orderId);
            },
            icon: const Icon(Icons.settings_suggest),
            label: const Text(
              'Execute Raw Process',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ),

        const SizedBox(height: 20),

      ],
    );
  }

  // ---------------------------------------------------------------------
  // Build read-only summary rows
  // ---------------------------------------------------------------------
  List<DataRow> _buildSummaryRows(List<Map<String, dynamic>> products, Set<String> focus, Set<String> temple) {
    final List<DataRow> rows = [];

    final genders = products.map((p) => (p['modelGender'] ?? 'Unknown').toString()).toSet().toList();
    for (var gender in genders) {
      // gender header row
      rows.add(DataRow(
        color: MaterialStateProperty.all(Colors.blue.shade50),
        cells: [
          DataCell(Center(child: Text(gender.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)))),
          ...List.generate(1 + focus.length + temple.length, (_) => const DataCell(Text(''))),
        ],
      ));

      final groupProducts = products.where((p) => (p['modelGender'] ?? '').toString() == gender).toList();
      for (var p in groupProducts) {
        final focusMap = (p['focusBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['focusBaseMaterialQuantities']) : {};
        final templeMap = (p['templeBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['templeBaseMaterialQuantities']) : {};

        final int totalFocus = focus.fold<int>(0, (a, m) => a + _toInt(focusMap[m]));
        final int totalTemple = temple.fold<int>(0, (a, m) => a + _toInt(templeMap[m]));
        final int totalQty = totalFocus + totalTemple;

        final List<DataCell> cells = [
          DataCell(Text((p['productName'] ?? '-').toString())),
          DataCell(Text(totalQty.toString())),
        ];

        for (var m in focus) {
          cells.add(DataCell(Text('${_toInt(focusMap[m])}')));
        }
        for (var m in temple) {
          cells.add(DataCell(Text('${_toInt(templeMap[m])}')));
        }

        rows.add(DataRow(cells: cells));
      }
    }

    return rows;
  }

  // ---------------------------------------------------------------------
  // Build editable input rows (with per-row Save button)
  // ---------------------------------------------------------------------
  List<DataRow> _buildInputRows(List<Map<String, dynamic>> products, Set<String> focus, Set<String> temple) {
    final List<DataRow> rows = [];

    final genders = products.map((p) => (p['modelGender'] ?? 'Unknown').toString()).toSet().toList();
    for (var gender in genders) {
      // gender header row
      rows.add(DataRow(
        color: MaterialStateProperty.all(Colors.blue.shade50),
        cells: [
          DataCell(Center(child: Text(gender.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)))),
          ...List.generate(1 + focus.length + temple.length, (_) => const DataCell(Text(''))), // extra for actions
        ],
      ));

      final groupProducts = products.where((p) => (p['modelGender'] ?? '').toString() == gender).toList();
      for (var p in groupProducts) {
        final productId = (p['productId'] ?? '').toString();
        final focusMap = (p['focusBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['focusBaseMaterialQuantities']) : {};
        final templeMap = (p['templeBaseMaterialQuantities'] is Map) ? Map<String, dynamic>.from(p['templeBaseMaterialQuantities']) : {};
        final int totalFocus = focusMap.values.fold<int>(0, (a, b) => a + _toInt(b));
        final int totalTemple = templeMap.values.fold<int>(0, (a, b) => a + _toInt(b));
        final int totalQty = totalFocus + totalTemple;

        // model cell and total qty
        final List<DataCell> cells = [
          DataCell(Text((p['productName'] ?? '-').toString())),
          DataCell(Text(totalQty.toString())),
        ];

        // focus input cells (use controllers that were created in init)
        for (var m in focus) {
          final ctrl = focusControllers[productId]?[m];
          cells.add(
            DataCell(
              SizedBox(
                // width: 62,
                height: 40,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                ),
              ),
            ),
          );
        }

        // temple input cells
        for (var m in temple) {
          final ctrl = templeControllers[productId]?[m];
          cells.add(
            DataCell(
              SizedBox(
                // width: 72,
                height: 40,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                ),
              ),
            ),
          );
        }
        rows.add(DataRow(cells: cells));
      }
    }
    return rows;
  }

  Future<void> _executeFullProcess(String orderId) async {
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order ID missing. Cannot process.")),
      );
      return;
    }

    setState(() => isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    final staffId = user?.uid ?? 'unknown';

    final Map<String, dynamic> allRawUsed = {};

    for (var p in sortedProducts) {
      final productId = (p['productId'] ?? '').toString();

      final focusMap = focusControllers[productId] ?? {};
      final templeMap = templeControllers[productId] ?? {};

      final Map<String, int> focusUsed = {};
      final Map<String, int> templeUsed = {};

      // read all focus input values
      for (var entry in focusMap.entries) {
        focusUsed[entry.key] = int.tryParse(entry.value.text) ?? 0;
      }

      // read all temple input values
      for (var entry in templeMap.entries) {
        templeUsed[entry.key] = int.tryParse(entry.value.text) ?? 0;
      }

      allRawUsed[productId] = {
        'focusUsed': focusUsed,
        'templeUsed': templeUsed,
        'timestamp': FieldValue.serverTimestamp(),
        'staffId': staffId,
      };
    }

    final orderRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(orderId);

    try {
      await orderRef.set(
        {'rawUsed': allRawUsed},
        SetOptions(merge: true),
      );

      // Update local cache
      rawUsedFromOrder.clear();
      rawUsedFromOrder.addAll(allRawUsed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Raw Process Executed & Saved Successfully")),
        );
      }
    } catch (e) {
      debugPrint("Failed to execute raw process: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to execute process")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

}
