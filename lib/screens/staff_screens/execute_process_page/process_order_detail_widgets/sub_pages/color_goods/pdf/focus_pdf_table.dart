import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../focus_color_details_page/controllers/focus_table_controller.dart';

class FocusPdfTable {
  static pw.Widget build({
    required List<String> productNames,
    required FocusTableController controller,
  }) {
    // ---------------- HEADERS ----------------
    final headers = <String>[
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
      'Pending',
    ];

    // ---------------- ROWS ----------------
    final rows = <List<String>>[];

    for (final row in controller.rows.values) {
      final cells = <String>[row.color];

      for (final pn in productNames) {
        final cell = row.products[pn]!;

        cells.add(cell.qty.toStringAsFixed(0));
        cells.add(cell.recCtrl.text);
        cells.add(cell.repCtrl.text);
        cells.add(cell.pending.value.toStringAsFixed(0));
      }

      cells.add(row.totalQty.toStringAsFixed(0));
      cells.add(row.recTotal.value.toStringAsFixed(0));
      cells.add(row.repTotal.value.toStringAsFixed(0));
      cells.add(row.pendingTotal.value.toStringAsFixed(0));

      rows.add(cells);
    }

    // ---------------- TOTAL ROW ----------------
    final totalCells = <String>['TOTAL'];

    for (int i = 0; i < productNames.length; i++) {
      totalCells.addAll(['', '', '', '']);
    }

    totalCells.addAll([
      '', // total qty already shown per row
      controller.grandRec.value.toStringAsFixed(0),
      controller.grandRep.value.toStringAsFixed(0),
      controller.grandPending.value.toStringAsFixed(0),
    ]);

    rows.add(totalCells);

    // ---------------- TABLE ----------------
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
