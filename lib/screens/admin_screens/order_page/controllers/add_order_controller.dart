import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/order_page/models/order_pdf_data.dart';
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

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();

  bool isEditMode = false;
  String? orderId;

  String? customerName;
  String? customerPhone;
  DateTime? orderDate;
  DateTime? shippingDate;

  List<Map<String, dynamic>> products = [];
  Map<String, List<Map<String, dynamic>>> productCustomizations = {};

  bool _isInitialized = false;

  // ────────────────────────────────
  // 🔹 Update Methods
  // ────────────────────────────────
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
                'focusColorId': c['focusColorId'],
                'focusColor': c['focusColor'],
                'focusQty': c['focusQty'],
                'templeColorId': c['templeColorId'],
                'templeColor': c['templeColor'],
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

  Future<void> initEditMode(bool editMode, String? id) async {
    if (!editMode || id == null || _isInitialized) return;

    isEditMode = editMode;
    orderId = id;

    final doc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    customerNameController.text = data['customerName'] ?? '';
    customerPhoneController.text = data['customerPhone'] ?? '';
    customerName = data['customerName'] ?? '';
    customerPhone = data['customerPhone'] ?? '';

    orderDate = (data['orderDate'] as Timestamp?)?.toDate();
    shippingDate = (data['shippingDate'] as Timestamp?)?.toDate();

    products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    // if customizations are nested inside products:
    for (var p in products) {
      final productId = p['productId'];
      final customList = List<Map<String, dynamic>>.from(p['customizations'] ?? []);
      productCustomizations[productId] = customList;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> saveOrder(BuildContext context) async {
    // Build final products list using productCustomizations
    final List<Map<String, dynamic>> finalProducts = products.map((product) {
      final productId = product['productId'];
      final customizations = productCustomizations[productId] ?? [];

      return {
        'productId': productId,
        'productName': product['productName'],
        'quantity': product['quantity'],
        'price': product['price'],
        'lineTotal': (product['quantity'] ?? 0) * (product['price'] ?? 0),
        // include customizations (each with IDs and names & qty)
        'customizations': customizations.map((c) {
          return {
            'focusColorId': c['focusColorId'],
            'focusColor': c['focusColor'],
            'focusQty': c['focusQty'],
            'templeColorId': c['templeColorId'],
            'templeColor': c['templeColor'],
            'templeQty': c['templeQty'],
          };
        }).toList(),
      };
    }).toList();

    final orderData = {
      'customerName': customerNameController.text.trim(),
      'customerPhone': customerPhoneController.text.trim(),
      'orderDate': Timestamp.fromDate(orderDate ?? DateTime.now()),
      'shippingDate': Timestamp.fromDate(shippingDate ?? DateTime.now()),
      'products': finalProducts,
      'totalAmount': total,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      final collection = FirebaseFirestore.instance.collection('orders');

      if (isEditMode && orderId != null) {
        // Update existing doc with merged products+customizations
        await collection.doc(orderId).update(orderData);
      } else {
        // New order -> assign order number and create
        final orderNumber = await _getNextOrderNumber();
        await collection.add({
          ...orderData,
          'orderNumber': orderNumber,
          'orderStatus': 'Yet to Start',
        });
      }

      // Optional: reflect merged products back into controller.products so local state matches DB
      products = List<Map<String, dynamic>>.from(finalProducts);
      // And rebuild productCustomizations from finalProducts for consistency
      productCustomizations.clear();
      for (var p in products) {
        final pid = p['productId'];
        finalListToMapSafe(p['customizations']);
        productCustomizations[pid] =
            List<Map<String, dynamic>>.from(p['customizations'] ?? []);
      }

      notifyListeners();

      if (context.mounted) {
        Navigator.pop(context);
        _showSnack(
          context,
          isEditMode ? '✅ Order updated successfully!' : '✅ Order added successfully!',
          color: Colors.green,
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving order: $e');
      _showSnack(context, 'Error saving order: $e', color: Colors.red);
    }
  }

  // small helper to normalize null customizations
  void finalListToMapSafe(dynamic customizations) {
    // no-op helper to make code readable (keeps dynamic handling stable)
    // If you prefer, remove helper and handle nulls inline
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
