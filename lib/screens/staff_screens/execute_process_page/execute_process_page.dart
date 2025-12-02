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
  State<ExecuteProcessPage> createState() => _ExecuteProcessPageState();
}

class _ExecuteProcessPageState extends State<ExecuteProcessPage> {
  String? companyId;
  late String currentUserId;

  final List<Map<String, dynamic>> activeProcesses = [];
  final Map<String, StreamSubscription> listeners = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (var sub in listeners.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final prefs = await SharedPreferences.getInstance();
    companyId = prefs.getString("cachedCompanyId");

    if (companyId == null) {
      setState(() => isLoading = false);
      return;
    }

    _listenToAssignedTasks();
  }

  /// Step 1: Listen to all tasks assigned to current user
  void _listenToAssignedTasks() {
    FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("tasks")
        .snapshots()
        .listen((snapshot) {
      _syncOrderTaskStreams(snapshot.docs);
    });
  }

  /// Step 2: For each task, listen to its actual taskPath document
  Future<void> _syncOrderTaskStreams(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> globalTasks) async {
    for (var sub in listeners.values) {
      sub.cancel();
    }
    listeners.clear();
    activeProcesses.clear();

    for (var doc in globalTasks) {
      final taskPath = doc.data()["taskPath"];
      if (taskPath == null) continue;

      final sub = FirebaseFirestore.instance
          .doc(taskPath)
          .snapshots()
          .listen((taskSnap) {
        if (!taskSnap.exists) return;

        final taskData = taskSnap.data()!;
        if (taskData["assignedTo"] != currentUserId) return;

        _listenToTaskHistory(taskSnap.reference, taskData);
      });

      listeners[taskPath] = sub;
    }

    setState(() => isLoading = false);
  }

  /// Step 3: Listen to history entries for each task
  void _listenToTaskHistory(
      DocumentReference taskRef, Map<String, dynamic> taskData) {
    taskRef.collection("history").snapshots().listen((historySnap) {
      activeProcesses.removeWhere(
          (p) => p["taskPath"] == taskRef.path); // clear old entries

      for (var h in historySnap.docs) {
        final data = h.data();

        if (data["status"] == "Started") {
          activeProcesses.add({
            "taskPath": taskRef.path,
            "taskTitle": taskData["taskTitle"],
            "stage": data["process"],
            "startTimestamp": data["startTimestamp"],
          });
        }
      }

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Execute Process", style: GoogleFonts.poppins()),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeProcesses.isEmpty
              ? Center(
                  child: Text(
                    "No active processes.\nStart a stage from Assigned Tasks.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: activeProcesses.length,
                  itemBuilder: (context, index) {
                    final p = activeProcesses[index];
                    final ts = p["startTimestamp"]?.toDate().toString() ?? "";

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProcessOrderDetailPage(
                                taskPath: p["taskPath"],
                                taskTitle: p["taskTitle"],
                                stage: p["stage"],
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p["taskTitle"],
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Stage: ${p["stage"]}",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              Text(
                                "Started at: $ts",
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
