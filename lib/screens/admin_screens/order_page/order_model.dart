import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String customerName;
  final String productName;
  final String status; // e.g., "Pending", "Shipped", "Delivered"
  final DateTime date;

  Order({
    required this.id,
    required this.customerName,
    required this.productName,
    required this.status,
    required this.date,
  });

  // Convert Firestore document to an Order object
  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      customerName: data['customerName'] ?? '',
      productName: data['productName'] ?? '',
      status: data['status'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}
