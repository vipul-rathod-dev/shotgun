import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/add_orders_stepper.dart';

class AddOrdersPage extends StatelessWidget {
  const AddOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddOrderController(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Order'),
          centerTitle: true,
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: AddOrdersStepper(),
        ),
      ),
    );
  }
}
