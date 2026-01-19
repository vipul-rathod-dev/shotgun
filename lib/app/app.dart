import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/create_company_page.dart';
import 'package:shotgun/screens/admin_screens/view_companies_page.dart';
import 'package:shotgun/screens/staff_screens/assigned_task_page/assigned_task_page.dart';
import 'package:shotgun/screens/staff_screens/execute_process_page/execute_process_page.dart';
import 'package:shotgun/screens/supervisor_screens/add_colors_fab/add_focus_color.dart';
import 'package:shotgun/screens/supervisor_screens/add_colors_fab/add_temple_color.dart';
import 'package:shotgun/screens/supervisor_screens/manage_customers_page/customers_list_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_customers_page/add_customers_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_staff/add_staff_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/manage_orders.dart';
import 'package:shotgun/screens/staff_screens/order_details/order_details_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/manage_products_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/color_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/demo_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/fitting_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/packing_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/quality_check_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/raw_process_page.dart';
import 'package:shotgun/screens/staff_screens/process_page/shipping_process_page.dart';
import 'package:shotgun/screens/staff_screens/track_orders/track_orders_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_staff/view_staff_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_supervisor_tasks/manage_supervisor_tasks.dart';
import 'package:shotgun/screens/supervisor_screens/manage_suppliers_page/suppliers_page.dart';
import 'package:shotgun/screens/supervisor_screens/manage_inventory_page/manage_inventory_page.dart';
import '../screens/supervisor_screens/color_templates/color_templates.dart';
import '../screens/supervisor_screens/manage_orders_page/add_orders_page.dart';
import '../screens/register_page.dart';
import '../screens/supervisor_screens/widgets/execute_order.dart';
import '../screens/auth_screens/auth_gate.dart';
import '../screens/auth_screens/route_guard.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shotgun App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),

      home: AuthGate(),

      routes: _secureRoutes,
    );
  }
}

final Map<String, WidgetBuilder> _secureRoutes = {
  '/register': (_) => const RegisterPage(),

  // ADMIN
  '/admin/create-company':
      (_) => const RoleGuard(requiredRole: 'admin', child: CreateCompanyPage()),
  '/admin/view-companies':
      (_) => const RoleGuard(requiredRole: 'admin', child: ViewCompaniesPage()),

  // SUPERVISOR
  '/supervisor/tasks':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: SupervisorTasksPage(),
      ),
  '/supervisor/products':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: ManageProductPage(),
      ),
  '/supervisor/customers':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: CustomersListPage(),
      ),
  '/supervisor/add-customer':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: AddCustomersPage(),
      ),
  '/supervisor/suppliers':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: ManageSuppliersPage(),
      ),
  '/supervisor/orders':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: ManageOrdersPage(),
      ),
  '/supervisor/orders/new':
      (_) =>
          const RoleGuard(requiredRole: 'supervisor', child: AddOrdersPage()),
  '/supervisor/orders/edit':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: AddOrdersPage(isEditMode: true),
      ),
  '/supervisor/color-templates':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: ColorTemplatesPage(),
      ),
  '/supervisor/manage-inventory':
      (_) => const RoleGuard(
        requiredRole: 'supervisor',
        child: ManageInventoryPage(),
      ),
  '/supervisor/view-staff':
      (_) =>
          const RoleGuard(requiredRole: 'supervisor', child: ViewStaffPage()),

  '/supervisor/add-staff': (context) {
    final companyId = ModalRoute.of(context)!.settings.arguments as String;
    return RoleGuard(
      requiredRole: 'supervisor',
      child: AddStaffPage(companyId: companyId),
    );
  },

  // FAB
  '/supervisor/add-focus-color':
      (_) =>
          const RoleGuard(requiredRole: 'supervisor', child: AddFocusColor()),
  '/supervisor/add-temple-color':
      (_) =>
          const RoleGuard(requiredRole: 'supervisor', child: AddTempleColor()),
  '/supervisor/execute-order':
      (_) => const RoleGuard(requiredRole: 'supervisor', child: ExecuteOrder()),

  '/orders': (_) => const TrackOrdersPage(),
  '/order-details': (_) => const OrderDetailsPage(),

  // STAFF
  '/staff/process':
      (_) => const RoleGuard(
        requiredRole: 'staff',
        child: ExecuteProcessPage(),
      ),
  '/staff/tasks':
      (_) => const RoleGuard(
        requiredRole: 'staff',
        child: AssignedTaskPage(),
      ),
  '/staff/rawProcess':
      (_) =>
          const RoleGuard(requiredRole: 'staff', child: RawProcessPage()),
  '/staff/colorProcess':
      (_) => const RoleGuard(
        requiredRole: 'staff',
        child: ColorProcessPage(),
      ),
  '/staff/qualityCheck':
      (_) => const RoleGuard(
        requiredRole: 'staff',
        child: QualityCheckPage(),
      ),
  '/staff/fittingProcess':
      (_) => const RoleGuard(
        requiredRole: 'staff',
        child: FittingProcessPage(),
      ),
  '/staff/demoProcess':
      (_) =>
          const RoleGuard(requiredRole: 'staff', child: DemoProcessPage()),
  '/staff/packing':
      (_) => const RoleGuard(requiredRole: 'staff', child: PackingPage()),
  '/staff/shipping':
      (_) => const RoleGuard(requiredRole: 'staff', child: ShippingPage()),
};
