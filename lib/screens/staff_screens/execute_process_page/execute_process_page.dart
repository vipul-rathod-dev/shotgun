// execute_process_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'process_order_detail_page.dart';

class ExecuteProcessPage extends StatefulWidget {
  const ExecuteProcessPage({super.key});

  @override
  State<ExecuteProcessPage> createState() =>
      _ExecuteProcessPageState();
}

class _ExecuteProcessPageState extends State<ExecuteProcessPage> {
  String? companyId;
  late String currentUserId;

  final List<Map<String, dynamic>> activeProcesses = [];

  final Map<String, StreamSubscription> listeners = {};

  StreamSubscription? globalTaskSubscription;

  bool isLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    globalTaskSubscription?.cancel();

    for (final sub in listeners.values) {
      sub.cancel();
    }

    listeners.clear();

    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    currentUserId = user.uid;

    final prefs = await SharedPreferences.getInstance();

    companyId = prefs.getString("cachedCompanyId");

    if (companyId == null || companyId!.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    _listenToAssignedTasks();
  }

  // ============================================================
  // LISTEN TO GLOBAL TASKS
  // ============================================================

  void _listenToAssignedTasks() {
    if (companyId == null) return;

    globalTaskSubscription = FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("tasks")
        .snapshots()
        .listen(
      (snapshot) {
        _syncOrderTaskStreams(snapshot.docs);
      },
      onError: (error) {
        debugPrint(
          "Execute Process global task listener error: $error",
        );

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });
      },
    );
  }

  // ============================================================
  // LISTEN TO ACTUAL TASK DOCUMENTS
  // ============================================================

  Future<void> _syncOrderTaskStreams(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> globalTasks,
  ) async {
    for (final sub in listeners.values) {
      await sub.cancel();
    }

    listeners.clear();

    activeProcesses.clear();

    for (final doc in globalTasks) {
      final taskPath = doc.data()["taskPath"];

      if (taskPath == null ||
          taskPath.toString().trim().isEmpty) {
        continue;
      }

      final path = taskPath.toString();

      final sub = FirebaseFirestore.instance
          .doc(path)
          .snapshots()
          .listen(
        (taskSnap) {
          if (!taskSnap.exists) return;

          final taskData = taskSnap.data();

          if (taskData == null) return;

          if (taskData["assignedTo"] != currentUserId) {
            return;
          }

          _listenToTaskHistory(
            taskSnap.reference,
            taskData,
          );
        },
        onError: (error) {
          debugPrint(
            "Execute Process task listener error: $error",
          );
        },
      );

      listeners[path] = sub;
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // ============================================================
  // LISTEN TO TASK HISTORY
  // ============================================================

  void _listenToTaskHistory(
    DocumentReference taskRef,
    Map<String, dynamic> taskData,
  ) {
    taskRef.collection("history").snapshots().listen(
      (historySnap) {
        activeProcesses.removeWhere(
          (process) =>
              process["taskPath"] == taskRef.path,
        );

        for (final historyDoc in historySnap.docs) {
          final data = historyDoc.data();

          if (data["status"] == "Started") {
            activeProcesses.add({
              "taskPath": taskRef.path,
              "taskTitle": taskData["taskTitle"],
              "stage": data["process"],
              "startTimestamp": data["startTimestamp"],
            });
          }
        }

        if (!mounted) return;

        setState(() {});
      },
      onError: (error) {
        debugPrint(
          "Execute Process history listener error: $error",
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: Text(
          "Execute Process",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : activeProcesses.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    // ------------------------------------------------
                    // HEADER / COUNT
                    // ------------------------------------------------

                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${activeProcesses.length} "
                            "active process"
                            "${activeProcesses.length == 1 ? "" : "es"}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timelapse,
                                  size: 14,
                                  color:
                                      Colors.orange.shade800,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "In Progress",
                                  style:
                                      GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ------------------------------------------------
                    // PROCESS LIST
                    // ------------------------------------------------

                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          24,
                        ),
                        itemCount:
                            activeProcesses.length,
                        itemBuilder:
                            (context, index) {
                          return _processCard(
                            activeProcesses[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  // ============================================================
  // PROCESS CARD
  // ============================================================

  Widget _processCard(
    Map<String, dynamic> process,
  ) {
    final title =
        _value(process["taskTitle"]).isNotEmpty
            ? _value(process["taskTitle"])
            : "Untitled Process";

    final stage =
        _value(process["stage"]).isNotEmpty
            ? _value(process["stage"])
            : "Unknown Stage";

    final taskPath =
        _value(process["taskPath"]);

    final startDate =
        _timestampToDate(
      process["startTimestamp"],
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: taskPath.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProcessOrderDetailPage(
                      taskPath: taskPath,
                      taskTitle: title,
                      stage: stage,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ======================================================
              // TITLE + STATUS
              // ======================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  _processStatusBadge(),
                ],
              ),

              const SizedBox(height: 12),

              // ======================================================
              // STAGE
              // ======================================================

              _infoRow(
                Icons.account_tree_outlined,
                "Stage",
                stage,
              ),

              // ======================================================
              // TASK
              // ======================================================

              if (taskPath.isNotEmpty)
                _infoRow(
                  Icons.assignment_outlined,
                  "Task",
                  _taskDisplayName(taskPath),
                ),

              const SizedBox(height: 4),

              // ======================================================
              // DIVIDER
              // ======================================================

              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),

              const SizedBox(height: 10),

              // ======================================================
              // FOOTER
              // ======================================================

              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      startDate == null
                          ? "Started time unavailable"
                          : "Started ${_formatDateTime(startDate)}",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROCESS STATUS BADGE
  // ============================================================

  Widget _processStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timelapse,
            size: 14,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            "In Progress",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade600,
          ),

          const SizedBox(width: 8),

          Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 44,
                color: Colors.orange.shade700,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              "No active processes",
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Start a stage from Assigned Tasks "
              "and it will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VALUE HELPER
  // ============================================================

  String _value(
    dynamic value,
  ) {
    if (value == null) {
      return "";
    }

    return value.toString().trim();
  }

  // ============================================================
  // TIMESTAMP
  // ============================================================

  DateTime? _timestampToDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // TASK DISPLAY NAME
  // ============================================================

  String _taskDisplayName(
    String taskPath,
  ) {
    final parts = taskPath.split('/');

    if (parts.isEmpty) {
      return taskPath;
    }

    return parts.last;
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDateTime(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return "$day/$month/${date.year} "
        "$hour:$minute";
  }
}