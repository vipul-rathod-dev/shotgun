import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/admin_page.dart';
import 'package:shotgun/screens/admin_screens/create_company_page.dart';
import 'package:shotgun/screens/admin_screens/view_companies_page.dart';
import 'package:shotgun/screens/supervisor_screens/supervisor_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_suppliers.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/manage_orders.dart';
import 'package:shotgun/screens/auth_screens/login_page.dart';
import 'package:shotgun/screens/staff_screens/manage_inventory/manage_inventory_page.dart';
import 'package:shotgun/screens/staff_screens/order_details/order_details_page.dart';
import 'package:shotgun/screens/supervisor_screens/product_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/color_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/demo_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/fitting_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/packing_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/quality_check_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/raw_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/shipping_process_page.dart';
import 'package:shotgun/screens/staff_screens/staff_page.dart';
import 'package:shotgun/screens/staff_screens/track_orders/track_orders_page.dart';
import '../screens/supervisor_screens/order_page/add_orders_page.dart';
import '../screens/register_page.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shotgun App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/admin': (context) => const AdminDashboard(),
        '/admin/create-company': (context) => const CreateCompanyPage(),
        '/admin/view-companies': (context) => const ViewCompaniesPage(),
        '/supervisor': (context) => const SupervisorDashboard(),
        '/staff': (context) => const StaffDashboard(),
        '/admin/products': (context) => const ManageProductPage(),
        '/manage-inventory': (context) => const ManageInventoryPage(),
        '/admin/suppliers': (context) => const ManageSuppliersPage(),
        '/admin/orders': (context) => const ManageOrdersPage(),
        '/admin/orders/new': (context) => const AddOrdersPage(),
        '/admin/orders/edit': (context) => const AddOrdersPage(isEditMode: true),
        '/orders': (context) => const TrackOrdersPage(),
        '/order-details': (context) => const OrderDetailsPage(),
        '/staff/rawProcess': (context) => const RawProcessPage(),
        '/staff/colorProcess': (context) => const ColorProcessPage(),
        '/staff/qualityCheck': (context) => const QualityCheckPage(),
        '/staff/fittingProcess': (context) => const FittingProcessPage(),
        '/staff/demoProcess': (context) => const DemoProcessPage(),
        '/staff/packing': (context) => const PackingPage(),
        '/staff/shipping': (context) => const ShippingPage(),
      },
    );
  }
}

