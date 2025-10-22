import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shotgun/screens/admin_screens/order_page/models/order_model.dart';

class OrderPdfService {
  static Future<void> generateOrderPdf(OrderModel order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Order Summary', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.Text('Customer: ${order.customerName}'),
            pw.Text('Phone: ${order.customerPhone}'),
            pw.Text('Order Date: ${order.orderDate.toLocal()}'),
            pw.Text('Shipping Date: ${order.shippingDate.toLocal()}'),
            pw.SizedBox(height: 20),
            pw.Text('Products:'),
            pw.TableHelper.fromTextArray(
              headers: ['Name', 'Quantity', 'Price'],
              data: order.products
                  .map((p) => [
                        p['name'] ?? '',
                        p['quantity'].toString(),
                        p['price'].toString()
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
