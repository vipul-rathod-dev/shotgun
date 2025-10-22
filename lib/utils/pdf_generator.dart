import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<pw.Document> generateOrderPdf({
    required String customerName,
    required String customerPhone,
    required DateTime? orderDate,
    required DateTime? shippingDate,
    required List<Map<String, dynamic>> products,
    required Map<String, List<Map<String, dynamic>>> productCustomizations,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    final orderDateStr = orderDate != null ? dateFormat.format(orderDate) : '-';
    final shippingDateStr =
        shippingDate != null ? dateFormat.format(shippingDate) : '-';

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              'Order Summary',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // Customer Info
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Customer Name: $customerName'),
                pw.Text('Phone Number: $customerPhone'),
                pw.Text('Order Date: $orderDateStr'),
                pw.Text('Shipping Date: $shippingDateStr'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Products',
            style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          ...products.map((p) {
            final qty = p['quantity'] ?? 0;
            final price = p['price'] ?? 0.0;
            final total = qty * price;
            final productId = p['productId'];
            final productCustoms = productCustomizations[productId] ?? [];

            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        p['productName'] ?? '-',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14),
                      ),
                      pw.Text('Qty: $qty'),
                      pw.Text('₹${price.toStringAsFixed(2)}'),
                      pw.Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800),
                      ),
                    ],
                  ),
                  if (productCustoms.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Color Customizations:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Focus Colours',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text(
                                'Temple Colours',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.Divider(),
                          ...productCustoms.map((c) {
                            final colorName = c['colorName'] ?? '-';
                            final colorQty = c['colorQty'] ?? 0;
                            final templeName = c['templeName'] ?? '-';
                            final templeQty = c['templeQty'] ?? 0;
                            return pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                    '🎨 $colorName (x$colorQty)',
                                    style: const pw.TextStyle(fontSize: 11)),
                                pw.Text(
                                    '🏛 $templeName (x$templeQty)',
                                    style: const pw.TextStyle(fontSize: 11)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );

    return pdf;
  }
}
