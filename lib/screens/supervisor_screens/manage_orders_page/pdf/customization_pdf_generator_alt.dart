// pdf/customization_pdf_generator_alt.dart
// Alternate customization PDF generator — modular functions version (Updated Split Pages + Page Numbers)

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CustomizationPdfGeneratorAlt {
  CustomizationPdfGeneratorAlt();

  Future<void> generateAndShareAltPdf(
    Map<String, dynamic> data,
    List<dynamic> products,
  ) async {
    final pdf = pw.Document();

    final productCustomizations = (data['productCustomizations'] ?? {}) as Map<String, dynamic>;
    final boxQtyData = (data['boxQuantity'] ?? {}) as Map<String, dynamic>;

    final orderedProducts = _collectProductsOrderedByGender(products);
    final focusMatrix = _collectFocusData(orderedProducts, productCustomizations, boxQtyData);
    final templeMatrix = _collectTempleData(orderedProducts, productCustomizations, boxQtyData);

    footer(pw.Context context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        );

    // --------------------------
    // PAGE 1 — Focus Colors
    // --------------------------

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        footer: footer,
        build: (context) => [
          _buildHeader(data),
          pw.SizedBox(height: 12),
          pw.Text(
            'FOCUS COLOR SUMMARY',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildFocusTable(focusMatrix, orderedProducts),
          // pw.SizedBox(height: 20),
          // _buildOverallSummary(focusMatrix, templeMatrix),
        ],
      ),
    );

    // --------------------------
    // PAGE 2 — Temple Colors
    // --------------------------

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        footer: footer,
        build: (context) => [
          _buildHeader(data),
          pw.SizedBox(height: 12),
          pw.Text(
            'TEMPLE COLOR SUMMARY',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildTempleTable(templeMatrix),
          pw.SizedBox(height: 20),
          _buildOverallSummary(focusMatrix, templeMatrix),
        ],
      ),
    );

    // Save & share
    final dir = await getTemporaryDirectory();
    final safeOrder = (data['orderNumber'] ?? DateTime.now().millisecondsSinceEpoch)
        .toString()
        .replaceAll(RegExp(r'[^\w\-]'), '_');

    final file = File('${dir.path}/ALT_customizations_$safeOrder.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Alternate Customizations PDF for ${data['orderNumber'] ?? ''}',
    );
  }

  // ---------------------------------------------------------------------------
  // --------------------- REMAINING FUNCTIONS UNCHANGED ------------------------
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _collectProductsOrderedByGender(List<dynamic> products) {
    final List<Map<String, dynamic>> gents = [];
    final List<Map<String, dynamic>> ladies = [];
    final List<Map<String, dynamic>> others = [];

    for (final p in products) {
      try {
        final mp = Map<String, dynamic>.from(p as Map);
        final genderRaw = (mp['modelGender'] ?? '').toString().toLowerCase();
        if (genderRaw.contains('gent') || genderRaw.contains('male')) {
          gents.add(mp);
        } else if (genderRaw.contains('lady') || genderRaw.contains('female')) {ladies.add(mp);}
        else {others.add(mp);}
      } catch (_) {}
    }

    return [...gents, ...ladies, ...others];
  }

  Map<String, dynamic> _collectFocusData(
    List<Map<String, dynamic>> orderedProducts,
    Map<String, dynamic> productCustomizations,
    Map<String, dynamic> boxQtyData,
  ) {
    final productNames = orderedProducts.map((p) => _productDisplayName(p)).toList();
    final Set<String> colorSet = {};
    final Map<String, Map<String, num>> matrix = {};
    final Map<String, num> receivedMap = {};
    final Map<String, num> repairingMap = {};
    final Map<String, num> totalMap = {};

    for (final product in orderedProducts) {
      final String productName = _productDisplayName(product);
      final num qty = _safeNum(product['quantity']);
      final gender = (product['modelGender'] ?? '').toString();
      final perModelOrderQty = _computePerModelQty(qty, boxQtyData[gender]);

      List<dynamic> customs = [];

      final pcEntryByProduct = productCustomizations[productName];
      if (pcEntryByProduct is List) {
        customs = pcEntryByProduct;
      } else if (productCustomizations[gender] is List) {customs = productCustomizations[gender] as List<dynamic>;}
      else if (product['customizations'] is List) {customs = product['customizations'] as List<dynamic>;}

      for (final c in customs) {
        try {
          final Map<String, dynamic> cust = Map<String, dynamic>.from(c);
          final focusColorRaw = (cust['focusColor'] ?? '').toString().trim();
          final baseMat = (cust['focusBaseMaterial'] ?? '').toString().trim();

          final String color = focusColorRaw.isEmpty
              ? '—'
              : (baseMat.isEmpty ? focusColorRaw : "$focusColorRaw - $baseMat");


          final num rawQty = _safeNum(cust['focusQty']);
          final num computed = rawQty * perModelOrderQty;

          final num received = _safeNum(cust['receivedFocus']);
          final num repairing = _safeNum(cust['repairingFocus']);

          colorSet.add(color);

          matrix.putIfAbsent(color, () => {});
          matrix[color]!.putIfAbsent(productName, () => 0);
          matrix[color]![productName] = matrix[color]![productName]! + computed;

          totalMap[color] = (totalMap[color] ?? 0) + computed;
          receivedMap[color] = (receivedMap[color] ?? 0) + received;
          repairingMap[color] = (repairingMap[color] ?? 0) + repairing;
        } catch (_) {}
      }
    }

    // final List<String> colors =
    //     colorSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    int basePriority(String c) {
      final b = c.toLowerCase();
      if (b.contains(' - black')) return 1;
      if (b.contains(' - clear')) return 2;
      if (b.contains(' - pc')) return 3;
      return 4;
    }

    final List<String> colors = colorSet.toList()
      ..sort((a, b) {
        final pa = basePriority(a);
        final pb = basePriority(b);
        if (pa != pb) return pa.compareTo(pb);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return {
      'productNames': productNames,
      'colors': colors,
      'matrix': matrix,
      'totalMap': totalMap,
      'receivedMap': receivedMap,
      'repairingMap': repairingMap,
    };
  }

  Map<String, dynamic> _collectTempleData(
    List<Map<String, dynamic>> orderedProducts,
    Map<String, dynamic> productCustomizations,
    Map<String, dynamic> boxQtyData,
  ) {
    final Set<String> gendersSet = {};
    for (final p in orderedProducts) {
      final g = _capitalize((p['modelGender'] ?? '').toString());
      if (g.isNotEmpty) gendersSet.add(g);
    }

    final List<String> genderOrder = [];
    for (final g in ['gents', 'ladies']) {
      for (final p in orderedProducts) {
        final gr = (p['modelGender'] ?? '').toString().toLowerCase();
        if (g == 'gents' && (gr.contains('gent') || gr.contains('male'))) {
          final name = _capitalize(p['modelGender']);
          if (!genderOrder.contains(name)) genderOrder.add(name);
        } else if (g == 'ladies' && (gr.contains('lady') || gr.contains('female'))) {
          final name = _capitalize(p['modelGender']);
          if (!genderOrder.contains(name)) genderOrder.add(name);
        }
      }
    }

    for (final g in gendersSet) {
      if (!genderOrder.contains(g)) genderOrder.add(g);
    }

    final Map<String, Map<String, num>> matrix = {};
    final Map<String, num> totalMap = {};
    final Map<String, num> recRMap = {};
    final Map<String, num> recLMap = {};
    final Map<String, num> repRMap = {};
    final Map<String, num> repLMap = {};

    final Map<String, int> colorPriority = {};
    final Map<String, int> firstSeenOrder = {};
    int counter = 0;

    for (final product in orderedProducts) {
      final displayName = _productDisplayName(product);
      final num qty = _safeNum(product['quantity']);
      final gender = _capitalize((product['modelGender'] ?? '').toString());
      final perModelQty = _computePerModelQty(qty, boxQtyData[product['modelGender']]);

      List<dynamic> customs = [];
      final pcEntry = productCustomizations[displayName];

      if (pcEntry is List) {
        customs = pcEntry;
      } else if (productCustomizations[product['modelGender']] is List)
        {customs = productCustomizations[product['modelGender']];}
      else if (product['customizations'] is List)
        {customs = product['customizations'];}

      for (final c in customs) {
        try {
          final Map<String, dynamic> cust = Map<String, dynamic>.from(c);
          final templeRaw = (cust['templeColor'] ?? '').toString().trim();
          final base = (cust['templeBaseMaterial'] ?? '').toString().trim();

          final String color = templeRaw.isEmpty
              ? '—'
              : (base.isEmpty ? templeRaw : "$templeRaw - $base");

          final num templeQty = _safeNum(cust['templeQty']);
          final num computed = templeQty * perModelQty;

          final num recR = _safeNum(cust['receivedTempleR']);
          final num recL = _safeNum(cust['receivedTempleL']);
          final num repR = _safeNum(cust['repairingTempleR']);
          final num repL = _safeNum(cust['repairingTempleL']);

          // final base = _extractBaseMaterialFromCustomization(cust);
          final pri = _priorityIndexForBase(base);

          colorPriority.putIfAbsent(color, () => pri);
          firstSeenOrder.putIfAbsent(color, () => counter++);

          matrix.putIfAbsent(color, () => {});
          matrix[color]!.putIfAbsent(gender, () => 0);
          matrix[color]![gender] = matrix[color]![gender]! + computed;

          totalMap[color] = (totalMap[color] ?? 0) + computed;
          recRMap[color] = (recRMap[color] ?? 0) + recR;
          recLMap[color] = (recLMap[color] ?? 0) + recL;
          repRMap[color] = (repRMap[color] ?? 0) + repR;
          repLMap[color] = (repLMap[color] ?? 0) + repL;
        } catch (_) {}
      }
    }

    final colors = colorPriority.keys.toList()
      ..sort((a, b) {
        final pa = colorPriority[a]!;
        final pb = colorPriority[b]!;
        if (pa != pb) return pa.compareTo(pb);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return {
      'genders': genderOrder,
      'colors': colors,
      'matrix': matrix,
      'totalMap': totalMap,
      'recRMap': recRMap,
      'recLMap': recLMap,
      'repRMap': repRMap,
      'repLMap': repLMap,
    };
  }

  // --------------------------------------------------
  // TABLES + SUMMARY + HEADER — UNCHANGED
  // --------------------------------------------------

  pw.Widget _buildHeader(Map<String, dynamic> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'COLOR CHART SHEET',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Order: ${data['orderNumber'] ?? '-'}', style: pw.TextStyle(fontSize: 10)),
            // pw.Text('Customer: ${data['customerName'] ?? '-'}', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Date: ${_formatNow()}', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFocusTable(
    Map<String, dynamic> focusMatrix,
    List<Map<String, dynamic>> orderedProducts,
  ) {
    final List<String> productNames = List<String>.from(focusMatrix['productNames']);
    final List<String> colors = List<String>.from(focusMatrix['colors']);
    final Map<String, Map<String, num>> matrix =
        (focusMatrix['matrix'] as Map).map((k, v) => MapEntry(
              k as String,
              (v as Map).map((pk, pv) => MapEntry(pk as String, _safeNum(pv))),
            ));

    final receivedMap = _toNumMap(focusMatrix['receivedMap']);
    final repairingMap = _toNumMap(focusMatrix['repairingMap']);

    final headerCells = <pw.Widget>[];
    headerCells.add(_headerCell('Focus Color'));
    for (final pn in productNames) {
      headerCells.add(_headerCell(pn));
    }
    headerCells.add(_headerCell('Total'));
    headerCells.add(_headerCell('Received'));
    headerCells.add(_headerCell('Repairing'));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headerCells,
      ),
    ];

    for (final color in colors) {
      final cells = <pw.Widget>[];
      cells.add(_bodyCell(color));

      num rowTotal = 0;

      for (final pn in productNames) {
        final v = matrix[color]?[pn] ?? 0;
        rowTotal += v;
        cells.add(_bodyCell(v == 0 ? '' : v.toStringAsFixed(0)));
      }

      final rec = receivedMap[color] ?? 0;
      final rep = repairingMap[color] ?? 0;

      cells.add(_bodyCell(rowTotal == 0 ? '' : rowTotal.toStringAsFixed(0)));
      cells.add(_bodyCell(rec == 0 ? '' : rec.toStringAsFixed(0)));
      cells.add(_bodyCell(rep == 0 ? '' : rep.toStringAsFixed(0)));

      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        ..._buildProductColumnWidths(productNames.length),
      },
      defaultColumnWidth: const pw.FlexColumnWidth(),
      children: rows,
    );
  }

  pw.Widget _buildTempleTable(Map<String, dynamic> templeMatrix) {
    final List<String> genders = List<String>.from(templeMatrix['genders']);
    final List<String> colors = List<String>.from(templeMatrix['colors']);
    final Map<String, Map<String, num>> matrix =
        (templeMatrix['matrix'] as Map).map((k, v) => MapEntry(
              k as String,
              (v as Map).map((gk, gv) => MapEntry(gk as String, _safeNum(gv))),
            ));

    final recRMap = _toNumMap(templeMatrix['recRMap']);
    final recLMap = _toNumMap(templeMatrix['recLMap']);
    final repRMap = _toNumMap(templeMatrix['repRMap']);
    final repLMap = _toNumMap(templeMatrix['repLMap']);

    final headerCells = <pw.Widget>[
      _headerCell('Temple Color'),
      ...genders.map(_headerCell),
      _headerCell('Total'),
      _headerCell('Rec R'),
      _headerCell('Rec L'),
      _headerCell('Rep R'),
      _headerCell('Rep L'),
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headerCells,
      )
    ];

    for (final color in colors) {
      final cells = <pw.Widget>[];
      cells.add(_bodyCell(color));

      num rowTotal = 0;

      for (final g in genders) {
        final v = matrix[color]?[g] ?? 0;
        rowTotal += v;
        cells.add(_bodyCell(v == 0 ? '' : v.toStringAsFixed(0)));
      }

      cells.add(_bodyCell(rowTotal == 0 ? '' : rowTotal.toStringAsFixed(0)));
      cells.add(_bodyCell((recRMap[color] ?? 0).toStringAsFixed(0)));
      cells.add(_bodyCell((recLMap[color] ?? 0).toStringAsFixed(0)));
      cells.add(_bodyCell((repRMap[color] ?? 0).toStringAsFixed(0)));
      cells.add(_bodyCell((repLMap[color] ?? 0).toStringAsFixed(0)));

      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        ..._buildGenderColumnWidths(genders.length),
      },
      defaultColumnWidth: const pw.FlexColumnWidth(),
      children: rows,
    );
  }

  pw.Widget _buildOverallSummary(
      Map<String, dynamic> focusMatrix, Map<String, dynamic> templeMatrix) {
    final totalFocus = _toNumMap(focusMatrix['totalMap'])
        .values
        .fold<num>(0, (s, v) => s + v);

    final totalTemple = _toNumMap(templeMatrix['totalMap'])
        .values
        .fold<num>(0, (s, v) => s + v);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Summary',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Total Focus Qty: ${totalFocus.toStringAsFixed(0)}',
                  style: pw.TextStyle(fontSize: 10)),
              pw.Text('Total Temple Qty: ${totalTemple.toStringAsFixed(0)}',
                  style: pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Text(
            'Generated: ${_formatNow()}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Small Helpers
  // --------------------------------------------------

  String _productDisplayName(Map<String, dynamic> product) {
    final pn = (product['productName'] ?? '').toString().trim();
    if (pn.isNotEmpty) return pn;

    final gender = (product['modelGender'] ?? '').toString();
    final sku = (product['sku'] ?? '').toString();
    if (sku.isNotEmpty) return '$gender - $sku';

    return 'Unnamed Product';
  }

  num _computePerModelQty(num qty, dynamic boxQtyVal) {
    final b = _safeNum(boxQtyVal);
    if (b == 0) return qty;
    return qty / b;
  }

  num _safeNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  int _priorityIndexForBase(String base) {
    final b = base.toLowerCase();
    if (b.contains('black')) return 1;
    if (b.contains('clear')) return 2;
    if (b.contains('pc')) return 3;
    return 4;
  }

  Map<String, num> _toNumMap(dynamic map) {
    return (map as Map).map((k, v) => MapEntry(k as String, _safeNum(v)));
  }

  Map<int, pw.FlexColumnWidth> _buildProductColumnWidths(int count) {
    final map = <int, pw.FlexColumnWidth>{};
    for (int i = 0; i < count; i++) {
      map[i + 1] = const pw.FlexColumnWidth(1);
    }
    final base = 1 + count;
    map[base] = const pw.FlexColumnWidth(1.2);
    map[base + 1] = const pw.FlexColumnWidth(1);
    map[base + 2] = const pw.FlexColumnWidth(1);
    return map;
  }

  Map<int, pw.FlexColumnWidth> _buildGenderColumnWidths(int count) {
    final map = <int, pw.FlexColumnWidth>{};
    for (int i = 0; i < count; i++) {
      map[i + 1] = const pw.FlexColumnWidth(1);
    }
    final base = 1 + count;
    map[base] = const pw.FlexColumnWidth(1.2);
    map[base + 1] = const pw.FlexColumnWidth(1);
    map[base + 2] = const pw.FlexColumnWidth(1);
    map[base + 3] = const pw.FlexColumnWidth(1);
    map[base + 4] = const pw.FlexColumnWidth(1);
    return map;
  }

  pw.Widget _headerCell(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _bodyCell(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value, style: pw.TextStyle(fontSize: 9)),
    );
  }

  String _formatNow() {
    final d = DateTime.now();
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.split(' ').map((p) {
      if (p.isEmpty) return '';
      return p[0].toUpperCase() + p.substring(1);
    }).join(' ');
  }
}
