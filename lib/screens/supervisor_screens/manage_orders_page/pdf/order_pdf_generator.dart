// pdf/order_pdf_generator.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/pdf/pdf_status_mapper.dart';

class OrderPdfGenerator {
  Future<void> generateAndSharePDF(Map<String, dynamic> data, List<dynamic> products) async {
    final pdf = pw.Document();
    final totals = _computeTotals(products);

    final headerGradient = [PdfColors.lightBlue200, PdfColors.cyan200];

    final grandTotal = products.fold<double>(0.0, (sum, p) {
      final qty = (p['quantity'] ?? 0) as num;
      final price = (p['price'] ?? 0) as num;
      return sum + (qty * price);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Container(
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: headerGradient, begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 48,
                  height: 48,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    gradient: pw.LinearGradient(colors: [PdfColors.indigo400, PdfColors.blue300]),
                  ),
                  child: pw.Center(
                    child: pw.Icon(pw.IconData(0xe8cc), color: PdfColors.white, size: 20),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${data['customerName'] ?? 'Unknown Customer'}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      pw.SizedBox(height: 4),
                      pw.Text('Order ID: ${data['orderNumber'] ?? '-'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfStatusMapper.map(data['orderStatus']),
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Text((data['orderStatus'] ?? 'Unknown').toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Icon(pw.IconData(0xe935), size: 10, color: PdfColors.black),
                          pw.SizedBox(width: 4),
                          pw.Text(_formatDate(data['orderDate']), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(8), color: PdfColors.grey100),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStatItem('Products', '${totals['totalProducts']}'),
                _pdfStatItem('Quantity', '${totals['totalQty']}'),
                _pdfStatItem('Focus Qty', '${totals['totalFocus']}'),
                _pdfStatItem('Temple Qty', '${totals['totalTemple']}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Product Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...products.map((p) {
            final productName = p['productName'] ?? 'Unnamed Product';
            final qty = p['quantity'] ?? 0;
            final price = (p['price'] ?? 0).toDouble();
            final totalAmount = qty * price;
            final productCustomizations = (data['productCustomizations'] ?? {});
            final modelGender = p['modelGender'];
            final perModelOrderQty = (data['boxQuantity'] != null && data['boxQuantity'][modelGender] != null && data['boxQuantity'][modelGender] != 0)
                ? (qty / data['boxQuantity'][modelGender])
                : qty;

            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(productName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text('Qty: $qty', style: pw.TextStyle(color: PdfColors.blue800, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Text('Price: Rs.${price.toStringAsFixed(2)}   |   Total: Rs.${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 6),
                  if ((productCustomizations[modelGender] ?? []).isNotEmpty)
                    pw.Column(
                      children: (productCustomizations[modelGender] ?? []).map<pw.Widget>((c) {
                        final focusColor = (c['focusColor'] ?? '').toString();
                        final templeColor = (c['templeColor'] ?? '').toString();
                        final focusQty = ((c['focusQty'] ?? 0) as num) * perModelOrderQty;
                        final templeQty = ((c['templeQty'] ?? 0) as num) * perModelOrderQty;

                        return pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 3),
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.grey200), borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            _pdfColorChip(focusColor, 'Focus', focusQty),
                            _pdfColorChip(templeColor, 'Temple', templeQty),
                          ]),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green300), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.Text('Rs.${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ]),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/order_${data['orderNumber']}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Order report for ${data['customerName']}');
  }

  Map<String, int> _computeTotals(List<dynamic> products) {
    int totalProducts = products.length;
    int totalQty = 0;
    int totalFocus = 0;
    int totalTemple = 0;

    for (final p in products) {
      try {
        final qty = (p['quantity'] is int) ? p['quantity'] as int : int.tryParse('${p['quantity']}') ?? 0;
        totalQty += qty;

        final productCustomizations = (p['customizations'] as List<dynamic>?) ?? [];
        for (final c in productCustomizations) {
          final fq = (c['focusQty'] is int) ? c['focusQty'] as int : int.tryParse('${c['focusQty']}') ?? 0;
          final tq = (c['templeQty'] is int) ? c['templeQty'] as int : int.tryParse('${c['templeQty']}') ?? 0;
          totalFocus += fq;
          totalTemple += tq;
        }
      } catch (_) {}
    }

    return {
      'totalProducts': totalProducts,
      'totalQty': totalQty,
      'totalFocus': totalFocus,
      'totalTemple': totalTemple,
    };
  }

  String _formatDate(dynamic ts) {
    try {
      if (ts == null) return '—';
      if (ts is DateTime) return '${ts.toLocal()}';
      return ts.toString();
    } catch (_) {
      return '—';
    }
  }

  pw.Widget _pdfStatItem(String title, String value) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      pw.SizedBox(height: 2),
      pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ]);
  }

  pw.Widget _pdfColorChip(String colorLabel, String title, num qty) {
    PdfColor? parsed;
    final cleaned = colorLabel.replaceAll('#', '').replaceAll('0x', '');
    if (cleaned.length == 6 || cleaned.length == 8) {
      try {
        final hex = int.parse(cleaned, radix: 16);
        parsed = PdfColor.fromInt(cleaned.length == 6 ? (0xFF000000 | hex) : hex);
      } catch (_) {
        parsed = null;
      }
    }

    return pw.Row(children: [
      pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: parsed ?? PdfColors.grey400, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text('$title: ${colorLabel.isEmpty ? "-" : colorLabel} (${qty.toStringAsFixed(0)})', style: pw.TextStyle(fontSize: 9)),
    ]);
  }
}
