import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrackOrdersController {
  /// Stream of all orders sorted by date
  Stream<QuerySnapshot> get ordersStream => FirebaseFirestore.instance
      .collection('orders')
      .orderBy('orderDate', descending: true)
      .snapshots();

  /// Dark mode check
  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Background color adaptive to theme
  Color backgroundColor(BuildContext context) =>
      isDarkMode(context) ? Colors.grey.shade900 : Colors.grey.shade100;
}
