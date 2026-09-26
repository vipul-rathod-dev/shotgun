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
  // ============================================================
  // USER / COMPANY
  // ============================================================

  String? companyId;
  late String currentUserId;

  // ============================================================
  // FIRESTORE LISTENERS
  // ============================================================

  StreamSubscription? globalTaskSubscription;

  final Map<String, StreamSubscription> _liveOrderListeners = {};

  Timer? debounceTimer;

  // ============================================================
  // TASK DATA
  // ============================================================

  List<Map<String, dynamic>> assignedTasks = [];

  bool isLoading = true;

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  String searchQuery = "";

  // ============================================================
  // FILTERS
  // ============================================================

  String selectedStatus = "All";
  String selectedOrderType = "All";
  String selectedStage = "All";

  // Date filter
  String selectedDateFilter = "All";

  DateTime? customFromDate;
  DateTime? customToDate;

  // ============================================================
  // SORT
  // ============================================================

  String selectedSort = "Newest";

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

    debounceTimer?.cancel();

    _searchController.dispose();

    for (final subscription in _liveOrderListeners.values) {
      subscription.cancel();
    }

    _liveOrderListeners.clear();

    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    currentUserId = user.uid;

    final prefs = await SharedPreferences.getInstance();

    companyId = prefs.getString("cachedCompanyId");

    if (companyId == null || companyId!.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    // IMPORTANT:
    // Keep the original working task-loading architecture.
    _listenToGlobalTasks();
  }

  // ============================================================
  // ORIGINAL WORKING GLOBAL TASK LISTENER
  // ============================================================

  void _listenToGlobalTasks() {
    if (companyId == null) return;

    globalTaskSubscription = FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("tasks")
        .snapshots()
        .listen(
      (snapshot) {
        debounceTimer?.cancel();

        debounceTimer = Timer(
          const Duration(milliseconds: 150),
          () {
            _syncAllTasksLive(snapshot.docs);
          },
        );
      },
      onError: (error) {
        debugPrint(
          "Global task listener error: $error",
        );

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });
      },
    );
  }

  // ============================================================
  // ORIGINAL WORKING TASK SYNC
  // ============================================================

  Future<void> _syncAllTasksLive(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> globalTasks,
  ) async {
    // Cancel previous listeners
    for (final subscription in _liveOrderListeners.values) {
      await subscription.cancel();
    }

    _liveOrderListeners.clear();

    if (mounted) {
      setState(() {
        assignedTasks = [];
        isLoading = true;
      });
    }

    for (final globalDoc in globalTasks) {
      final globalData = globalDoc.data();

      final taskPath = globalData["taskPath"];

      if (taskPath == null ||
          taskPath.toString().trim().isEmpty) {
        debugPrint(
          "⚠️ Global task ${globalDoc.id} has no taskPath",
        );

        continue;
      }

      final path = taskPath.toString();

      // ----------------------------------------------------------
      // IMPORTANT:
      // Listen to the actual task document.
      // This is the same architecture as your original code.
      // ----------------------------------------------------------

      final subscription = FirebaseFirestore.instance
          .doc(path)
          .snapshots()
          .listen(
        (taskSnap) {
          if (!taskSnap.exists) {
            return;
          }

          final taskData = taskSnap.data();

          if (taskData == null) {
            return;
          }

          // ------------------------------------------------------
          // IMPORTANT:
          // ASSIGNMENT IS CHECKED ON THE ACTUAL TASK DOCUMENT.
          // ------------------------------------------------------

          if (taskData["assignedTo"] != currentUserId) {
            return;
          }

          final newEntry = {
            ...taskData,
            "taskPath": path,
            "companyId": companyId,

            // Keep global task ID available.
            "globalTaskId": globalDoc.id,
          };

          if (!mounted) return;

          setState(() {
            final index = assignedTasks.indexWhere(
              (task) => task["taskPath"] == path,
            );

            if (index == -1) {
              assignedTasks.add(newEntry);
            } else {
              assignedTasks[index] = newEntry;
            }

            isLoading = false;
          });
        },
        onError: (error) {
          debugPrint(
            "Task listener error for $path: $error",
          );
        },
      );

      _liveOrderListeners[path] = subscription;
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // SEARCH + FILTER + SORT
  // ============================================================

  List<Map<String, dynamic>> _applySearchFiltersAndSort() {
    List<Map<String, dynamic>> list =
        List<Map<String, dynamic>>.from(
      assignedTasks,
    );

    // ==========================================================
    // SEARCH
    // ==========================================================

    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      list = list.where((task) {
        final values = [
          task["taskTitle"],
          task["taskName"],
          task["title"],
          task["orderType"],
          task["status"],
          task["stage"],
          task["orderNumber"],
          task["customerName"],
          task["customerPhone"],
          task["brandName"],
          task["taskPath"],
        ];

        return values.any(
          (value) {
            if (value == null) return false;

            return value
                .toString()
                .toLowerCase()
                .contains(query);
          },
        );
      }).toList();
    }

    // ==========================================================
    // STATUS
    // ==========================================================

    if (selectedStatus != "All") {
      list = list.where((task) {
        return _value(task["status"]) ==
            selectedStatus;
      }).toList();
    }

    // ==========================================================
    // ORDER TYPE
    // ==========================================================

    if (selectedOrderType != "All") {
      list = list.where((task) {
        return _value(task["orderType"]) ==
            selectedOrderType;
      }).toList();
    }

    // ==========================================================
    // STAGE
    // ==========================================================

    if (selectedStage != "All") {
      list = list.where((task) {
        return _value(task["stage"]) ==
            selectedStage;
      }).toList();
    }

    // ==========================================================
    // DATE
    // ==========================================================

    list = _applyDateFilter(list);

    // ==========================================================
    // SORT
    // ==========================================================

    switch (selectedSort) {
      case "Newest":
        list.sort(
          (a, b) => _taskDate(b).compareTo(
            _taskDate(a),
          ),
        );
        break;

      case "Oldest":
        list.sort(
          (a, b) => _taskDate(a).compareTo(
            _taskDate(b),
          ),
        );
        break;

      case "Title A-Z":
        list.sort(
          (a, b) => _value(a["taskTitle"])
              .toLowerCase()
              .compareTo(
                _value(b["taskTitle"])
                    .toLowerCase(),
              ),
        );
        break;

      case "Title Z-A":
        list.sort(
          (a, b) => _value(b["taskTitle"])
              .toLowerCase()
              .compareTo(
                _value(a["taskTitle"])
                    .toLowerCase(),
              ),
        );
        break;

      case "Order Type A-Z":
        list.sort(
          (a, b) => _value(a["orderType"])
              .toLowerCase()
              .compareTo(
                _value(b["orderType"])
                    .toLowerCase(),
              ),
        );
        break;

      case "Order Type Z-A":
        list.sort(
          (a, b) => _value(b["orderType"])
              .toLowerCase()
              .compareTo(
                _value(a["orderType"])
                    .toLowerCase(),
              ),
        );
        break;

      case "Status A-Z":
        list.sort(
          (a, b) => _value(a["status"])
              .toLowerCase()
              .compareTo(
                _value(b["status"])
                    .toLowerCase(),
              ),
        );
        break;

      case "Status Z-A":
        list.sort(
          (a, b) => _value(b["status"])
              .toLowerCase()
              .compareTo(
                _value(a["status"])
                    .toLowerCase(),
              ),
        );
        break;
    }

    return list;
  }

  // ============================================================
  // DATE FILTER
  // ============================================================

  List<Map<String, dynamic>> _applyDateFilter(
    List<Map<String, dynamic>> list,
  ) {
    if (selectedDateFilter == "All") {
      return list;
    }

    final now = DateTime.now();

    DateTime? start;
    DateTime? end;

    if (selectedDateFilter == "Today") {
      start = DateTime(
        now.year,
        now.month,
        now.day,
      );

      end = start.add(
        const Duration(days: 1),
      );
    }

    if (selectedDateFilter == "Yesterday") {
      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      start = today.subtract(
        const Duration(days: 1),
      );

      end = today;
    }

    if (selectedDateFilter == "Last 7 Days") {
      end = now;

      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(
        const Duration(days: 6),
      );
    }

    if (selectedDateFilter == "Last 30 Days") {
      end = now;

      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(
        const Duration(days: 29),
      );
    }

    if (selectedDateFilter == "Custom") {
      start = customFromDate;

      if (customToDate != null) {
        end = DateTime(
          customToDate!.year,
          customToDate!.month,
          customToDate!.day,
        ).add(
          const Duration(days: 1),
        );
      }
    }

    if (start == null || end == null) {
      return list;
    }

    return list.where((task) {
      final date = _taskDate(task);

      return !date.isBefore(start!) &&
          date.isBefore(end!);
    }).toList();
  }

  // ============================================================
  // DYNAMIC FILTER VALUES
  // ============================================================

  List<String> _statuses() {
    final values = assignedTasks
        .map((task) => _value(task["status"]))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ["All", ...values];
  }

  List<String> _orderTypes() {
    final values = assignedTasks
        .map((task) => _value(task["orderType"]))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ["All", ...values];
  }

  List<String> _stages() {
    final values = assignedTasks
        .map((task) => _value(task["stage"]))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ["All", ...values];
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectCustomDateRange(
    void Function(void Function()) setModalState,
  ) async {
    final now = DateTime.now();

    final initialStart =
        customFromDate ??
        DateTime(
          now.year,
          now.month,
          now.day,
        );

    final initialEnd =
        customToDate ??
        initialStart;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd,
      ),
    );

    if (range == null) {
      return;
    }

    setModalState(() {
      customFromDate = range.start;
      customToDate = range.end;
      selectedDateFilter = "Custom";
    });
  }

  // ============================================================
  // FILTER SHEET
  // ============================================================

  Future<void> _openFilterSheet() async {
    String tempStatus = selectedStatus;
    String tempOrderType = selectedOrderType;
    String tempStage = selectedStage;
    String tempDateFilter = selectedDateFilter;

    DateTime? tempFromDate = customFromDate;
    DateTime? tempToDate = customToDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Filter Tasks",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(
                              context,
                            ),
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle("Status"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempStatus,
                        items: _statuses(),
                        onChanged: (value) {
                          setModalState(() {
                            tempStatus = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle("Order Type"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempOrderType,
                        items: _orderTypes(),
                        onChanged: (value) {
                          setModalState(() {
                            tempOrderType = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle("Stage / Process"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempStage,
                        items: _stages(),
                        onChanged: (value) {
                          setModalState(() {
                            tempStage = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle("Date"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempDateFilter,
                        items: const [
                          "All",
                          "Today",
                          "Yesterday",
                          "Last 7 Days",
                          "Last 30 Days",
                          "Custom",
                        ],
                        onChanged: (value) async {
                          if (value == "Custom") {
                            await _selectCustomDateRange(
                              setModalState,
                            );

                            tempDateFilter =
                                "Custom";

                            tempFromDate =
                                customFromDate;

                            tempToDate =
                                customToDate;
                          } else {
                            setModalState(() {
                              tempDateFilter =
                                  value;
                            });
                          }
                        },
                      ),

                      if (tempDateFilter ==
                          "Custom") ...[
                        const SizedBox(height: 8),

                        Text(
                          tempFromDate != null &&
                                  tempToDate != null
                              ? "${_formatDateOnly(tempFromDate!)} → ${_formatDateOnly(tempToDate!)}"
                              : "Select date range",
                          style:
                              GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  tempStatus =
                                      "All";

                                  tempOrderType =
                                      "All";

                                  tempStage =
                                      "All";

                                  tempDateFilter =
                                      "All";

                                  tempFromDate =
                                      null;

                                  tempToDate =
                                      null;
                                });
                              },
                              child:
                                  const Text(
                                "Reset",
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedStatus =
                                      tempStatus;

                                  selectedOrderType =
                                      tempOrderType;

                                  selectedStage =
                                      tempStage;

                                  selectedDateFilter =
                                      tempDateFilter;

                                  customFromDate =
                                      tempFromDate;

                                  customToDate =
                                      tempToDate;
                                });

                                Navigator.pop(
                                  context,
                                );
                              },
                              child: const Text(
                                "Apply Filters",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SORT SHEET
  // ============================================================

  Future<void> _openSortSheet() async {
    String tempSort = selectedSort;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            const sortOptions = [
              "Newest",
              "Oldest",
              "Title A-Z",
              "Title Z-A",
              "Order Type A-Z",
              "Order Type Z-A",
              "Status A-Z",
              "Status Z-A",
            ];

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Sort Tasks",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(
                            context,
                          ),
                          icon: const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    ...sortOptions.map(
                      (sort) {
                        return RadioListTile<String>(
                          dense: true,
                          value: sort,
                          groupValue: tempSort,
                          title: Text(
                            sort,
                            style:
                                GoogleFonts.poppins(
                              fontSize: 13,
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setModalState(() {
                              tempSort = value;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedSort =
                                tempSort;
                          });

                          Navigator.pop(context);
                        },
                        child:
                            const Text("Apply Sort"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  void _clearAll() {
    setState(() {
      searchQuery = "";

      selectedStatus = "All";
      selectedOrderType = "All";
      selectedStage = "All";

      selectedDateFilter = "All";

      customFromDate = null;
      customToDate = null;

      selectedSort = "Newest";

      _searchController.clear();
    });
  }

  // ============================================================
  // ACTIVE FILTER CHECK
  // ============================================================

  bool get hasActiveFilters {
    return selectedStatus != "All" ||
        selectedOrderType != "All" ||
        selectedStage != "All" ||
        selectedDateFilter != "All" ||
        searchQuery.trim().isNotEmpty;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (companyId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tasks =
        _applySearchFiltersAndSort();

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,

        title: Text(
          "Assigned Tasks",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),

        actions: [
          IconButton(
            tooltip: "Clear Search & Filters",
            onPressed:
                hasActiveFilters
                    ? _clearAll
                    : null,
            icon: const Icon(
              Icons.filter_alt_off_outlined,
            ),
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // ==================================================
                // SEARCH AREA
                // ==================================================

                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    16,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller:
                            _searchController,

                        onChanged: (value) {
                          setState(() {
                            searchQuery =
                                value;
                          });
                        },

                        decoration:
                            InputDecoration(
                          hintText:
                              "Search tasks, orders, customers...",

                          hintStyle:
                              GoogleFonts.poppins(
                            fontSize: 13,
                            color:
                                Colors.grey.shade600,
                          ),

                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),

                          suffixIcon:
                              searchQuery
                                      .isNotEmpty
                                  ? IconButton(
                                      onPressed:
                                          () {
                                        _searchController
                                            .clear();

                                        setState(() {
                                          searchQuery =
                                              "";
                                        });
                                      },
                                      icon:
                                          const Icon(
                                        Icons
                                            .clear,
                                      ),
                                    )
                                  : null,

                          filled: true,
                          fillColor:
                              const Color(
                            0xFFF4F5F7,
                          ),

                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton.icon(
                              onPressed:
                                  _openFilterSheet,

                              icon:
                                  const Icon(
                                Icons
                                    .filter_list,
                                size: 18,
                              ),

                              label: Text(
                                hasActiveFilters
                                    ? "Filters Applied"
                                    : "Filters",
                                style:
                                    GoogleFonts
                                        .poppins(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child:
                                OutlinedButton.icon(
                              onPressed:
                                  _openSortSheet,

                              icon:
                                  const Icon(
                                Icons.sort,
                                size: 18,
                              ),

                              label: Text(
                                "Sort",
                                style:
                                    GoogleFonts
                                        .poppins(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // ACTIVE FILTERS
                // ==================================================

                if (hasActiveFilters)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      12,
                    ),
                    child:
                        SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal,
                      child: Row(
                        children: [
                          if (searchQuery
                              .trim()
                              .isNotEmpty)
                            _activeChip(
                              "Search: $searchQuery",
                            ),

                          if (selectedStatus !=
                              "All")
                            _activeChip(
                              "Status: $selectedStatus",
                            ),

                          if (selectedOrderType !=
                              "All")
                            _activeChip(
                              "Type: $selectedOrderType",
                            ),

                          if (selectedStage !=
                              "All")
                            _activeChip(
                              "Stage: $selectedStage",
                            ),

                          if (selectedDateFilter !=
                              "All")
                            _activeChip(
                              "Date: $selectedDateFilter",
                            ),
                        ],
                      ),
                    ),
                  ),

                // ==================================================
                // RESULT COUNT
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${tasks.length} task${tasks.length == 1 ? "" : "s"}",
                        style:
                            GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        "Sort: $selectedSort",
                        style:
                            GoogleFonts.poppins(
                          fontSize: 11,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // TASK LIST
                // ==================================================

                Expanded(
                  child: tasks.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            16,
                            4,
                            16,
                            24,
                          ),

                          itemCount:
                              tasks.length,

                          itemBuilder:
                              (context, index) {
                            return _taskCard(
                              tasks[index],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // TASK CARD
  // ============================================================

  Widget _taskCard(
    Map<String, dynamic> task,
  ) {
    final title =
        _value(task["taskTitle"]).isNotEmpty
            ? _value(task["taskTitle"])
            : "Untitled Task";

    final status =
        _value(task["status"]).isNotEmpty
            ? _value(task["status"])
            : "Unknown";

    final orderType =
        _value(task["orderType"]);

    final stage =
        _value(task["stage"]);

    final orderNumber =
        _value(task["orderNumber"]);

    final customerName =
        _value(task["customerName"]);

    final customerPhone =
        _value(task["customerPhone"]);

    final brandName =
        _value(task["brandName"]);

    final date =
        _taskDate(task);

    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),

      elevation: 0,

      color: Colors.white,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),

        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),

        onTap: () {
          final taskPath =
              task["taskPath"];

          if (taskPath == null) {
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TaskDetailPage(
                taskPath:
                    taskPath.toString(),
              ),
            ),
          );
        },

        child: Padding(
          padding:
              const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // --------------------------------------------------
              // TITLE + STATUS
              // --------------------------------------------------

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
                      style:
                          GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  _statusBadge(status),
                ],
              ),

              const SizedBox(height: 12),

              // --------------------------------------------------
              // ORDER
              // --------------------------------------------------

              if (orderNumber.isNotEmpty)
                _infoRow(
                  Icons
                      .receipt_long_outlined,
                  "Order",
                  orderNumber,
                ),

              // --------------------------------------------------
              // CUSTOMER
              // --------------------------------------------------

              if (customerName.isNotEmpty)
                _infoRow(
                  Icons.person_outline,
                  "Customer",
                  customerName,
                ),

              // --------------------------------------------------
              // PHONE
              // --------------------------------------------------

              if (customerPhone.isNotEmpty)
                _infoRow(
                  Icons.phone_outlined,
                  "Phone",
                  customerPhone,
                ),

              // --------------------------------------------------
              // BRAND
              // --------------------------------------------------

              if (brandName.isNotEmpty)
                _infoRow(
                  Icons.business_outlined,
                  "Brand",
                  brandName,
                ),

              // --------------------------------------------------
              // ORDER TYPE
              // --------------------------------------------------

              if (orderType.isNotEmpty)
                _infoRow(
                  Icons.category_outlined,
                  "Order Type",
                  orderType,
                ),

              // --------------------------------------------------
              // STAGE
              // --------------------------------------------------

              if (stage.isNotEmpty)
                _infoRow(
                  Icons
                      .account_tree_outlined,
                  "Stage",
                  stage,
                ),

              const SizedBox(height: 10),

              Divider(
                height: 1,
                color:
                    Colors.grey.shade200,
              ),

              const SizedBox(height: 10),

              // --------------------------------------------------
              // FOOTER
              // --------------------------------------------------

              Row(
                children: [
                  Icon(
                    Icons
                        .schedule_outlined,
                    size: 15,
                    color:
                        Colors.grey.shade600,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      date.millisecondsSinceEpoch ==
                              0
                          ? "No date"
                          : _formatDate(
                              date,
                            ),
                      style:
                          GoogleFonts.poppins(
                        fontSize: 11,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios,
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
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    Color background;
    Color foreground;
    IconData icon;

    switch (status.toLowerCase()) {
      case "completed":
        background =
            Colors.green.shade50;
        foreground =
            Colors.green.shade700;
        icon =
            Icons.check_circle_outline;
        break;

      case "in progress":
        background =
            Colors.orange.shade50;
        foreground =
            Colors.orange.shade800;
        icon =
            Icons.timelapse;
        break;

      case "pending":
        background =
            Colors.blue.shade50;
        foreground =
            Colors.blue.shade700;
        icon =
            Icons.pending_outlined;
        break;

      default:
        background =
            Colors.grey.shade100;
        foreground =
            Colors.grey.shade700;
        icon =
            Icons.info_outline;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground,
          ),

          const SizedBox(width: 4),

          Text(
            status,
            style:
                GoogleFonts.poppins(
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
              color: foreground,
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
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                Colors.grey.shade600,
          ),

          const SizedBox(width: 8),

          Text(
            "$label:",
            style:
                GoogleFonts.poppins(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
              fontWeight:
                  FontWeight.w500,
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(
                fontSize: 12,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String>
        onChanged,
  }) {
    final safeValue =
        items.contains(value)
            ? value
            : items.first;

    return DropdownButtonFormField<
        String>(
      initialValue: safeValue,

      decoration:
          InputDecoration(
        filled: true,
        fillColor:
            const Color(0xFFF5F6F8),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              BorderSide.none,
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),

      items: items.map(
        (item) {
          return DropdownMenuItem<
              String>(
            value: item,

            child: Text(
              item,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(
                fontSize: 13,
              ),
            ),
          );
        },
      ).toList(),

      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
  ) {
    return Text(
      title,
      style:
          GoogleFonts.poppins(
        fontSize: 13,
        fontWeight:
            FontWeight.w600,
      ),
    );
  }

  // ============================================================
  // ACTIVE CHIP
  // ============================================================

  Widget _activeChip(
    String label,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        right: 8,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.blue.shade50,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Text(
        label,
        style:
            GoogleFonts.poppins(
          fontSize: 11,
          color:
              Colors.blue.shade700,
          fontWeight:
              FontWeight.w500,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    final filtered =
        hasActiveFilters;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              filtered
                  ? Icons.search_off
                  : Icons
                      .assignment_outlined,

              size: 60,

              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            Text(
              filtered
                  ? "No matching tasks"
                  : "No assigned tasks",

              style:
                  GoogleFonts.poppins(
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              filtered
                  ? "Try changing your search or filters."
                  : "Tasks assigned to you will appear here.",

              textAlign:
                  TextAlign.center,

              style:
                  GoogleFonts.poppins(
                fontSize: 12,
                color:
                    Colors.grey.shade600,
              ),
            ),

            if (filtered) ...[
              const SizedBox(height: 16),

              OutlinedButton(
                onPressed:
                    _clearAll,

                child:
                    const Text(
                  "Clear Search & Filters",
                ),
              ),
            ],
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
  // DATE HELPER
  // ============================================================

  DateTime _taskDate(
    Map<String, dynamic> task,
  ) {
    final possibleDates = [
      task["updatedAt"],
      task["createdAt"],
      task["timestamp"],
      task["assignedAt"],
      task["orderDate"],
    ];

    for (final value
        in possibleDates) {
      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final parsed =
            DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    String two(int value) {
      return value
          .toString()
          .padLeft(2, "0");
    }

    return "${two(date.day)}/"
        "${two(date.month)}/"
        "${date.year} "
        "${two(date.hour)}:"
        "${two(date.minute)}";
  }

  String _formatDateOnly(
    DateTime date,
  ) {
    String two(int value) {
      return value
          .toString()
          .padLeft(2, "0");
    }

    return "${two(date.day)}/"
        "${two(date.month)}/"
        "${date.year}";
  }
}