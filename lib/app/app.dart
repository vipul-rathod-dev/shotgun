import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/admin_page.dart';
import 'package:shotgun/screens/admin_screens/order_page/manage_orders.dart';
import 'package:shotgun/screens/admin_screens/manage_suppliers.dart';
import 'package:shotgun/screens/admin_screens/order_page/new_order_page.dart';
import 'package:shotgun/screens/staff_screens/manage_inventory.dart';
import 'package:shotgun/screens/admin_screens/product_page.dart';
import 'package:shotgun/screens/staff_screens/staff_page.dart';
import '../screens/login_page.dart';
import '../screens/register_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth & Firestore',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/admin': (context) => const AdminDashboard(),
        '/staff': (context) => const StaffDashboard(),
        '/admin/products': (context) => const ManageProductPage(),
        '/manage-inventory': (context) => const ManageInventoryPage(),
        '/admin/suppliers': (context) => const ManageSuppliersPage(),
        '/admin/orders': (context) => const ManageOrdersPage(),
        '/admin/orders/new': (context) => const NewMultiProductOrderPage(),
      },
    );
  }
}

