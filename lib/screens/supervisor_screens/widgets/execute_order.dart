// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/widgets/raw_material_selection_page.dart';

class ExecuteOrder extends StatefulWidget {
  const ExecuteOrder({super.key});

  @override
  State<ExecuteOrder> createState() => _ExecuteOrderState();
}

class _ExecuteOrderState extends State<ExecuteOrder> {
  String? selectedOrderId;
  String? selectedStaffId;
  String? cachedCompanyId;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cachedCompanyId = prefs.getString('cachedCompanyId');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Execute Order',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1565C0),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF3F6FB),
      body: cachedCompanyId == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Order to Execute',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Orders Dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('companies')
                            .doc(cachedCompanyId)
                            .collection('orders')
                            .where('orderStatus', isEqualTo: 'Received')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            Future.microtask(() => setState(() {
                                  selectedOrderId = null;
                                }));
                            return const Text(
                              "No orders with status 'Received'.",
                              style: TextStyle(color: Colors.black54),
                            );
                          }

                          final orders = snapshot.data!.docs;
                          final validIds = orders.map((doc) => doc.id).toSet();

                          // ✅ Automatically select the first available order if none selected
                          if (selectedOrderId == null || !validIds.contains(selectedOrderId)) {
                            Future.microtask(() {
                              if (mounted) {
                                setState(() {
                                  selectedOrderId = orders.first.id;
                                  selectedStaffId = null; // reset staff when auto-selecting
                                });
                              }
                            });
                          }


                          return DropdownButtonFormField<String>(
                            value: validIds.contains(selectedOrderId) ? selectedOrderId : null,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            hint: const Text('Choose an order'),
                            items: orders.map((doc) {
                              final orderNum =
                                  doc['orderNumber']?.toString() ?? doc.id;
                              final customer =
                                  doc['customerName'] ?? 'Unknown Customer';
                              final orderType =
                                  doc['orderType'] ?? 'Unknown Order Type';
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  "Order #$orderNum - $customer - $orderType",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: isProcessing
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedOrderId = value;
                                      selectedStaffId = null;
                                    });
                                  },
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // 🔹 Staff Dropdown
                      if (selectedOrderId != null) ...[
                        const Text(
                          'Assign Task To',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('companies')
                              .doc(cachedCompanyId)
                              .collection('users')
                              .where('role', isEqualTo: 'staff')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final staff = snapshot.data?.docs ?? [];

                            if (staff.isEmpty) {
                              return const Text(
                                "No staff users found.",
                                style: TextStyle(color: Colors.black54),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              value: selectedStaffId,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              hint:
                                  const Text('Select staff to assign task'),
                              items: staff.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    doc['name'] ?? 'Unnamed Staff',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isProcessing
                                  ? null
                                  : (value) {
                                      setState(() => selectedStaffId = value);
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                      ],

                      // 🔹 Process Button
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.precision_manufacturing),
                          label: const Text('Process Order'),
                          onPressed: selectedOrderId != null && selectedStaffId != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RawMaterialSelectionPage(
                                      companyId: cachedCompanyId!,
                                      orderId: selectedOrderId!,
                                      assignedStaffId: selectedStaffId!, // ✅ Pass staff
                                    ),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select both Order and Staff before proceeding.'),
                                  ),
                                );
                              },

                        )
                      ),
                    ],
                  ),
                ),

                // 🔹 Overlay loader
                if (isProcessing)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
