import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../temple_color_details_page/controllers/temple_table_controller.dart';

class TemplePdfTable {
  static pw.Widget build({
    required List<String> genders,
    required TempleTableController controller,
  }) {
    // ---------------- HEADERS ----------------
    final headers = <String>[
      'Temple Color',
      for (final g in genders) ...[
        g,
        'Rec R',
        'Rec L',
        'Rep R',
        'Rep L',
        'Pending R',
        'Pending L',
      ],
      'Total',
      'Rec R',
      'Rec L',
      'Rep R',
      'Rep L',
      'Pending R',
      'Pending L',
    ];

    final rows = <List<String>>[];

    for (final row in controller.rows.values) {
      final cells = <String>[row.color];

      for (final g in genders) {
        final cell = row.genders[g]!;

        cells.add(cell.qty.toStringAsFixed(0));
        cells.add(cell.recRCtrl.text);
        cells.add(cell.recLCtrl.text);
        cells.add(cell.repRCtrl.text);
        cells.add(cell.repLCtrl.text);
        cells.add(cell.pendingR.value.toStringAsFixed(0));
        cells.add(cell.pendingL.value.toStringAsFixed(0));
      }

      cells.add(row.totalQty.toStringAsFixed(0));
      cells.add(row.recRTotal.value.toStringAsFixed(0));
      cells.add(row.recLTotal.value.toStringAsFixed(0));
      cells.add(row.repRTotal.value.toStringAsFixed(0));
      cells.add(row.repLTotal.value.toStringAsFixed(0));

      final pendingR = row.genders.values.fold<num>(
        0,
        (s, c) => s + c.pendingR.value,
      );
      final pendingL = row.genders.values.fold<num>(
        0,
        (s, c) => s + c.pendingL.value,
      );

      cells.add(pendingR.toStringAsFixed(0));
      cells.add(pendingL.toStringAsFixed(0));

      rows.add(cells);
    }

    // ---------------- TOTAL ROW ----------------
    final totalCells = <String>['TOTAL'];

    for (int i = 0; i < genders.length; i++) {
      totalCells.addAll(['', '', '', '', '', '', '']);
    }

    totalCells.addAll([
      '',
      controller.grandRecR.value.toStringAsFixed(0),
      controller.grandRecL.value.toStringAsFixed(0),
      controller.grandRepR.value.toStringAsFixed(0),
      controller.grandRepL.value.toStringAsFixed(0),
      controller.grandPendingR.value.toStringAsFixed(0),
      controller.grandPendingL.value.toStringAsFixed(0),
    ]);

    rows.add(totalCells);

    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellAlignment: pw.Alignment.center,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
      },
    );
  }
}
