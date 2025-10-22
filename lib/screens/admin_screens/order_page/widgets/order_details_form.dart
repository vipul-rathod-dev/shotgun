import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/widgets/date_picker_field.dart';

class OrderDetailsForm extends StatefulWidget {
  final AddOrderController controller;

  const OrderDetailsForm({super.key, required this.controller});

  @override
  State<OrderDetailsForm> createState() => _OrderDetailsFormState();
}

class _OrderDetailsFormState extends State<OrderDetailsForm> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.controller.formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DatePickerField(
            label: 'Order Date',
            selectedDate: widget.controller.orderDate,
            onDateSelected: widget.controller.setOrderDate, // ✅
          ),
          const SizedBox(height: 16),
          DatePickerField(
            label: 'Shipping Date',
            selectedDate: widget.controller.shippingDate,
            onDateSelected: widget.controller.setShippingDate, // ✅
          ),
        ],
      ),
    );
  }
}
