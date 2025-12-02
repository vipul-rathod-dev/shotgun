import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskPath;

  const TaskDetailPage({super.key, required this.taskPath});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with SingleTickerProviderStateMixin {
  late DocumentReference<Map<String, dynamic>> taskRef;
  late ScrollController stepperScrollController;

  @override
  void initState() {
    super.initState();
    taskRef = FirebaseFirestore.instance.doc(widget.taskPath);
    stepperScrollController = ScrollController();
  }

  @override
  void dispose() {
    stepperScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Task Details", style: GoogleFonts.poppins()),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: taskRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text("Task not found"));

          final task = snapshot.data!.data()!;
          final orderType = task["orderType"];

          final stages = _getStages(orderType);

          return _buildTaskDetail(context, task, stages);
        },
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, Map<String, dynamic> task, List<String> stages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task["taskTitle"] ?? "Untitled Task",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        _statusChip(task["status"] ?? "Unknown"),
        const SizedBox(height: 20),

        // DESCRIPTION
        Text("Description",
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(task["description"] ?? "No description",
            style: GoogleFonts.poppins(fontSize: 14)),
        const SizedBox(height: 30),

        // ACTIVITY TIMELINE + BUTTONS
        Text("Activity Timeline",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        _buildStepper(stages),
      ]),
    );
  }

  /// BUILD DYNAMIC STEPPER WITH ICONS + ACTION BUTTONS
  Widget _buildStepper(List<String> stages) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: taskRef.collection("history").orderBy("timestamp").snapshots(),
      builder: (context, snapshot) {
        final history = snapshot.data?.docs ?? [];

        return Column(
          children: List.generate(stages.length, (index) {
            final stage = stages[index];
            QueryDocumentSnapshot<Map<String, dynamic>>? entry;

            for (var h in history) {
              if ((h.data()["process"] ?? "").toString().toLowerCase() ==
                  stage.toLowerCase()) {
                entry = h;
                break;
              }
            }

            final isCompleted = entry != null;
            final timestamp = entry?.data()["timestamp"]?.toDate().toString() ?? "Pending";

            final canStart = index == 0 || history.any(
                (h) => h.data()["process"] == stages[index - 1]); // previous completed

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_getStageIcon(stage),
                      color: isCompleted ? Colors.green : Colors.grey, size: 28),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage,
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                          isCompleted ? "Completed at: $timestamp" : "Pending",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey[700]),
                        ),

                        const SizedBox(height: 10),

                        /// BUTTONS
                        if (!isCompleted)
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: canStart
                                    ? () => _startProcess(stage)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  disabledBackgroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text("Start"),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: canStart
                                    ? () => _completeProcess(stage)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  disabledBackgroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text("Complete"),
                              ),
                            ],
                          )
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        );
      },
    );
  }

  /// START PROCESS
  Future<void> _startProcess(String stage) async {
    await taskRef.collection("history").add({
      "process": stage,
      "status": "Started",
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Extract company + order id
    final segments = widget.taskPath.split("/");
    final companyId = segments[1];
    final orderId = segments[3];

    final taskData = (await taskRef.get()).data()!;
    final orderType = taskData["orderType"];
    final stages = _getStages(orderType);

    // 1️⃣ Mark task as In Progress ONLY if starting first stage
    if (stage == stages.first) {
      await taskRef.update({
        "status": "In Progress",
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // 2️⃣ Mark orderStatus = current stage name
    await FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("orders")
        .doc(orderId)
        .update({
      "orderStatus": stage, // ← EXACT STAGE NAME
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// COMPLETE PROCESS
  Future<void> _completeProcess(String stage) async {
    await taskRef.collection("history").add({
      "process": stage,
      "status": "Completed",
      "timestamp": FieldValue.serverTimestamp(),
    });

    // Extract company + order id
    final segments = widget.taskPath.split("/");
    final companyId = segments[1];
    final orderId = segments[3];

    final taskData = (await taskRef.get()).data()!;
    final orderType = taskData["orderType"];

    final stages = _getStages(orderType);

    // If NOT the last stage → Do nothing else
    if (stage != stages.last) return;

    // 1️⃣ Complete task
    await taskRef.update({
      "status": "Completed",
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ Complete order
    await FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("orders")
        .doc(orderId)
        .update({
      "orderStatus": "Completed",
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // 3️⃣ Add final history entry
    await taskRef.collection("history").add({
      "process": "Task Completed",
      "status": "Completed",
      "timestamp": FieldValue.serverTimestamp(),
    });
  }


  /// STAGE ICONS
  IconData _getStageIcon(String stage) {
    if (stage.contains("Raw")) return Icons.layers;
    if (stage.contains("Color")) return Icons.color_lens;
    if (stage.contains("Fitting")) return Icons.construction;
    if (stage.contains("Demo")) return Icons.video_label;
    if (stage.contains("Packing")) return Icons.inventory_2;
    if (stage.contains("Shipping")) return Icons.local_shipping;
    return Icons.check_circle;
  }

  /// GET STAGES BASED ON ORDER TYPE
  List<String> _getStages(String orderType) {
    orderType = orderType.toLowerCase();

    if (orderType == "stock") {
      return [
        "Packing Process",
        "Shipping Process",
      ];
    }

    return [
      "Raw Process",
      "Color Process",
      "Fitting Process",
      "Demo Process",
      "Packing Process",
      "Shipping Process",
    ];
  }

  /// STATUS CHIP
  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status.toLowerCase() == "completed") color = Colors.green;
    if (status.toLowerCase() == "in progress") color = Colors.orange;

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      label: Text(status,
          style: GoogleFonts.poppins(
              color: color, fontWeight: FontWeight.w600)),
    );
  }
}
