import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class CustomerDetailsForm extends StatefulWidget {
  final AddOrderController controller;
  final String? companyId;
  const CustomerDetailsForm({super.key, required this.controller, required this.companyId});

  @override
  State<CustomerDetailsForm> createState() => _CustomerDetailsFormState();
}

class _CustomerDetailsFormState extends State<CustomerDetailsForm> {
  late TextEditingController _phoneController;
  late TextEditingController _brandNameController;
  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  bool _loadingCustomers = true;

  @override
  void initState() {
    super.initState();
    if (widget.companyId != null) {
    _loadCustomers();
    }
    _phoneController = TextEditingController(text: widget.controller.customerPhone);
    _brandNameController = TextEditingController(text: widget.controller.brandName);
  }

  Future<void> _loadCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customers')
        .orderBy('name')
        .get();

    setState(() {
      _customers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "name": data["name"],
          "phone": data["phone"],
          "brandName": data["brandName"],
          ...data,
        };
      }).toList();

      _loadingCustomers = false;
    });
  }


  @override
  void dispose() {
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
          _loadingCustomers
            ? const Center(child: CircularProgressIndicator())
            : SearchableDropdown(
                items: _customers,
                keyName: "name",
                labelText: "Select Customer",
                value: _selectedCustomerId == null
                  ? null
                  : _customers.where((c) => c["id"] == _selectedCustomerId).isNotEmpty
                      ? _customers.firstWhere((c) => c["id"] == _selectedCustomerId)
                      : null,
                onChanged: (selected) {
                  if (selected == null) return;
                  setState(() {
                    _selectedCustomerId = selected["id"];
                  });

                  // 🔥 Auto-fill the controller fields
                  widget.controller.setCustomerName(selected["name"]);
                  widget.controller.customerNameController.text = selected["name"];

                  widget.controller.setCustomerPhone(selected["phone"]);
                  widget.controller.customerPhoneController.text = selected["phone"];

                  if (selected["brandName"] != null) {
                    widget.controller.setBrandName(selected["brandName"]);
                    widget.controller.brandNameController.text = selected["brandName"];
                  }

                  widget.controller.setDefaultTemplates(
                    selected["defaultTemplates"] ?? {},
                  );
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
