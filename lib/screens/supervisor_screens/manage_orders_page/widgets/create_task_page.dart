import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/utils/firestore_scripts.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';

class CreateTaskPage extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? orderData;

  const CreateTaskPage({
    super.key,
    this.orderId,
    this.orderData,
  });

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  String? companyId;

  bool isLoading = true;

  List<Map<String, dynamic>> allStaff = [];
  Map<String, dynamic>? selectedStaff;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    // 🔥 Correct way to get companyId
    companyId = widget.orderData?['companyId']
        ?? await FirestoreScripts.getCachedCompanyId();

    print("🔥 CompanyID Loaded: $companyId");

    if (companyId != null) {
      await loadStaff();
    }

    setState(() => isLoading = false);
  }

  Future<void> loadStaff() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      allStaff = snap.docs.map((doc) {
        return {
          "id": doc.id,
          "name": doc['name'] ?? 'Unnamed',
          "email": doc['email'] ?? '',
        };
      }).toList();

      print("🔥 Staff Loaded: $allStaff");

      setState(() {});
    } catch (e) {
      debugPrint("❌ Error loading staff: $e");
    }
  }

  Future<void> updateStatusIfStockOrder() async {
    if (widget.orderData?['orderType'] == "Stock") {
      final id = companyId;

      if (id == null || widget.orderId == null) return;

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'orderStatus': 'Packing Process',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("🔥 Status Updated: Received → Packing Process");
    }
  }

  Future<void> createTask() async {
    if (companyId == null || widget.orderId == null || selectedStaff == null) {
      debugPrint("❌ Missing required data");
      return;
    }

    try {
      // -----------------------------
      // MAIN TASK DOCUMENT (full data)
      // -----------------------------
      final orderTaskRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('orders')
          .doc(widget.orderId)
          .collection('tasks')
          .doc(); // auto-ID

      final taskId = orderTaskRef.id;

      final taskData = {
        'taskTitle': "Task for Order #${widget.orderData!['orderNumber']}",
        'taskId': taskId,
        'orderId': widget.orderId,
        'orderType': widget.orderData?['orderType'] ?? '',
        'assignedTo': selectedStaff!['id'],
        'assignedToName': selectedStaff!['name'],
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save full task data
      await orderTaskRef.set(taskData);

      // -----------------------------
      // GLOBAL TASK REFERENCE (ONLY IDs)
      // -----------------------------
      final globalTaskRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('tasks')
          .doc(taskId);

      await globalTaskRef.set({
        'taskId': taskId,
        'orderId': widget.orderId,
        'taskPath':
            "companies/$companyId/orders/${widget.orderId}/tasks/$taskId",
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("🔥 Task saved + global ref created");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task assigned successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("❌ Task creation failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Task creation failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Assign Task")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchableDropdown(
              items: allStaff,        // <-- Now guaranteed not empty
              keyName: "name",
              labelText: "Select Staff Member",
              value: selectedStaff,
              onChanged: (value) {
                setState(() => selectedStaff = value);
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedStaff == null
                    ? null
                    : () async {
                        await updateStatusIfStockOrder();
                        await createTask();
                      },
                child: const Text("Assign Task"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
