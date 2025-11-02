// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: isProcessing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow,
                                  color: Colors.white),
                          label: Text(
                            isProcessing ? 'Processing...' : 'Process Order',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: isProcessing ||
                                  selectedOrderId == null ||
                                  selectedStaffId == null
                              ? null
                              : _confirmAndProcessOrder,
                        ),
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

  Future<void> _confirmAndProcessOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirm Execution'),
        content: const Text(
            'Are you sure you want to execute this order and assign it to the selected staff?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Execute'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _processOrder(selectedOrderId!, selectedStaffId!);
    }
  }

  Future<void> _processOrder(String orderId, String staffId) async {
    setState(() => isProcessing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final companyRef = firestore.collection('companies').doc(cachedCompanyId);

      final orderRef = companyRef.collection('orders').doc(orderId);
      final userRef = companyRef.collection('users').doc(staffId);

      // 🔹 Fetch order data
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order not found.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final orderData = orderSnapshot.data()!;
      final orderType = orderData['orderType'] ?? '';
      final brandName = orderData['brandName'] ?? 'Unknown Brand';
      final orderNumber = orderData['orderNumber'] ?? 'N/A';
      final customerName = orderData['customerName'] ?? 'Unknown Customer';
      final productDetails = orderData['products'] ?? [];
      final customizationDetails = orderData['customizationDetails'] ?? {};

      // 🔹 Determine next order status
      String nextStatus;
      switch (orderType) {
        case 'Stock':
          nextStatus = 'Packing';
          break;
        case 'Customized':
          nextStatus = 'Raw Process';
          break;
        default:
          nextStatus = 'Packing';
      }

      // 🔹 Fetch staff name
      String assignedToName = 'Unknown Staff';
      final userSnapshot = await userRef.get();
      if (userSnapshot.exists) {
        assignedToName = userSnapshot.data()?['name'] ?? assignedToName;
      }

      // 🔹 Update order document
      await orderRef.update({
        'orderStatus': nextStatus,
        'assignedTo': staffId,
        'assignedToName': assignedToName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 🔹 Prepare task data
      final Map<String, dynamic> taskData = {
        'companyId': cachedCompanyId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'brandName': brandName,
        'customerName': customerName,
        'orderType': orderType,
        'orderStatus': nextStatus,
        'assignedTo': staffId,
        'assignedToName': assignedToName,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'productDetails': productDetails,
      };

      // 🔹 Add customization details for customized orders
      if (orderType == 'Customized') {
        taskData['customizationDetails'] = customizationDetails;
      }

      // 🔹 Create task in both locations
      final taskRef = await orderRef.collection('tasks').add(taskData);
      await companyRef.collection('tasks').doc(taskRef.id).set({
        ...taskData,
        'taskId': taskRef.id,
        'orderPath': orderRef.path,
      });

      // ✅ Modern Success Sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 60,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Order Processed Successfully!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300], thickness: 1.2),
                  const SizedBox(height: 10),

                  // Order info summary
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow("Order Number", orderNumber),
                      _infoRow("Customer", customerName),
                      _infoRow("Brand", brandName),
                      _infoRow("Order Type", orderType),
                      _infoRow("New Status", nextStatus),
                      _infoRow("Assigned To", assignedToName),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      setState(() {
        selectedOrderId = null;
        selectedStaffId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }


}
