import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/utils/pdf_generator.dart';
import 'package:printing/printing.dart';

class AddOrderController extends ChangeNotifier {
  // 🔹 Form keys for different steps
  final List<GlobalKey<FormState>> formKeys = [
    GlobalKey<FormState>(), // Customer Details
    GlobalKey<FormState>(), // Order Details
    GlobalKey<FormState>(), // Products
    GlobalKey<FormState>(), // Color Customizations
  ];

  String? customerName;
  String? customerPhone;
  DateTime? orderDate;
  DateTime? shippingDate;

  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> productCustomizations = {};

  // ────────────────────────────────
  // 🔹 Update Methods
  // ────────────────────────────────
  void setCustomerName(String name) {
    customerName = name;
    notifyListeners();
  }

  void setCustomerPhone(String phone) {
    customerPhone = phone;
    notifyListeners();
  }

  void setOrderDate(DateTime date) {
    orderDate = date;
    notifyListeners();
  }

  void setShippingDate(DateTime date) {
    shippingDate = date;
    notifyListeners();
  }

  // ────────────────────────────────
  // 🔹 Product Handling
  // ────────────────────────────────
  void addProduct(Map<String, dynamic> product) {
    products.add(product);
    notifyListeners();
  }

  void removeProduct(Map<String, dynamic> product) {
    products.removeWhere((p) => p['productId'] == product['productId']);
    notifyListeners();
  }

  // ────────────────────────────────
  // 🔹 Customization Handling
  // ────────────────────────────────
  void addCustomization(String productId, Map<String, dynamic> data) {
    productCustomizations.putIfAbsent(productId, () => []).add(data);
    notifyListeners();
  }

  void updateCustomization(
    String productId,
    int index,
    Map<String, dynamic> newData,
  ) {
    if (productCustomizations[productId] != null &&
        index >= 0 &&
        index < productCustomizations[productId]!.length) {
      productCustomizations[productId]![index] = newData;
      notifyListeners(); // ensures SummarySection rebuilds
    }
  }

  void removeCustomization(String productId, int index) {
    if (productCustomizations[productId] != null) {
      productCustomizations[productId]!.removeAt(index);
      notifyListeners();
    }
  }

  double get total {
    return products.fold<double>(
      0,
      (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)),
    );
  }

  // ────────────────────────────────
  // 🔹 PDF Generation
  // ────────────────────────────────
  Future<void> generateOrderPdf(BuildContext context) async {
    try {
      final pdf = await PdfGenerator.generateOrderPdf(
        customerName: customerName ?? '-',
        customerPhone: customerPhone ?? '-',
        orderDate: orderDate,
        shippingDate: shippingDate,
        products: products,
        productCustomizations: productCustomizations,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      _showSnack(context, '✅ PDF generated successfully', color: Colors.green);

    } catch (e, stack) {
      debugPrint('❌ PDF Generation Error: $e');
      debugPrint(stack.toString());
      _showSnack(context, 'Error generating PDF: $e', color: Colors.red);
    }
  }

  Future<String> _getNextOrderNumber() async {
    final counterRef = FirebaseFirestore.instance.collection('metadata').doc('order_counter');
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int nextNumber = 1;
      if (snapshot.exists) {
        nextNumber = (snapshot.data()?['lastOrderNumber'] ?? 0) + 1;
      }

      transaction.set(counterRef, {'lastOrderNumber': nextNumber});

      final year = DateTime.now().year;
      return 'ORD-$year-${nextNumber.toString().padLeft(4, '0')}';
    });
  }

  // ────────────────────────────────
  // 🔹 Submit Order
  // ────────────────────────────────
  Future<void> submitOrder(BuildContext context) async {
    if (customerName == null || customerName!.isEmpty) {
      _showSnack(context, 'Please enter customer name');
      return;
    }

    if (products.isEmpty) {
      _showSnack(context, 'Please add at least one product');
      return;
    }

    if (orderDate == null || shippingDate == null) {
      _showSnack(context, 'Please select order and shipping dates');
      return;
    }

    if (shippingDate!.isBefore(orderDate!)) {
      _showSnack(context, 'Shipping date cannot be before order date');

      return;
    }

    try {
      final orderNumber = await _getNextOrderNumber();

      // 🧾 Build final products list
      final List<Map<String, dynamic>> finalProducts = products.map((product) {
        final productId = product['productId'];
        final customizations = productCustomizations[productId] ?? [];
        return {
          'productId': productId,
          'productName': product['productName'],
          'quantity': product['quantity'],
          'price': product['price'],
          'lineTotal': (product['quantity'] ?? 0) * (product['price'] ?? 0),
          'customizations': customizations.map((c) => {
                'colorName': c['colorName'],
                'colorQty': c['colorQty'],
                'templeName': c['templeName'],
                'templeQty': c['templeQty'],
              }).toList(),
        };
      }).toList();

      await FirebaseFirestore.instance.collection('orders').add({
        'orderNumber': orderNumber,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'orderDate': Timestamp.fromDate(orderDate!),
        'shippingDate': Timestamp.fromDate(shippingDate!),
        'products': finalProducts,
        'totalAmount': total,
        'orderStatus': 'Yet to Start',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnack(context, '✅ Order #$orderNumber submitted successfully!', color: Colors.green);

      // Optional: Clear data after submission
      products.clear();
      productCustomizations.clear();
      customerName = null;
      customerPhone = null;
      orderDate = null;
      shippingDate = null;
      notifyListeners();
    } catch (e, stack) {
      debugPrint("❌ Order submission failed: $e");
      debugPrint(stack.toString());
      _showSnack(context, 'Order submission failed: $e', color: Colors.red);

    }
  }

  // ────────────────────────────────
  // 🔹 Helper: SnackBar
  // ────────────────────────────────
  void _showSnack(BuildContext context, String msg, {Color color = Colors.black87}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
