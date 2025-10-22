import 'package:cloud_firestore/cloud_firestore.dart';

class OrderPdfData {
  final String customerName;
  final String customerPhone;
  final DateTime? orderDate;
  final DateTime? shippingDate;
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? productCustomizations;

  OrderPdfData({
    required this.customerName,
    required this.customerPhone,
    this.orderDate,
    this.shippingDate,
    required this.products,
    this.productCustomizations,
  });

  factory OrderPdfData.fromMap(Map<String, dynamic> data) {
    return OrderPdfData(
      customerName: data['customerName'] ?? '-',
      customerPhone: data['customerPhone'] ?? '-',
      orderDate: (data['orderDate'] is Timestamp)
          ? (data['orderDate'] as Timestamp).toDate()
          : data['orderDate'] as DateTime?,
      shippingDate: (data['shippingDate'] is Timestamp)
          ? (data['shippingDate'] as Timestamp).toDate()
          : data['shippingDate'] as DateTime?,
      products: (data['products'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      productCustomizations:
          (data['productCustomizations'] != null)
              ? Map<String, dynamic>.from(data['productCustomizations'])
              : null,
    );
  }

  /// Convert to map (for saving back to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'orderDate': orderDate,
      'shippingDate': shippingDate,
      'products': products,
      if (productCustomizations != null)
        'productCustomizations': productCustomizations,
    };
  }
}
