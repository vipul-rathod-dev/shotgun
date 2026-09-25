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
  List<Map<String, dynamic>> _customers = [];
  // String? _selectedCustomerId;
  bool _loadingCustomers = true;

  @override
  void initState() {
    super.initState();
    if (widget.companyId != null) {
    _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customers')
        .orderBy('name')
        .get();

    if (!mounted) return;

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
                value: widget.controller.selectedCustomerId == null
                  ? null
                  : _customers.firstWhere(
                      (c) => c["id"] == widget.controller.selectedCustomerId,
                      orElse: () => {},
                    ),

                onChanged: (selected) {
                  if (selected == null) return;

                  final customerId = selected["id"]?.toString();
                  final customerName = selected["name"]?.toString() ?? '';
                  final phone = selected["phone"]?.toString() ?? '';
                  final brandName = selected["brandName"]?.toString() ?? '';

                  widget.controller.selectedCustomerId = customerId;

                  widget.controller.setCustomerName(customerName);
                  widget.controller.setCustomerPhone(phone);
                  widget.controller.setBrandName(brandName);

                   widget.controller.customerNameController.value =
                      TextEditingValue(
                    text: customerName,
                    selection: TextSelection.collapsed(
                      offset: customerName.length,
                    ),
                  );

                  widget.controller.customerPhoneController.value =
                      TextEditingValue(
                    text: phone,
                    selection: TextSelection.collapsed(
                      offset: phone.length,
                    ),
                  );

                  widget.controller.brandNameController.value =
                      TextEditingValue(
                    text: brandName,
                    selection: TextSelection.collapsed(
                      offset: brandName.length,
                    ),
                  );

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
          const SizedBox(height: 20),
          // 🔹 New Order Type Dropdown
          ValueListenableBuilder(
            valueListenable: widget.controller.orderTypeNotifier,
            builder: (_, value, __) {
              return SearchableDropdown(
                labelText: "Order Type",
                keyName: "label",
                items: const [
                  {"value": "Stock", "label": "Stock Order"},
                  {"value": "Customized", "label": "Customized Order"},
                ],
                value: value == null
                    ? null
                    : {
                        "value": value,
                        "label": value == "Stock"
                            ? "Stock Order"
                            : "Customized Order",
                      },
                onChanged: (selected) {
                  if (selected == null) return;
                  widget.controller.setOrderType(selected["value"]);
                },
              );
            },
          )
        ],
      ),
    );
  }
}
