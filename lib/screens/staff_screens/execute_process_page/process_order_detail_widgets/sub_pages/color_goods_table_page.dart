// color_goods_table_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ColorGoodsTablePage extends StatefulWidget {
  final String companyId;
  final String orderId;
  final List products; // parent-provided product list

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
  // controllers for received & repairing fields
  final Map<String, TextEditingController> recRCtr = {};
  final Map<String, TextEditingController> recLCtr = {};
  final Map<String, TextEditingController> repRCtr = {};
  final Map<String, TextEditingController> repLCtr = {};

  // Row level value notifiers
  final Map<String, ValueNotifier<num>> rowRecTotal = {};
  final Map<String, ValueNotifier<num>> rowRepTotal = {};
  final Map<String, ValueNotifier<num>> rowPendingTotal = {};

  final ValueNotifier<num> grandRecTotal = ValueNotifier<num>(0);
  final ValueNotifier<num> grandRepTotal = ValueNotifier<num>(0);
  final ValueNotifier<num> grandPendingTotal = ValueNotifier<num>(0);

  // Pending per product notifier
  final Map<String, Map<String, TextEditingController>> recPerProductCtr = {};
  final Map<String, Map<String, TextEditingController>> repPerProductCtr = {};
  final Map<String, Map<String, ValueNotifier<num>>> pendingPerProduct = {};

  bool _grandInitialized = false;

  // -----------------------
  // Helpers copied from PDF logic
  // -----------------------
  num _safeNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  // int _toInt(dynamic v) {
  //   final n = _safeNum(v);
  //   return n.toInt();
  // }

  String _productDisplayName(Map<String, dynamic> product) {
    final pn = (product['productName'] ?? '').toString().trim();
    if (pn.isNotEmpty) return pn;

    final gender = (product['modelGender'] ?? '').toString();
    final sku = (product['sku'] ?? '').toString();
    if (sku.isNotEmpty) return '$gender - $sku';

    return 'Unnamed Product';
  }

  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.split(' ').map((p) {
      if (p.isEmpty) return '';
      return p[0].toUpperCase() + p.substring(1);
    }).join(' ');
  }

  int _priorityIndexForBase(String base) {
    final b = base.toLowerCase();
    if (b.contains('black')) return 1;
    if (b.contains('clear')) return 2;
    if (b.contains('pc')) return 3;
    return 4;
  }

  num _computePerModelQty(num qty, dynamic boxQtyVal) {
    final b = _safeNum(boxQtyVal);
    if (b == 0) return qty;
    return qty / b;
  }

  Map<String, num> _toNumMap(dynamic map) {
    final out = <String, num>{};
    if (map is Map) {
      for (final e in map.entries) {
        out[e.key.toString()] = _safeNum(e.value);
      }
    }
    return out;
  }

  // replicate _collectProductsOrderedByGender
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
        } else if (genderRaw.contains('lady') || genderRaw.contains('female')) {
          ladies.add(mp);
        } else {
          others.add(mp);
        }
      } catch (_) {}
    }

    return [...gents, ...ladies, ...others];
  }

  // Ported focus matrix builder (exact logic)
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
      } else if (productCustomizations[gender] is List) {
        customs = productCustomizations[gender] as List<dynamic>;
      } else if (product['customizations'] is List) {
        customs = product['customizations'] as List<dynamic>;
      }

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

  // Ported temple matrix builder (exact logic)
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
      } else if (productCustomizations[product['modelGender']] is List) {
        customs = productCustomizations[product['modelGender']];
      } else if (product['customizations'] is List) {
        customs = product['customizations'];
      }

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

  void _recalcProductPending(String color, String product, num qty) {
    final rec = _safeNum(recPerProductCtr[color]![product]!.text);
    final rep = _safeNum(repPerProductCtr[color]![product]!.text);

    pendingPerProduct[color]![product]!.value =
        qty - rec - rep;
  }

  void _recalcRowTotals(String color, num rowTotal) {
    final rec = recPerProductCtr[color]!.values.fold<num>(
      0,
      (s, c) => s + _safeNum(c.text),
    );

    final rep = repPerProductCtr[color]!.values.fold<num>(
      0,
      (s, c) => s + _safeNum(c.text),
    );

    rowRecTotal[color]!.value = rec;
    rowRepTotal[color]!.value = rep;
    rowPendingTotal[color]!.value = rowTotal - rec - rep;
  }

  void _recalcAllForRow(String color, Map<String, num> rowMatrix) {
    num rowTotal = rowMatrix.values.fold<num>(0, (s, v) => s + v);

    num rec = 0;
    num rep = 0;

    for (final entry in rowMatrix.entries) {
      final product = entry.key;
      final qty = entry.value;

      final r = _safeNum(recPerProductCtr[color]![product]!.text);
      final p = _safeNum(repPerProductCtr[color]![product]!.text);

      rec += r;
      rep += p;

      pendingPerProduct[color]![product]!.value = qty - r - p;
    }

    rowRecTotal[color]!.value = rec;
    rowRepTotal[color]!.value = rep;
    rowPendingTotal[color]!.value = rowTotal - rec - rep;

    // 👇 ADD THIS
    _recalcGrandTotals();
  }

  void _recalcGrandTotals() {
    num rec = 0;
    num rep = 0;
    num total = 0;

    rowRecTotal.forEach((_, v) => rec += v.value);
    rowRepTotal.forEach((_, v) => rep += v.value);
    rowPendingTotal.forEach((_, v) => total += v.value);

    grandRecTotal.value = rec;
    grandRepTotal.value = rep;
    grandPendingTotal.value = total;
  }


  // ---------------------------
  // UI Table builders (mimic PDF style)
  // ---------------------------
  Widget _focusTableWidget(Map<String, dynamic> focusMatrix) {
    final List<String> productNames = List<String>.from(focusMatrix['productNames'] ?? []);
    final List<String> colors = List<String>.from(focusMatrix['colors'] ?? []);
    final matrix = (focusMatrix['matrix'] ?? {}) as Map<String, Map<String, num>>;
    final totalMap = _toNumMap(focusMatrix['totalMap'] ?? {});
    num grandTotal = 0;
    final Map<String, num> columnTotals = { for (final pn in productNames) pn: 0 };

    final headerTitles = <String>[
      'Focus Color', 
      for (final pn in productNames) ...[
        pn,
        'Rec',
        'Rep',
        'Pending',
      ],
      'Total', 
      'Received', 
      'Repairing', 
      'Pending'
    ];

    // Build DataTable columns
    final columns = headerTitles.map((t) => DataColumn(label: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)))).toList();

    for (final color in colors) {
      final rTotal = totalMap[color] ?? 0;
      
      rowRecTotal.putIfAbsent(color, () => ValueNotifier<num>(0));
      rowRepTotal.putIfAbsent(color, () => ValueNotifier<num>(0));
      rowPendingTotal.putIfAbsent(color, () => ValueNotifier<num>(0));

      recPerProductCtr.putIfAbsent(color, () => {});
      repPerProductCtr.putIfAbsent(color, () => {});
      pendingPerProduct.putIfAbsent(color, () => {});

      grandTotal += rTotal;

      if (!_grandInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final color in colors) {
            _recalcAllForRow(color, matrix[color]!);
          }
          _grandInitialized = true;
        });
      }

      for (final pn in productNames) {
        columnTotals[pn] = (columnTotals[pn] ?? 0) + (matrix[color]?[pn] ?? 0);
      }

      for (final pn in productNames) {
        final qty = matrix[color]?[pn] ?? 0;
        final rowTotal = productNames.fold<num>(
          0,
          (s, pn) => s + (matrix[color]?[pn] ?? 0),
        );

        // 👇 FORCE recalculation from existing values
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _recalcRowTotals(color, rowTotal);

          for (final pn in productNames) {
            _recalcProductPending(
              color,
              pn,
              matrix[color]?[pn] ?? 0,
            );
          }
        });

        recPerProductCtr[color]!.putIfAbsent(
          pn,
          () => TextEditingController(text: '0'),
        );

        repPerProductCtr[color]!.putIfAbsent(
          pn,
          () => TextEditingController(text: '0'),
        );

        pendingPerProduct[color]!.putIfAbsent(
          pn,
          () => ValueNotifier<num>(matrix[color]?[pn] ?? 0),
        );

        // 👇 FORCE INITIAL CALC
        pendingPerProduct[color]![pn]!.value = qty;
      }
    }

    final rows = <DataRow>[];
    
    for (int i = 0; i < colors.length; i++) {
      final color = colors[i];
      final isEven = i % 2 == 0;

      final List<DataCell> cells = [];
      cells.add(DataCell(Text(color, style: GoogleFonts.poppins(fontSize: 12))));

      num rowTotal = 0;
      // for (final pn in productNames) {
      //   final v = matrix[color]?[pn] ?? 0;
      //   rowTotal += v;
      //   cells.add(DataCell(Text(v == 0 ? '' : v.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 12))));
      // }

      for (final pn in productNames) {
        final v = matrix[color]?[pn] ?? 0;
        rowTotal += v;

        // Product qty cell
        cells.add(
          DataCell(
            Text(
              v == 0 ? '' : v.toStringAsFixed(0),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        );

        // Received
        cells.add(
          DataCell(
            SizedBox(
              width: 60,
              child: TextField(
                controller: recPerProductCtr[color]![pn],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onChanged: (_) {
                  _recalcAllForRow(color, matrix[color]!);
                },
              ),
            ),
          ),
        );

        // Repairing
        cells.add(
          DataCell(
            SizedBox(
              width: 60,
              child: TextField(
                controller: repPerProductCtr[color]![pn],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onChanged: (_) {
                  _recalcAllForRow(color, matrix[color]!);
                },
              ),
            ),
          ),
        );

        // Pending (LIVE)
        cells.add(
          DataCell(
            ValueListenableBuilder<num>(
              valueListenable: pendingPerProduct[color]![pn]!,
              builder: (_, value, __) {
                return Text(
                  value.toStringAsFixed(0),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: value > 0 ? Colors.red : Colors.green,
                  ),
                );
              },
            ),
          ),
        );
      }

      // final rec = receivedMap[color] ?? 0;
      // final rep = repairingMap[color] ?? 0;

      cells.add(DataCell(Text(rowTotal == 0 ? '' : rowTotal.toStringAsFixed(0), style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));

      // RECEIVED (TEXT)
      cells.add(
        DataCell(
          ValueListenableBuilder<num>(
            valueListenable: rowRecTotal[color]!,
            builder: (_, value, __) {
              return Text(
                value.toStringAsFixed(0),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      );

      // REPAIRING (TEXT)
      cells.add(
        DataCell(
          ValueListenableBuilder<num>(
            valueListenable: rowRepTotal[color]!,
            builder: (_, value, __) {
              return Text(
                value.toStringAsFixed(0),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      );

      // PENDING (TEXT)
      cells.add(
        DataCell(
          ValueListenableBuilder<num>(
            valueListenable: rowPendingTotal[color]!,
            builder: (_, value, __) {
              return Text(
                value.toStringAsFixed(0),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: value > 0 ? Colors.red : Colors.green,
                ),
              );
            },
          ),
        ),
      );

      rows.add(
        DataRow(
          color: MaterialStateProperty.all(isEven ? Colors.grey.shade200 : Colors.white),
          cells: cells,
        ),
      );
    }

    final List<DataCell> totalCells = [];

    // Focus Color column
    totalCells.add(
      DataCell(
        Text('TOTAL', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
    );

    // Product + Pending columns
    for (final pn in productNames) {
      final productTotal = columnTotals[pn] ?? 0;

      final totalRec = recPerProductCtr.values.fold<num>(
        0,
        (s, m) => s + (_safeNum(m[pn]?.text)),
      );

      final totalRep = repPerProductCtr.values.fold<num>(
        0,
        (s, m) => s + (_safeNum(m[pn]?.text)),
      );

      final pendingTotal = productTotal - totalRec - totalRep;

      // Qty
      totalCells.add(
        DataCell(
          Text(productTotal.toStringAsFixed(0),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      );

      // Rec
      totalCells.add(
        DataCell(
          Text(totalRec.toStringAsFixed(0),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      );

      // Rep
      totalCells.add(
        DataCell(
          Text(totalRep.toStringAsFixed(0),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      );

      // Pending
      totalCells.add(
        DataCell(
          Text(pendingTotal.toStringAsFixed(0),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: pendingTotal > 0 ? Colors.red : Colors.green,
              )),
        ),
      );
    }
    
    // Final columns
    totalCells.add(DataCell(Text(grandTotal.toStringAsFixed(0))));
    totalCells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: grandRecTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

    totalCells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: grandRepTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

    totalCells.add(
      DataCell(
        ValueListenableBuilder<num>(
          valueListenable: grandPendingTotal,
          builder: (_, v, __) => Text(
            v.toStringAsFixed(0),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: v > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );

    // Add row into table
    rows.add(
      DataRow(
        color: MaterialStateProperty.all(Colors.amber.shade200),
        cells: totalCells,
      ),
    );


    // Build header row style using a container to get dark background
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("FOCUS COLOR SUMMARY", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.black87),
              headingTextStyle: GoogleFonts.poppins(textStyle: const TextStyle(color: Colors.white)),
              columns: columns,
              rows: rows,
              columnSpacing: 14,
              dataRowHeight: 36,
              headingRowHeight: 40,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _templeTableWidget(Map<String, dynamic> templeMatrix) {
    final List<String> genders = List<String>.from(templeMatrix['genders'] ?? []);
    final List<String> colors = List<String>.from(templeMatrix['colors'] ?? []);
    final matrix = (templeMatrix['matrix'] ?? {}) as Map<String, Map<String, num>>;
    // final totalMap = _toNumMap(templeMatrix['totalMap'] ?? {});
    final recRMap = _toNumMap(templeMatrix['recRMap'] ?? {});
    final recLMap = _toNumMap(templeMatrix['recLMap'] ?? {});
    final repRMap = _toNumMap(templeMatrix['repRMap'] ?? {});
    final repLMap = _toNumMap(templeMatrix['repLMap'] ?? {});

    final headerTitles = <String>['Temple Color', ...genders, 'Total', 'Rec R', 'Rec L', 'Rep R', 'Rep L'];

    final columns = headerTitles.map((t) => DataColumn(label: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)))).toList();

    num grandTotal = 0;
    num grandRecR = 0;
    num grandRecL = 0;
    num grandRepR = 0;
    num grandRepL = 0;

    final Map<String, num> columnTotals = {
      for (final g in genders) g: 0
    };

    for (final color in colors) {
      for (final g in genders) {
        columnTotals[g] =
            (columnTotals[g] ?? 0) + (matrix[color]?[g] ?? 0);
      }

      final rowTotal = genders.fold<num>(
        0,
        (s, g) => s + (matrix[color]?[g] ?? 0),
      );

      grandTotal += rowTotal;
      grandRecR += recRMap[color] ?? 0;
      grandRecL += recLMap[color] ?? 0;
      grandRepR += repRMap[color] ?? 0;
      grandRepL += repLMap[color] ?? 0;
      
      recRCtr.putIfAbsent(color, () {
        return TextEditingController(text: (recRMap[color] ?? 0).toString());
      });
      recLCtr.putIfAbsent(color, () {
        return TextEditingController(text: (recLMap[color] ?? 0).toString());
      });
      repRCtr.putIfAbsent(color, () {
        return TextEditingController(text: (repRMap[color] ?? 0).toString());
      });
      repLCtr.putIfAbsent(color, () {
        return TextEditingController(text: (repLMap[color] ?? 0).toString());
      });
    }


    final rows = <DataRow>[];
    for (int i = 0; i < colors.length; i++) {
      final color = colors[i];
      final isEven = i % 2 == 0;

      final List<DataCell> cells = [];
      cells.add(DataCell(Text(color, style: GoogleFonts.poppins(fontSize: 12))));

      num rowTotal = 0;
      for (final g in genders) {
        final v = matrix[color]?[g] ?? 0;
        rowTotal += v;
        cells.add(DataCell(Text(v == 0 ? '' : v.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 12))));
      }

      cells.add(DataCell(Text(rowTotal == 0 ? '' : rowTotal.toStringAsFixed(0), style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));
      cells.add(
        DataCell(
          SizedBox(
            width: 70,
            child: TextField(
              controller: recRCtr[color],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ),
      );

      cells.add(
        DataCell(
          SizedBox(
            width: 70,
            child: TextField(
              controller: recLCtr[color],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ),
      );

      cells.add(
        DataCell(
          SizedBox(
            width: 70,
            child: TextField(
              controller: repRCtr[color],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ),
      );

      cells.add(
        DataCell(
          SizedBox(
            width: 70,
            child: TextField(
              controller: repLCtr[color],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ),
      );

      rows.add(
        DataRow(
          color: MaterialStateProperty.all(isEven ? Colors.grey.shade200 : Colors.white),
          cells: cells,
        ),
      );
    }

    final List<DataCell> totalCells = [];

      totalCells.add(
        DataCell(
          Text("TOTAL", style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      );

      // Gender column totals
      for (final g in genders) {
        final v = columnTotals[g] ?? 0;
        totalCells.add(
          DataCell(
            Text(
              v == 0 ? '' : v.toStringAsFixed(0),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }

      // Total column
      totalCells.add(
        DataCell(
          Text(
            grandTotal.toStringAsFixed(0),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      );

      // Rec / Rep totals
      totalCells.add(DataCell(Text(grandRecR.toStringAsFixed(0),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));
      totalCells.add(DataCell(Text(grandRecL.toStringAsFixed(0),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));
      totalCells.add(DataCell(Text(grandRepR.toStringAsFixed(0),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));
      totalCells.add(DataCell(Text(grandRepL.toStringAsFixed(0),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700))));
      rows.add(
        DataRow(
          color: MaterialStateProperty.all(Colors.amber.shade200),
          cells: totalCells,
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TEMPLE COLOR SUMMARY", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.black87),
              headingTextStyle: GoogleFonts.poppins(textStyle: const TextStyle(color: Colors.white)),
              columns: columns,
              rows: rows,
              columnSpacing: 14,
              dataRowHeight: 36,
              headingRowHeight: 40,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ---------------------------
  // Build page using a StreamBuilder to keep tables live
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance
        .collection("companies")
        .doc(widget.companyId)
        .collection("orders")
        .doc(widget.orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Color Goods"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !(snap.data!.exists)) {
            return const Center(child: Text("Order not found"));
          }

          final orderData = snap.data!.data()!;
          final productCustomizations = (orderData['productCustomizations'] ?? {}) as Map<String, dynamic>;
          final boxQtyData = (orderData['boxQuantity'] ?? {}) as Map<String, dynamic>;

          // Ensure we have orderedProducts using parent products (keeps gender order)
          final orderedProducts = _collectProductsOrderedByGender(widget.products);

          // Build matrices using exact PDF logic
          final focusMatrix = _collectFocusData(orderedProducts, productCustomizations, boxQtyData);
          final templeMatrix = _collectTempleData(orderedProducts, productCustomizations, boxQtyData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header summary
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COLOR CHART SHEET', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order: ${orderData['orderNumber'] ?? '-'}', style: GoogleFonts.poppins(fontSize: 12)),
                          Text('Generated: ${DateTime.now().toLocal().toString().split(".").first}', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Focus table (exact logic)
                _focusTableWidget(focusMatrix),

                // Temple table (exact logic)
                _templeTableWidget(templeMatrix),

                // Summary box (combined)
                _overallSummaryWidget(focusMatrix, templeMatrix),

                // Save Button
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                  ),
                  onPressed: _saveColorGoodsToFirestore,
                  child: Text(
                    "Save Color Goods",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveColorGoodsToFirestore() async {
    final orderRef = FirebaseFirestore.instance
        .collection("companies")
        .doc(widget.companyId)
        .collection("orders")
        .doc(widget.orderId);

    // -----------------------
    // Build FOCUS data map
    // -----------------------
    final Map<String, dynamic> focusData = {};

    // -----------------------
    // Build TEMPLE data map
    // -----------------------
    final Map<String, dynamic> templeData = {};

    recRCtr.forEach((color, controller) {
      final recR = num.tryParse(controller.text.trim()) ?? 0;
      final recL = num.tryParse(recLCtr[color]?.text.trim() ?? "0") ?? 0;
      final repR = num.tryParse(repRCtr[color]?.text.trim() ?? "0") ?? 0;
      final repL = num.tryParse(repLCtr[color]?.text.trim() ?? "0") ?? 0;

      templeData[color] = {
        "recR": recR,
        "recL": recL,
        "repR": repR,
        "repL": repL,
      };
    });

    // -----------------------
    // Combine
    // -----------------------
    final colorDetails = {
      "focus": focusData,
      "temple": templeData,
      "updatedAt": DateTime.now().toIso8601String(),
    };

    try {
      await orderRef.update({"colorDetails": colorDetails});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Color Details Saved Successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to Save: $e")),
        );
      }
    }
  }


  Widget _overallSummaryWidget(Map<String, dynamic> focusMatrix, Map<String, dynamic> templeMatrix) {
    final totalFocus = _toNumMap(focusMatrix['totalMap']).values.fold<num>(0, (s, v) => s + v);
    final totalTemple = _toNumMap(templeMatrix['totalMap']).values.fold<num>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.0),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Total Focus Qty Received: ${totalFocus.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Total Temple Qty Received: ${totalTemple.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Text('Prepared: ${DateTime.now().toLocal().toString().split(".").first}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
