class OrderModel {
  final String customerName;
  final String customerPhone;
  final DateTime orderDate;
  final DateTime shippingDate;
  final List<Map<String, dynamic>> products;

  OrderModel({
    required this.customerName,
    required this.customerPhone,
    required this.orderDate,
    required this.shippingDate,
    required this.products,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'customerEmail': customerPhone,
      'orderDate': orderDate.toIso8601String(),
      'shippingDate': shippingDate.toIso8601String(),
      'products': products,
    };
  }
}
