import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/add_orders_stepper.dart';

class AddOrdersPage extends StatelessWidget {
  final bool isEditMode;
  final String? orderId;
  final String? companyId;

  const AddOrdersPage({
    super.key,
    this.isEditMode = false,
    this.orderId,
    this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = AddOrderController();
        controller.initEditMode(
          isEditMode: isEditMode,
          orderId: orderId,
          companyId: companyId,
        );
        return controller;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Edit Order' : 'Add New Order'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AddOrdersStepper(companyId: companyId),
        ),
      ),
    );
  }
}
