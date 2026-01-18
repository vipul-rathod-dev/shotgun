import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/models/order_pdf_data.dart';
import 'package:shotgun/utils/pdf_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
  Map<String, int> boxQuantity = {};
  String? gentsDefaultTemplate;
  String? ladiesDefaultTemplate;
  String? babyDefaultTemplate;
  String? selectedCustomerId;
  ValueNotifier<String?> orderTypeNotifier = ValueNotifier(null);

  void setOrderType(String? type) {
    orderTypeNotifier.value = type;
    orderType = type;
    if (orderType == 'Stock') productCustomizations.clear();
  }

  void setSelectedCustomer(String? id) {
    selectedCustomerId = id;
  }

  // ────────────────────────────────
  // 🔹 Helper: Get Company ID
  // ────────────────────────────────
  Future<String> _getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('cachedCompanyId');
    if (id == null) throw Exception('No cached company ID found.');
    return id;
  }

  void setDefaultTemplates(Map<String, dynamic>? templates) {
    gentsDefaultTemplate = templates?['gents'];
    ladiesDefaultTemplate = templates?['ladies'];
    babyDefaultTemplate = templates?['baby'];
  }


  // ────────────────────────────────
  // 🔹 Setters / Updaters
  // ────────────────────────────────
  // void setOrderType(String? type) {
  //   orderType = type;
  //   if (type == 'Stock') productCustomizations.clear();
  //   notifyListeners();
  // }

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
  void addCustomization(String gender, Map<String, dynamic> customization) {
    if (!productCustomizations.containsKey(gender)) {
      productCustomizations[gender] = [];
    }
    productCustomizations[gender]!.add(customization);
    _updateBoxQuantity(gender);
    notifyListeners();
  }

  void updateCustomization(String gender, int index, Map<String, dynamic> newData) {
    if (productCustomizations.containsKey(gender) &&
        index < productCustomizations[gender]!.length) {
      productCustomizations[gender]![index] = newData;
      _updateBoxQuantity(gender);
      notifyListeners();
    }
  }

  void removeCustomization(String gender, int index) {
    if (productCustomizations.containsKey(gender) &&
        index < productCustomizations[gender]!.length) {
      productCustomizations[gender]!.removeAt(index);
      _updateBoxQuantity(gender);
      notifyListeners();
    }
  }

  void _updateBoxQuantity(String gender) {
    final entries = productCustomizations[gender] ?? [];
    final total = entries.fold<int>(
      0,
      (sum1, e) => sum1 + (int.tryParse(e['focusQty']?.toString() ?? '0') ?? 0),
    );
    boxQuantity[gender] = total;
  }

  double get total => products.fold<double>(
    0,
    (sum1, p) =>
        sum1 + ((p['price'] ?? 0) * ((p['quantity'] ?? 0) as num).toInt()),
  );

  // ────────────────────────────────
  // 🔹 PDF Generation
  // ────────────────────────────────
  Future<void> generateOrderPdf(BuildContext context, {bool shareInstead = false}) async {
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

      // 🪄 Save PDF temporarily
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/order_summary.pdf');
      await file.writeAsBytes(pdf);

      if (shareInstead) {
        await Share.shareXFiles([XFile(file.path)], text: 'Order Summary PDF');
        _showSnack(context, '✅ PDF shared successfully', color: Colors.green);
      } else {
        // fallback to preview
        await Printing.layoutPdf(onLayout: (format) async => pdf);
      }
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
  Future<void> submitOrder1(BuildContext context) async {
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
              'focusBaseMaterialQuantities': p['focusBaseMaterialQuantities'],
              'templeBaseMaterialQuantities': p['templeBaseMaterialQuantities'],
              'customizations':
                  customizations
                      .map(
                        (c) => {
                          'focusColorId': c['focusColorId'],
                          'focusColor': c['focusColor'],
                          'focusQty': c['focusQty'],
                          'focusBaseMaterial': c['focusBaseMaterial'],
                          'templeColorId': c['templeColorId'],
                          'templeColor': c['templeColor'],
                          'templeQty': c['templeQty'],
                          'templeBaseMaterial': c['templeBaseMaterial'],
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
      if (user == null) throw Exception('Missing user info.');

      final finalProducts = products.map((p) {
        final pid = p['productId'];
        return {
          'productId': pid,
          'productName': p['productName'],
          'quantity': p['quantity'],
          'price': p['price'],
          'lineTotal': (p['quantity'] ?? 0) * (p['price'] ?? 0),
          'modelGender': p['modelGender'],
          'focusBaseMaterialQuantities': p['focusBaseMaterialQuantities'],
          'templeBaseMaterialQuantities': p['templeBaseMaterialQuantities'],
        };
      }).toList();

      // 🔹 Firestore-safe deep copies
      final safeBoxQuantity = Map<String, dynamic>.from(boxQuantity);
      final safeCustomizations = productCustomizations.map(
        (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
      );

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
            'boxQuantity': safeBoxQuantity,
            'productCustomizations': safeCustomizations,
            'timestamp': FieldValue.serverTimestamp(),
            'createdByUid': user.uid,
            'createdByEmail': user.email,
          });

      _showSnack(context, '✅ Order #$orderNumber submitted successfully!',
          color: Colors.green);

      products.clear();
      productCustomizations.clear();
      boxQuantity.clear();
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
  void initEditMode({
    required bool isEditMode,
    String? orderId,
    String? companyId,
  }) async {
    if (!isEditMode || orderId == null || _isInitialized) return;

    // ✅ Ensure widget is still mounted before doing async operations
    await Future.delayed(Duration.zero);
    if (!isEditMode) return;

    // ✅ Use passed companyId OR fallback to prefs
    final cid = companyId ?? await _getCompanyId();
    if (cid.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(cid)
        .collection('orders')
        .doc(orderId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    // -------------------------------
    // 🔹 Restore Basic Fields
    // -------------------------------
    customerNameController.text = data['customerName'] ?? '';
    customerPhoneController.text = data['customerPhone'] ?? '';
    brandNameController.text = data['brandName'] ?? '';

    customerName = data['customerName'];
    customerPhone = data['customerPhone'];
    brandName = data['brandName'];
    orderType = data['orderType'] ?? 'Stock';

    orderDate = (data['orderDate'] as Timestamp?)?.toDate();
    shippingDate = (data['shippingDate'] as Timestamp?)?.toDate();

    // -------------------------------
    // 🔹 Restore Products
    // -------------------------------
    products = List<Map<String, dynamic>>.from(data['products'] ?? []);

    // -------------------------------
    // 🔹 Restore gender-level customizations
    // -------------------------------
    if (data.containsKey('productCustomizations')) {
      productCustomizations.clear();
      (data['productCustomizations'] as Map).forEach((key, value) {
        productCustomizations[key.toString()] =
            List<Map<String, dynamic>>.from(value ?? []);
      });
    }

    // -------------------------------
    // 🔹 Restore Box Quantities
    // -------------------------------
    if (data.containsKey('boxQuantity')) {
      boxQuantity.clear();
      (data['boxQuantity'] as Map).forEach((key, value) {
        boxQuantity[key.toString()] = (value as num).toInt();
      });
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

    final safeBoxQuantity = Map<String, dynamic>.from(boxQuantity);
    final safeCustomizations = productCustomizations.map(
      (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
    );

    final finalProducts =
        products.map((p) {
          final pid = p['productId'];
          return {
            'productId': pid,
            'productName': p['productName'],
            'quantity': p['quantity'],
            'price': p['price'],
            'lineTotal': (p['quantity'] ?? 0) * (p['price'] ?? 0),
            'modelGender': p['modelGender'],
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
      'boxQuantity': safeBoxQuantity,
      'productCustomizations': safeCustomizations,
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

extension OrderPdfGenerator on AddOrderController {
  Future<void> generateOrderPdf1(BuildContext context, {bool shareInstead = false}) async {
    final pdf = pw.Document();

    final total = products.fold<double>(0, (sum1, p) => sum1 + ((p['price'] ?? 0) * (p['quantity'] ?? 0)));
    final DateFormat fmt = DateFormat('dd MMM yyyy');

    // Group products by gender
    final Map<String, List<Map<String, dynamic>>> genderGroups = {};
    for (final p in products) {
      final gender = (p['modelGender'] ?? 'Unknown').toString();
      genderGroups.putIfAbsent(gender, () => []);
      genderGroups[gender]!.add(p);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.robotoRegular(),
            bold: await PdfGoogleFonts.robotoBold(),
          ),
        ),
        build: (context) => [
          pw.Text('Order Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),

          _infoRow('Customer', customerName ?? '-'),
          _infoRow('Phone Number', customerPhone ?? '-'),
          _infoRow('Brand Name', brandName ?? '-'),
          _infoRow('Order Date', orderDate == null ? '-' : fmt.format(orderDate!)),
          _infoRow('Shipping Date', shippingDate == null ? '-' : fmt.format(shippingDate!)),

          pw.SizedBox(height: 15),
          pw.Text('Products by Gender', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),

          if (products.isEmpty)
            pw.Text('No products added.', style: pw.TextStyle(color: PdfColors.grey))
          else
            ...genderGroups.entries.map((entry) {
              final gender = entry.key;
              final productList = entry.value;
              final genderCustomizations = productCustomizations[gender] ?? [];
              final genderBoxQty = (boxQuantity[gender] ?? 0);

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(gender,
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      children: productList.map((p) {
                        final qty = (p['quantity'] ?? 0) as int;
                        final price = (p['price'] ?? 0).toDouble();
                        final total = (qty * price).toStringAsFixed(2);
                        final ratio = genderBoxQty > 0 ? (qty / genderBoxQty) : 0.0;

                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Text(p['productName'] ?? '-',
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold, fontSize: 13)),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Text('Qty: $qty',
                                      textAlign: pw.TextAlign.center,
                                      style: const pw.TextStyle(fontSize: 12)),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Text('₹$price',
                                      textAlign: pw.TextAlign.center,
                                      style: const pw.TextStyle(fontSize: 12)),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Text('₹$total',
                                      textAlign: pw.TextAlign.right,
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.green)),
                                ),
                              ],
                            ),
                            if (genderCustomizations.isNotEmpty) ...[
                              pw.SizedBox(height: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(6),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: PdfColors.grey300),
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Color Customizations',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                    pw.SizedBox(height: 4),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      color: PdfColors.grey200,
                                      child: pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('🎯 Focus Color', style: const pw.TextStyle(fontSize: 11)),
                                          pw.Text('🏛 Temple Color',
                                              style: const pw.TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    ...genderCustomizations.map((c) {
                                      final focusColor = c['focusColor'] ?? '-';
                                      final focusQty = ((c['focusQty'] ?? 0) * ratio).toStringAsFixed(1);
                                      final templeColor = c['templeColor'] ?? '-';
                                      final templeQty = ((c['templeQty'] ?? 0) * ratio).toStringAsFixed(1);
                                      return pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('$focusColor = $focusQty',
                                              style: const pw.TextStyle(fontSize: 11)),
                                          pw.Text('$templeColor = $templeQty',
                                              style: const pw.TextStyle(fontSize: 11)),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                            pw.SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],
              );
            }),

          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Grand Total:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('₹${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (shareInstead) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Order_Summary_${customerName ?? ''}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
      );
    }
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
