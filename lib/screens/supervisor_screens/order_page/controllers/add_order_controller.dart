import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/models/order_pdf_data.dart';
import 'package:shotgun/utils/pdf_generator.dart';

class AddOrderController extends ChangeNotifier {
  // 🔹 Form keys for different steps
  final List<GlobalKey<FormState>> formKeys = [
    GlobalKey<FormState>(), // Customer Details
    GlobalKey<FormState>(), // Order Details
    GlobalKey<FormState>(), // Products
    GlobalKey<FormState>(), // Color Customizations
  ];

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();

  bool isEditMode = false;
  String? orderId;

  String? customerName;
  String? customerPhone;
  String? brandName;
  DateTime? orderDate;
  DateTime? shippingDate;

  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> productCustomizations = {};

  bool _isInitialized = false;

  String? orderType; // e.g., 'Standard' or 'Customized'

  bool get showColorCustomization => orderType == 'Customized';

  // ────────────────────────────────
  // 🔹 Helper: Get Company ID
  // ────────────────────────────────
  Future<String> _getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('cachedCompanyId');
    if (id == null) throw Exception('No cached company ID found.');
    return id;
  }

  // ────────────────────────────────
  // 🔹 Setters / Updaters
  // ────────────────────────────────
  void setOrderType(String? type) {
    orderType = type;
    if (type == 'Standard') productCustomizations.clear();
    notifyListeners();
  }

  void setCustomerName(String name) {
    customerNameController.text = name;
    customerName = name;
    notifyListeners();
  }

  void setCustomerPhone(String phone) {
    customerPhoneController.text = phone;
    customerPhone = phone;
    notifyListeners();
  }

  void setBrandName(String name) {
    brandNameController.text = name;
    brandName = name;
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
  // 🔹 Customizations
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
      notifyListeners();
    }
  }

  void removeCustomization(String productId, int index) {
    productCustomizations[productId]?.removeAt(index);
    notifyListeners();
  }

  double get total => products.fold<double>(
    0,
    (sum, p) =>
        sum + ((p['price'] ?? 0) * ((p['quantity'] ?? 0) as num).toInt()),
  );

  // ────────────────────────────────
  // 🔹 PDF Generation
  // ────────────────────────────────
  Future<void> generateOrderPdf(BuildContext context) async {
    try {
      final orderData = OrderPdfData(
        customerName: customerName ?? '-',
        customerPhone: customerPhone ?? '-',
        orderDate: orderDate,
        shippingDate: shippingDate,
        products: products,
        productCustomizations: productCustomizations,
      );
      final pdf = await PdfGenerator.generateOrderPdf(orderData);
      await Printing.layoutPdf(onLayout: (format) async => pdf);

      _showSnack(context, '✅ PDF generated successfully', color: Colors.green);
    } catch (e, stack) {
      debugPrint('❌ PDF Generation Error: $e');
      debugPrint(stack.toString());
      _showSnack(context, 'Error generating PDF: $e', color: Colors.red);
    }
  }

  // ────────────────────────────────
  // 🔹 Generate Order Number (Company Scoped)
  // ────────────────────────────────
  Future<String> _getNextOrderNumber() async {
    final companyId = await _getCompanyId();
    final counterRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('metadata')
        .doc('order_counter');

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
      final companyId = await _getCompanyId();
      final orderNumber = await _getNextOrderNumber();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Missing user info.');
      }

      final finalProducts =
          products.map((p) {
            final customizations = productCustomizations[p['productId']] ?? [];
            return {
              'productId': p['productId'],
              'productName': p['productName'],
              'quantity': p['quantity'],
              'price': p['price'],
              'lineTotal': (p['quantity'] ?? 0) * (p['price'] ?? 0),
              'customizations':
                  customizations
                      .map(
                        (c) => {
                          'focusColorId': c['focusColorId'],
                          'focusColor': c['focusColor'],
                          'focusQty': c['focusQty'],
                          'templeColorId': c['templeColorId'],
                          'templeColor': c['templeColor'],
                          'templeQty': c['templeQty'],
                        },
                      )
                      .toList(),
            };
          }).toList();

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('orders')
          .add({
            'orderNumber': orderNumber,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'brandName': brandName,
            'orderDate': Timestamp.fromDate(orderDate!),
            'shippingDate': Timestamp.fromDate(shippingDate!),
            'products': finalProducts,
            'totalAmount': total,
            'orderType': orderType,
            'orderStatus': 'Received',
            'timestamp': FieldValue.serverTimestamp(),
            'createdByUid': user.uid,
            'createdByEmail': user.email,
          });

      _showSnack(
        context,
        '✅ Order #$orderNumber submitted successfully!',
        color: Colors.green,
      );

      // Reset state
      products.clear();
      productCustomizations.clear();
      customerName = null;
      customerPhone = null;
      brandName = null;
      orderType = null;
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
  // 🔹 Edit Mode Initialization
  // ────────────────────────────────
  Future<void> initEditMode(bool editMode, String? id) async {
    if (!editMode || id == null || _isInitialized) return;

    isEditMode = editMode;
    orderId = id;
    final companyId = await _getCompanyId();

    final doc =
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('orders')
            .doc(id)
            .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    customerNameController.text = data['customerName'] ?? '';
    customerPhoneController.text = data['customerPhone'] ?? '';
    brandNameController.text = data['brandName'] ?? '';
    customerName = data['customerName'];
    customerPhone = data['customerPhone'];
    brandName = data['brandName'];
    orderType = data['orderType'] ?? 'Standard';
    orderDate = (data['orderDate'] as Timestamp?)?.toDate();
    shippingDate = (data['shippingDate'] as Timestamp?)?.toDate();

    products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    for (var p in products) {
      final pid = p['productId'];
      productCustomizations[pid] = List<Map<String, dynamic>>.from(
        p['customizations'] ?? [],
      );
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ────────────────────────────────
  // 🔹 Save (Update) Order
  // ────────────────────────────────
  Future<void> saveOrder(BuildContext context) async {
    final companyId = await _getCompanyId();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Missing user info.');
    }

    final finalProducts =
        products.map((p) {
          final pid = p['productId'];
          final customizations = productCustomizations[pid] ?? [];
          return {
            'productId': pid,
            'productName': p['productName'],
            'quantity': p['quantity'],
            'price': p['price'],
            'lineTotal': (p['quantity'] ?? 0) * (p['price'] ?? 0),
            'customizations': customizations,
          };
        }).toList();

    final orderData = {
      'customerName': customerNameController.text.trim(),
      'customerPhone': customerPhoneController.text.trim(),
      'brandName': brandNameController.text.trim(),
      'orderType': orderType,
      'orderDate': Timestamp.fromDate(orderDate ?? DateTime.now()),
      'shippingDate': Timestamp.fromDate(shippingDate ?? DateTime.now()),
      'products': finalProducts,
      'totalAmount': total,
      'timestamp': FieldValue.serverTimestamp(),
      'createdByUid': user.uid,
      'createdByEmail': user.email,
    };

    try {
      final collection = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('orders');

      if (isEditMode && orderId != null) {
        await collection.doc(orderId).update(orderData);
      } else {
        final orderNumber = await _getNextOrderNumber();
        await collection.add({
          ...orderData,
          'orderNumber': orderNumber,
          'orderStatus': 'Received',
        });
      }

      notifyListeners();

      if (context.mounted) {
        Navigator.pop(context);
        _showSnack(
          context,
          isEditMode
              ? '✅ Order updated successfully!'
              : '✅ Order added successfully!',
          color: Colors.green,
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving order: $e');
      _showSnack(context, 'Error saving order: $e', color: Colors.red);
    }
  }

  // ────────────────────────────────
  // 🔹 Helper: SnackBar
  // ────────────────────────────────
  void _showSnack(
    BuildContext context,
    String msg, {
    Color color = Colors.black87,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
