import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'focus_color_details_page/controllers/focus_table_controller.dart';
import 'pdf/focus_pdf_table.dart';
import 'pdf/temple_pdf_table.dart';
import 'temple_color_details_page/controllers/temple_table_controller.dart';

class ColorGoodsPdfGenerator {
  static Future<void> generateAndShare({
    required String orderNumber,
    required List<String> productNames,
    required List<String> genders,
    required FocusTableController focusController,
    required TempleTableController templeController,
  }) async {
    final pdf = pw.Document();

    // ------------------------------------------------
    // PAGE 1 — FOCUS COLOR SUMMARY
    // ------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          _title('FOCUS COLOR SUMMARY', orderNumber),
          pw.SizedBox(height: 12),
          FocusPdfTable.build(
            productNames: productNames,
            controller: focusController,
          ),
        ],
      ),
    );

    // ------------------------------------------------
    // PAGE 2 — TEMPLE COLOR SUMMARY
    // ------------------------------------------------
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          _title('TEMPLE COLOR SUMMARY', orderNumber),
          pw.SizedBox(height: 12),
          TemplePdfTable.build(
            genders: genders,
            controller: templeController,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Color_Goods_$orderNumber.pdf',
    );
  }

  static pw.Widget _title(String text, String orderNumber) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Order No: $orderNumber',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
      ],
    );
  }
}
