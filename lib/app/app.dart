import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/admin_page.dart';
import 'package:shotgun/screens/admin_screens/create_company_page.dart';
import 'package:shotgun/screens/admin_screens/view_companies_page.dart';
import 'package:shotgun/screens/auth_screens/company_login_page.dart';
import 'package:shotgun/screens/staff_screens/assigned_task_page/assigned_task_page.dart';
import 'package:shotgun/screens/staff_screens/execute_process_page/execute_process_page.dart';
// import 'package:shotgun/screens/staff_screens/tasks_page/tasks_page.dart';
import 'package:shotgun/screens/supervisor_screens/add_colors_fab/add_focus_color.dart';
import 'package:shotgun/screens/supervisor_screens/add_colors_fab/add_temple_color.dart';
import 'package:shotgun/screens/supervisor_screens/manage_customers_page/customers_list_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_customers_page/add_customers_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_staff/add_staff_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/manage_orders.dart';
import 'package:shotgun/screens/auth_screens/login_page.dart';
// import 'package:shotgun/screens/staff_screens/manage_inventory/manage_inventory_page.dart';
import 'package:shotgun/screens/staff_screens/order_details/order_details_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/manage_products_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/color_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/demo_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/fitting_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/packing_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/quality_check_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/raw_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/shipping_process_page.dart';
import 'package:shotgun/screens/staff_screens/staff_page.dart';
import 'package:shotgun/screens/staff_screens/track_orders/track_orders_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_staff/view_staff_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_supervisor_tasks/manage_supervisor_tasks.dart';
import 'package:shotgun/screens/supervisor_screens/manage_suppliers_page/suppliers_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_inventory_page/manage_inventory_page.dart';
import '../screens/supervisor_screens/color_templates/color_templates.dart';
import '../screens/supervisor_screens/manage_orders_page/add_orders_page.dart';
import '../screens/register_page.dart';
import '../screens/supervisor_screens/supervisor_dashboard.dart';
import '../screens/supervisor_screens/widgets/execute_order.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shotgun App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      initialRoute: '/company-login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/company-login': (context) => const CompanyLoginPage(),
        '/register': (context) => const RegisterPage(),

        // ADMIN ROUTES
        '/admin': (context) => const AdminDashboard(),
        '/admin/create-company': (context) => const CreateCompanyPage(),
        '/admin/view-companies': (context) => const ViewCompaniesPage(),

        // SUPERVISOR ROUTES
        '/supervisor': (context) => const SupervisorDashboard(),
        '/supervisor/tasks': (context) => const SupervisorTasksPage(),
        '/supervisor/products': (context) => const ManageProductPage(),
        '/supervisor/customers': (context) => const CustomersListPage(),
        '/supervisor/add-customer': (context) => const AddCustomersPage(),
        '/supervisor/suppliers': (context) => const ManageSuppliersPage(),
        '/supervisor/orders': (context) => const ManageOrdersPage(),
        '/supervisor/orders/new': (context) => const AddOrdersPage(),
        '/supervisor/orders/edit': (context) => const AddOrdersPage(isEditMode: true),
        '/supervisor/color-templates': (context) => const ColorTemplatesPage(),
        '/supervisor/manage-inventory': (context) => const ManageInventoryPage(),
        '/supervisor/view-staff': (context) => const ViewStaffPage(),
        '/supervisor/add-staff': (context) {
          final companyId = ModalRoute.of(context)!.settings.arguments as String;
          return AddStaffPage(companyId: companyId);
        },

        // FAB Menu routes
        '/supervisor/add-focus-color': (context) => const AddFocusColor(),
        '/supervisor/add-temple-color': (context) => const AddTempleColor(),
        '/supervisor/execute-order': (context) => const ExecuteOrder(),
        // '/manage-inventory': (context) => const ManageProductPage1(),
        

        // STAFF ROUTES
        '/staff': (context) => const StaffDashboard(),
        '/staff/process': (_) => const ExecuteProcessPage(),
        '/staff/tasks': (_) => const AssignedTaskPage(),

        '/orders': (context) => const TrackOrdersPage(),
        '/order-details': (context) => const OrderDetailsPage(),
        '/staff/rawProcess': (context) => const RawProcessPage(),
        '/staff/colorProcess': (context) => const ColorProcessPage(),
        '/staff/qualityCheck': (context) => const QualityCheckPage(),
        '/staff/fittingProcess': (context) => const FittingProcessPage(),
        '/staff/demoProcess': (context) => const DemoProcessPage(),
        '/staff/packing': (context) => const PackingPage(),
        '/staff/shipping': (context) => const ShippingPage(),
        // '/staff/tasks': (context) => const TasksPage(),
      },
    );
  }
}

