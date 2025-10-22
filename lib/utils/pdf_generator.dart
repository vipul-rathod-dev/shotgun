import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shotgun/screens/admin_screens/order_page/models/order_pdf_data.dart';

class PdfGenerator {
  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No date';
    try {
      if (timestamp is DateTime) {
        return DateFormat.yMMMd().format(timestamp);
      }
      if (timestamp is Map && timestamp.containsKey('seconds')) {
        // Firestore Timestamp (as map)
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp['seconds'] * 1000);
        return DateFormat.yMMMd().format(date);
      }
      return DateFormat.yMMMd().format(timestamp.toDate());
    } catch (_) {
      return 'Invalid date';
    }
  }

  /// 🔹 Main function: generates a PDF from order data
  static Future<Uint8List> generateOrderPdf(OrderPdfData orderData) async {
    final pdf = pw.Document();

    final customerName = orderData.customerName;
    final orderDate = _formatDate(orderData.orderDate);
    final shippingDate = _formatDate(orderData.shippingDate);
    final products = orderData.products as List<dynamic>? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // 🧾 Header
            pw.Center(
              child: pw.Text(
                'Order Summary',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),

            // 🧍 Customer Details
            pw.Text('Customer Name: $customerName',
                style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Order Date: $orderDate',
                style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Shipping Date: $shippingDate',
                style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),

            // 🛒 Product List
            pw.Text('Products:',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            if (products.isEmpty)
              pw.Text('No products found.', style: const pw.TextStyle(color: PdfColors.grey)),

            ...products.map((product) {
              final name = product['productName'] ?? 'Unnamed Product';
              final qty = product['quantity'] ?? 0;
              final customizations =
                  product['customizations'] as List<dynamic>? ?? [];

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$name (Qty: $qty)',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 6),

                    if (customizations.isEmpty)
                      pw.Text('No customizations added.',
                          style: const pw.TextStyle(color: PdfColors.grey)),

                    if (customizations.isNotEmpty)
                      pw.Table(
                        border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                            children: [
                              _headerCell('Focus Color'),
                              _headerCell('Focus Qty'),
                              _headerCell('Temple Color'),
                              _headerCell('Temple Qty'),
                            ],
                          ),
                          ...customizations.map((c) {
                            return pw.TableRow(
                              children: [
                                _cell(c['focusColor'] ?? ''),
                                _cell('${c['focusQty'] ?? 0}'),
                                _cell(c['templeColor'] ?? ''),
                                _cell('${c['templeQty'] ?? 0}'),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // 🔹 Helper widget for table header
  static pw.Widget _headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      );

  // 🔹 Helper widget for table cell
  static pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
      );
}
