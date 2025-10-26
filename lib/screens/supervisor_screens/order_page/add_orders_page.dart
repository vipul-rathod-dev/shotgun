import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/widgets/add_orders_stepper.dart';

class AddOrdersPage extends StatelessWidget {
  final bool isEditMode;
  final String? orderId;

  const AddOrdersPage({
    super.key,
    this.isEditMode = false,
    this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddOrderController()..initEditMode(isEditMode, orderId),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Edit Order' : 'Add New Order'),
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
