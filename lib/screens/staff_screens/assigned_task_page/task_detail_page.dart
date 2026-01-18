// task_detail_page.dart
// Final fully updated file with safe IDs, correct Start/Complete switching,
// atomic writes, realtime task + order syncing, auto-scroll, icons, and badges.

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
  late final DocumentReference<Map<String, dynamic>> taskRef;
  late final ScrollController stepperScrollController;

  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();

    taskRef = FirebaseFirestore.instance
        .doc(widget.taskPath);

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
        builder: (context, taskSnap) {
          if (taskSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return const Center(child: Text("Task not found"));
          }

          final task = taskSnap.data!.data()!;
          final orderType = (task["orderType"] ?? "").toString().toLowerCase();
          final stages = _getStages(orderType);

          // Extract IDs from path
          final segments = widget.taskPath.split("/");
          if (segments.length < 6) {
            return Center(child: Text("Invalid task path"));
          }

          final companyId = segments[1];
          final orderId = segments[3];

          final orderRef = FirebaseFirestore.instance
              .collection("companies")
              .doc(companyId)
              .collection("orders")
              .doc(orderId);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: orderRef.snapshots(),
            builder: (context, orderSnap) {
              final bool hasOrder = orderSnap.hasData && (orderSnap.data?.exists ?? false);

              final orderStatus = hasOrder
                  ? orderSnap.data!.data()!["orderStatus"] ?? "Unknown"
                  : "Unknown";


              return _buildTaskDetail(context, task, stages, orderStatus);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskDetail(
      BuildContext context,
      Map<String, dynamic> task,
      List<String> stages,
      String orderStatus,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          task["taskTitle"] ?? "Untitled Task",
          style:
          GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            _taskStatusChip(task["status"].toString()),
            const SizedBox(width: 10),
            _orderStatusChip(orderStatus),
          ],
        ),

        const SizedBox(height: 20),

        Text("Description",
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(task["description"] ?? "No description",
            style: GoogleFonts.poppins(fontSize: 14)),

        const SizedBox(height: 20),

        Text("Activity Timeline",
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        _buildStepper(stages),
      ]),
    );
  }

  Widget _buildStepper(List<String> stages) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
      taskRef.collection("history").orderBy("startTimestamp").snapshots(),
      builder: (context, snap) {
        final history = snap.data?.docs ?? [];

        // Auto scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final index = _getActiveStageIndex(history, stages);
          if (index != null && stepperScrollController.hasClients) {
            final position = 150.0 * index;
            stepperScrollController.animateTo(
              position,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });

        return SingleChildScrollView(
          controller: stepperScrollController,
          child: Column(
            children: List.generate(stages.length, (index) {
              final stage = stages[index];
              final safeId = stage.replaceAll(" ", "_").toLowerCase();

              final entry = _findHistoryDocById(history, safeId);
              final entryData = entry?.data();

              final isStarted = entryData?["status"] == "Started";
              final isCompleted = entryData?["status"] == "Completed";


              final timestamp = isCompleted
                  ? (entryData?["completeTimestamp"]?.toDate().toString() ?? "")
                  : isStarted
                  ? (entryData?["startTimestamp"]?.toDate().toString() ?? "")
                  : "Pending";

              // Previous stage must be completed
              bool prevCompleted = false;
              if (index == 0) prevCompleted = true;
              else {
                final prevSafe =
                stages[index - 1].replaceAll(" ", "_").toLowerCase();
                for (var h in history) {
                  if (h.id == prevSafe &&
                      h.data()["status"] == "Completed") {
                    prevCompleted = true;
                    break;
                  }
                }
              }

              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                margin: EdgeInsets.only(bottom: 20),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconForStage(stage),
                      color: isCompleted ? Colors.green : Colors.grey,
                      size: 30,
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stage,
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            isCompleted
                                ? "Completed at: $timestamp"
                                : isStarted
                                ? "Started at: $timestamp"
                                : "Pending",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.black54),
                          ),

                          const SizedBox(height: 10),

                          _buttonsForStage(
                              stage, prevCompleted, isStarted, isCompleted),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buttonsForStage(
      String stage,
      bool prevCompleted,
      bool isStarted,
      bool isCompleted,
      ) {
    if (!isStarted && !isCompleted) {
      // show START
      return ElevatedButton(
        onPressed: prevCompleted ? () => _onStartPressed(stage) : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue),
        child: Text("Start"),
      );
    }

    if (isStarted && !isCompleted) {
      // show COMPLETE
      return ElevatedButton(
        onPressed: () => _onCompletePressed(stage),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green),
        child: Text("Complete"),
      );
    }

    return SizedBox.shrink(); // completed -> no buttons
  }

  // Button wrappers
  Future<void> _onStartPressed(String stage) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    try {
      await _startProcess(stage);
    } finally {
      setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _onCompletePressed(String stage) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    try {
      await _completeProcess(stage);
    } finally {
      setState(() => _isProcessingAction = false);
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _findHistoryDocById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> history,
    String safeId,
  ) {
    for (var h in history) {
      if (h.id == safeId) return h;
    }
    return null;
  }


  // START PROCESS — transactional
  Future<void> _startProcess(String stage) async {
    final segments = widget.taskPath.split("/");
    final companyId = segments[1];
    final orderId = segments[3];

    final safeId = stage.replaceAll(" ", "_").toLowerCase();
    final historyDoc = taskRef.collection("history").doc(safeId);

    final batch = FirebaseFirestore.instance.batch();

    // read task
    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() ?? {};
    final orderType = taskData["orderType"].toString().toLowerCase();
    final stages = _getStages(orderType);
    final isFirst = stage.trim().toLowerCase() == stages.first.trim().toLowerCase();

    // write history start
    batch.set(historyDoc, {
      "process": stage,
      "status": "Started",
      "startTimestamp": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // update task if first stage
    if (isFirst) {
      batch.update(taskRef, {
        "status": "In Progress",
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // update parent orderStatus
    final orderRef = FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("orders")
        .doc(orderId);

    batch.update(orderRef, {
      "orderStatus": stage,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // COMPLETE PROCESS — transactional
  Future<void> _completeProcess(String stage) async {
    final segments = widget.taskPath.split("/");
    final companyId = segments[1];
    final orderId = segments[3];

    final safeId = stage.replaceAll(" ", "_").toLowerCase();
    final historyDoc = taskRef.collection("history").doc(safeId);

    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() ?? {};
    final orderType = (taskData["orderType"] ?? "stock").toString().toLowerCase();
    final stages = _getStages(orderType);
    final isLast = stage.trim().toLowerCase() == stages.last.trim().toLowerCase();

    // ------------------------------------------------------
    // 🔥 RAW PROCESS VALIDATION
    // ------------------------------------------------------
    if (stage.trim().toLowerCase() == "raw process") {
      final orderRef = FirebaseFirestore.instance
          .collection("companies")
          .doc(companyId)
          .collection("orders")
          .doc(orderId);

      final orderSnap = await orderRef.get();
      final orderData = orderSnap.data() ?? {};

      final rawUsed = orderData["rawUsed"];

      if (rawUsed == null || rawUsed is! Map || rawUsed.isEmpty) {
        // ❌ STOP PROCESS HERE
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Cannot complete Raw Process. No raw material usage found.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // ← DO NOT COMPLETE STAGE
      }
    }
    // ------------------------------------------------------

    final batch = FirebaseFirestore.instance.batch();

    // update history completion
    batch.update(historyDoc, {
      "status": "Completed",
      "completeTimestamp": FieldValue.serverTimestamp(),
    });

    if (isLast) {
      batch.update(taskRef, {
        "status": "Completed",
        "updatedAt": FieldValue.serverTimestamp(),
      });

      final orderRef = FirebaseFirestore.instance
          .collection("companies")
          .doc(companyId)
          .collection("orders")
          .doc(orderId);

      batch.update(orderRef, {
        "orderStatus": "Completed",
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // final history entry
      final finalDoc = taskRef.collection("history").doc("task_completed");
      batch.set(finalDoc, {
        "process": "Task Completed",
        "status": "Completed",
        "timestamp": FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Utility: find current active stage index
  int? _getActiveStageIndex(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> history,
      List<String> stages,
      ) {
    for (int i = 0; i < stages.length; i++) {
      final safeId = stages[i].replaceAll(" ", "_").toLowerCase();
      final entry = _findHistoryDocById(history, safeId);
      if (entry == null || entry.data()["status"] != "Completed") {
        return i;
      }
    }
    return null;
  }

  IconData _iconForStage(String stage) {
    final s = stage.toLowerCase();
    if (s.contains("raw")) return Icons.layers;
    if (s.contains("color")) return Icons.color_lens;
    if (s.contains("fitting")) return Icons.handyman;
    if (s.contains("demo")) return Icons.screen_share;
    if (s.contains("packing")) return Icons.inventory_2;
    if (s.contains("shipping")) return Icons.local_shipping;
    return Icons.task;
  }

  List<String> _getStages(String orderType) {
    if (orderType == "stock") {
      return ["Packing Process", "Shipping Process"];
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

  Widget _taskStatusChip(String status) {
    final s = status.toLowerCase();
    Color c = Colors.grey;
    if (s.contains("in progress")) c = Colors.orange;
    if (s.contains("completed")) c = Colors.green;

    return Chip(
      backgroundColor: c.withOpacity(0.2),
      label: Text(
        "Task: $status",
        style: GoogleFonts.poppins(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _orderStatusChip(String status) {
    final s = status.toLowerCase();
    Color c = Colors.blue;

    if (s.contains("completed")) c = Colors.green;
    else if (s.contains("shipping")) c = Colors.deepOrange;
    else if (s.contains("packing")) c = Colors.teal;
    else if (s.contains("raw")) c = Colors.brown;
    else if (s.contains("color")) c = Colors.purple;
    else if (s.contains("fitting")) c = Colors.indigo;
    else if (s.contains("demo")) c = Colors.cyan;

    return Chip(
      backgroundColor: c.withOpacity(0.2),
      label: Text(
        "Order: $status",
        style: GoogleFonts.poppins(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}
