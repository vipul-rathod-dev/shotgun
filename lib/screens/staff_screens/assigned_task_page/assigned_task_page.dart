// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_detail_page.dart';

class AssignedTaskPage extends StatefulWidget {
  const AssignedTaskPage({super.key});

  @override
  State<AssignedTaskPage> createState() => _AssignedTaskPageState();
}

class _AssignedTaskPageState extends State<AssignedTaskPage> {
  String? companyId;
  late String currentUserId;

  StreamSubscription? globalTaskSubscription;
  Timer? debounceTimer;

  List<Map<String, dynamic>> assignedTasks = [];
  bool isLoading = true;

  String searchQuery = "";
  String selectedFilter = "All";
  String selectedSort = "None";
  final StreamController<List<Map<String, dynamic>>> _taskStreamController =
    StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    globalTaskSubscription?.cancel();
    debounceTimer?.cancel();
    _taskStreamController.close();
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

    _listenToGlobalTasks();
  }

  /// Real-time listener for global tasks
  void _listenToGlobalTasks() {
    globalTaskSubscription = FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("tasks")
        .snapshots()
        .listen((snapshot) async {
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 150), () {
        _syncAllTasksLive(snapshot.docs);
      });
    });
  }

  final Map<String, StreamSubscription> _liveOrderListeners = {};

  Future<void> _syncAllTasksLive(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> globalTasks) async {
    
    // Cancel old listeners
    for (var sub in _liveOrderListeners.values) {
      sub.cancel();
    }
    _liveOrderListeners.clear();

    List<Map<String, dynamic>> latestTaskList = [];

    for (var globalDoc in globalTasks) {
      final taskPath = globalDoc.data()["taskPath"];
      if (taskPath == null || taskPath.isEmpty) continue;

      // Listen to EACH task live
      final sub = FirebaseFirestore.instance
          .doc(taskPath)
          .snapshots()
          .listen((taskSnap) {
        if (!taskSnap.exists) return;

        final taskData = taskSnap.data()!;
        if (taskData["assignedTo"] != currentUserId) return;

        // Update the local list entry
        final index = latestTaskList.indexWhere(
            (t) => t["taskPath"] == taskPath);

        final newEntry = {
          ...taskData,
          "taskPath": taskPath,
          "companyId": companyId,
        };

        if (index == -1) {
          latestTaskList.add(newEntry);
        } else {
          latestTaskList[index] = newEntry;
        }

        // Broadcast updated tasks
        _taskStreamController.add(List.from(latestTaskList));
      });

      _liveOrderListeners[taskPath] = sub;
    }

    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> _applyFilters() {
    List<Map<String, dynamic>> list = List.from(assignedTasks);

    // Search Filter
    if (searchQuery.isNotEmpty) {
      list = list.where((task) {
        final title = (task["taskTitle"] ?? "").toString().toLowerCase();
        final orderType = (task["orderType"] ?? "").toString().toLowerCase();
        return title.contains(searchQuery.toLowerCase()) ||
              orderType.contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Status Filter
    if (selectedFilter != "All") {
      list = list.where((task) {
        return (task["status"] ?? "") == selectedFilter;
      }).toList();
    }

    // Sorting
    if (selectedSort == "OrderType A-Z") {
      list.sort((a, b) => (a["orderType"] ?? "").compareTo(b["orderType"] ?? ""));
    } else if (selectedSort == "OrderType Z-A") {
      list.sort((a, b) => (b["orderType"] ?? "").compareTo(a["orderType"] ?? ""));
    }

    return list;
  }


  @override
  Widget build(BuildContext context) {
    if (companyId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Assigned Tasks",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 🔎 SEARCH BAR
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search tasks...",
                    filled: true,
                    fillColor: Colors.grey[200],
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),

              // 🔥 FILTER CHIPS
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildFilterChip("All"),
                    _buildFilterChip("Pending"),
                    _buildFilterChip("In Progress"),
                    _buildFilterChip("Completed"),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔽 SORT DROPDOWN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Text("Sort By: "),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedSort,
                      items: const [
                        DropdownMenuItem(
                          value: "None",
                          child: Text("None"),
                        ),
                        DropdownMenuItem(
                          value: "OrderType A-Z",
                          child: Text("OrderType A-Z"),
                        ),
                        DropdownMenuItem(
                          value: "OrderType Z-A",
                          child: Text("OrderType Z-A"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSort = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🟩 FILTERED + SEARCHED + SORTED LIST
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _taskStreamController.stream,
                  builder: (context, snap) {
                    if (!snap.hasData) return Center(child: Text("No tasks found"));

                    assignedTasks = snap.data!;
                    final filteredList = _applyFilters();

                    if (filteredList.isEmpty) {
                      return const Center(child: Text("No tasks found."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final task = filteredList[index];
                        final title = task["taskTitle"] ?? "Untitled Task";
                        final status = task["status"] ?? "Unknown";
                        final orderType = task["orderType"] ?? "";

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text("Status: $status",
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[600])),
                                Text("OrderType: $orderType",
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TaskDetailPage(taskPath: task["taskPath"]),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.blue,
        onSelected: (_) {
          setState(() {
            selectedFilter = label;
          });
        },
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

}
