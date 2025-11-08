import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/models/order_pdf_data.dart';

class PdfGenerator {
  static Future<Uint8List> generateOrderPdf(OrderPdfData data) async {
    final pdf = pw.Document();

    String fmtDate(DateTime? date) =>
        date == null ? '-' : DateFormat('dd MMM yyyy').format(date);

    // 🧩 Build products map for lookup
    final Map<String, Map<String, dynamic>> productsMap = {
      for (var p in data.products)
        (p['productId'] ?? '').toString(): p,
    };

    // 🧮 Build base material summary
    final Map<String, Map<String, Map<String, int>>> baseMaterialSummary = {};
    if (data.productCustomizations == null) {
      // 🧮 Build base material summary
      for (var entry in data.products) {
        final productId = entry['productId'];
        final productName = productsMap[productId]?['productName'] ?? 'Unknown Product';
        final customizations = productsMap[productId]?['customizations'];

        for (final c in customizations) {
          final base = (c['focusBaseMaterial'] ?? 'Unknown').toString();
          final focusQty = (c['focusQty'] ?? 0) as int;
          final templeQty = (c['templeQty'] ?? 0) as int;

          baseMaterialSummary.putIfAbsent(base, () => {});
          baseMaterialSummary[base]!.putIfAbsent(productName, () => {'focus': 0, 'temple': 0});

          baseMaterialSummary[base]![productName]!['focus'] =
              (baseMaterialSummary[base]![productName]!['focus'] ?? 0) + focusQty;
          baseMaterialSummary[base]![productName]!['temple'] =
              (baseMaterialSummary[base]![productName]!['temple'] ?? 0) + templeQty;
        }
      }
    } else {
      for (final entry in data.productCustomizations!.entries) {
        final productId = entry.key;
        final productName = productsMap[productId]?['productName'] ?? 'Unknown Product';
        final customizations = entry.value;

        for (final c in customizations) {
          final base = (c['focusBaseMaterial'] ?? 'Unknown').toString();
          final focusQty = (c['focusQty'] ?? 0) as int;
          final templeQty = (c['templeQty'] ?? 0) as int;

          baseMaterialSummary.putIfAbsent(base, () => {});
          baseMaterialSummary[base]!.putIfAbsent(productName, () => {'focus': 0, 'temple': 0});

          baseMaterialSummary[base]![productName]!['focus'] =
              (baseMaterialSummary[base]![productName]!['focus'] ?? 0) + focusQty;
          baseMaterialSummary[base]![productName]!['temple'] =
              (baseMaterialSummary[base]![productName]!['temple'] ?? 0) + templeQty;
        }
      }
    }

    final total = data.products.fold<double>(
      0,
      (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)),
    );

    // 🖨️ PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'ORDER SUMMARY',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),

          // 🔹 Customer Info
          pw.Text('Customer: ${data.customerName}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Phone: ${data.customerPhone}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Order Date: ${fmtDate(data.orderDate)}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Shipping Date: ${fmtDate(data.shippingDate)}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),

          // 🔹 Product Table
          pw.Text('Products',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey500),
            headers: ['Product', 'Qty', 'Price', 'Total'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellAlignment: pw.Alignment.centerLeft,
            data: data.products
                .map((p) => [
                      p['productName'] ?? '-',
                      (p['quantity'] ?? 0).toString(),
                      'Rs.${p['price']}',
                      'Rs.${((p['price'] ?? 0) * (p['quantity'] ?? 0)).toStringAsFixed(2)}',
                      // '₹${p['price']}',
                      // '₹${((p['price'] ?? 0) * (p['quantity'] ?? 0)).toStringAsFixed(2)}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),

          // 🔹 Base Material Summary
          if (baseMaterialSummary.isNotEmpty) ...[
            pw.Text('Focus & Temple Summary by Base Material',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            ...baseMaterialSummary.entries.map((baseEntry) {
              final base = baseEntry.key;
              final productEntries = baseEntry.value;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(base,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800)),
                  pw.Table.fromTextArray(
                    border: pw.TableBorder.all(width: 0.2, color: PdfColors.grey500),
                    headers: ['Product', 'Focus Qty', 'Temple Qty'],
                    headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                    data: productEntries.entries
                        .map((e) => [
                              e.key,
                              e.value['focus'].toString(),
                              e.value['temple'].toString()
                            ])
                        .toList(),
                  ),
                  pw.SizedBox(height: 12),
                ],
              );
            }),
          ],

          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            // child: pw.Text('Grand Total: ₹${total.toStringAsFixed(2)}',
            child: pw.Text('Grand Total: Rs.${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateSimpleTextPdf({
    required String title,
    required String content,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text(content, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    return pdf.save();
  }

}
