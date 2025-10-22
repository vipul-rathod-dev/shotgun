import 'package:flutter/material.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class CustomerDetailsForm extends StatefulWidget {
  final AddOrderController controller;
  const CustomerDetailsForm({super.key, required this.controller});

  @override
  State<CustomerDetailsForm> createState() => _CustomerDetailsFormState();
}

class _CustomerDetailsFormState extends State<CustomerDetailsForm> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _brandNameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.customerName);
    _phoneController = TextEditingController(text: widget.controller.customerPhone);
    _brandNameController = TextEditingController(text: widget.controller.brandName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _brandNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.controller.formKeys[0],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          CustomTextField(
            label: 'Customer Name',
            icon: Icons.person,
            controller: widget.controller.customerNameController,
            onChanged: widget.controller.setCustomerName, // ✅ clean one-liner
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the customer name';
              }
              if (value.trim().length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Phone Number',
            icon: Icons.phone,
            controller: widget.controller.customerPhoneController,
            keyboardType: TextInputType.phone,
            onChanged: widget.controller.setCustomerPhone, // ✅
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a phone number';
              }
              if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                return 'Enter a valid 10-digit phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Brand Name',
            icon: Icons.branding_watermark_outlined,
            controller: widget.controller.brandNameController,
            onChanged: widget.controller.setBrandName, // ✅ clean one-liner
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the customer brand name';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
