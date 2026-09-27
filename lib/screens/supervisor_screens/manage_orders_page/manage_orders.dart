import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/order_card.dart';
import 'add_orders_page.dart';

class ManageOrdersPage extends StatefulWidget {
  const ManageOrdersPage({super.key});

  @override
  State<ManageOrdersPage> createState() => _ManageOrdersPageState();
}

class _ManageOrdersPageState extends State<ManageOrdersPage> {
  String? companyId;

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
    _loadCompanyId();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD COMPANY
  // ============================================================

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      companyId = prefs.getString('cachedCompanyId');
    });
  }

  // ============================================================
  // SEARCH + FILTER + SORT
  // ============================================================

  List<QueryDocumentSnapshot> _applySearchFiltersAndSort(
    List<QueryDocumentSnapshot> orders,
  ) {
    List<QueryDocumentSnapshot> list =
        List<QueryDocumentSnapshot>.from(orders);

    // ==========================================================
    // SEARCH
    // ==========================================================

    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      list = list.where((order) {
        final data = order.data() as Map<String, dynamic>;

        final values = [
          data["orderNumber"],
          data["customerName"],
          data["customerPhone"],
          data["brandName"],
          data["orderType"],
          data["orderStatus"],
          order.id,
        ];

        return values.any((value) {
          if (value == null) return false;

          return value
              .toString()
              .toLowerCase()
              .contains(query);
        });
      }).toList();
    }

    // ==========================================================
    // STATUS
    // ==========================================================

    if (selectedStatus != "All") {
      list = list.where((order) {
        final data = order.data() as Map<String, dynamic>;

        return _value(data["orderStatus"]) == selectedStatus;
      }).toList();
    }

    // ==========================================================
    // ORDER TYPE
    // ==========================================================

    if (selectedOrderType != "All") {
      list = list.where((order) {
        final data = order.data() as Map<String, dynamic>;

        return _value(data["orderType"]) == selectedOrderType;
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
          (a, b) {
            final first =
                _orderDate(b.data() as Map<String, dynamic>);

            final second =
                _orderDate(a.data() as Map<String, dynamic>);

            return first.compareTo(second);
          },
        );
        break;

      case "Oldest":
        list.sort(
          (a, b) {
            final first =
                _orderDate(a.data() as Map<String, dynamic>);

            final second =
                _orderDate(b.data() as Map<String, dynamic>);

            return first.compareTo(second);
          },
        );
        break;

      case "Order Number A-Z":
        list.sort(
          (a, b) {
            final first = _value(
              (a.data() as Map<String, dynamic>)["orderNumber"],
            );

            final second = _value(
              (b.data() as Map<String, dynamic>)["orderNumber"],
            );

            return _compareOrderNumbers(first, second);
          },
        );
        break;

      case "Order Number Z-A":
        list.sort(
          (a, b) {
            final first = _value(
              (b.data() as Map<String, dynamic>)["orderNumber"],
            );

            final second = _value(
              (a.data() as Map<String, dynamic>)["orderNumber"],
            );

            return _compareOrderNumbers(first, second);
          },
        );
        break;

      case "Customer A-Z":
        list.sort(
          (a, b) {
            final first = _value(
              (a.data() as Map<String, dynamic>)["customerName"],
            ).toLowerCase();

            final second = _value(
              (b.data() as Map<String, dynamic>)["customerName"],
            ).toLowerCase();

            return first.compareTo(second);
          },
        );
        break;

      case "Customer Z-A":
        list.sort(
          (a, b) {
            final first = _value(
              (b.data() as Map<String, dynamic>)["customerName"],
            ).toLowerCase();

            final second = _value(
              (a.data() as Map<String, dynamic>)["customerName"],
            ).toLowerCase();

            return first.compareTo(second);
          },
        );
        break;

      case "Status A-Z":
        list.sort(
          (a, b) {
            final first = _value(
              (a.data() as Map<String, dynamic>)["orderStatus"],
            ).toLowerCase();

            final second = _value(
              (b.data() as Map<String, dynamic>)["orderStatus"],
            ).toLowerCase();

            return first.compareTo(second);
          },
        );
        break;

      case "Status Z-A":
        list.sort(
          (a, b) {
            final first = _value(
              (b.data() as Map<String, dynamic>)["orderStatus"],
            ).toLowerCase();

            final second = _value(
              (a.data() as Map<String, dynamic>)["orderStatus"],
            ).toLowerCase();

            return first.compareTo(second);
          },
        );
        break;
    }

    return list;
  }

  // ============================================================
  // DATE FILTER
  // ============================================================

  List<QueryDocumentSnapshot> _applyDateFilter(
    List<QueryDocumentSnapshot> list,
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

    return list.where((order) {
      final data = order.data() as Map<String, dynamic>;

      final date = _orderDate(data);

      return !date.isBefore(start!) && date.isBefore(end!);
    }).toList();
  }

  // ============================================================
  // DYNAMIC FILTER VALUES
  // ============================================================

  List<String> _statuses(
    List<QueryDocumentSnapshot> orders,
  ) {
    final values = orders
        .map((order) {
          final data = order.data() as Map<String, dynamic>;

          return _value(data["orderStatus"]);
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ["All", ...values];
  }

  List<String> _orderTypes(
    List<QueryDocumentSnapshot> orders,
  ) {
    final values = orders
        .map((order) {
          final data = order.data() as Map<String, dynamic>;

          return _value(data["orderType"]);
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ["All", ...values];
  }

  // ============================================================
  // CUSTOM DATE RANGE
  // ============================================================

  Future<void> _selectCustomDateRange(
    void Function(void Function()) setModalState,
  ) async {
    final now = DateTime.now();

    final initialStart = customFromDate ??
        DateTime(
          now.year,
          now.month,
          now.day,
        );

    final initialEnd = customToDate ?? initialStart;

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

  Future<void> _openFilterSheet(
    List<QueryDocumentSnapshot> orders,
  ) async {
    String tempStatus = selectedStatus;
    String tempOrderType = selectedOrderType;
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
                      // ------------------------------------------------
                      // HEADER
                      // ------------------------------------------------

                      Row(
                        children: [
                          Text(
                            "Filter Orders",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // STATUS
                      // ------------------------------------------------

                      _sectionTitle("Status"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempStatus,
                        items: _statuses(orders),
                        onChanged: (value) {
                          setModalState(() {
                            tempStatus = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // ORDER TYPE
                      // ------------------------------------------------

                      _sectionTitle("Order Type"),

                      const SizedBox(height: 8),

                      _dropdown(
                        value: tempOrderType,
                        items: _orderTypes(orders),
                        onChanged: (value) {
                          setModalState(() {
                            tempOrderType = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // ------------------------------------------------
                      // DATE
                      // ------------------------------------------------

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

                            tempDateFilter = "Custom";
                            tempFromDate =
                                customFromDate;
                            tempToDate =
                                customToDate;
                          } else {
                            setModalState(() {
                              tempDateFilter = value;
                            });
                          }
                        },
                      ),

                      if (tempDateFilter == "Custom") ...[
                        const SizedBox(height: 8),
                        Text(
                          tempFromDate != null &&
                                  tempToDate != null
                              ? "${_formatDateOnly(tempFromDate!)} → ${_formatDateOnly(tempToDate!)}"
                              : "Select date range",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ------------------------------------------------
                      // ACTIONS
                      // ------------------------------------------------

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  tempStatus = "All";
                                  tempOrderType = "All";
                                  tempDateFilter = "All";
                                  tempFromDate = null;
                                  tempToDate = null;
                                });
                              },
                              child: const Text(
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

                                  selectedDateFilter =
                                      tempDateFilter;

                                  customFromDate =
                                      tempFromDate;

                                  customToDate =
                                      tempToDate;
                                });

                                Navigator.pop(context);
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

    const sortOptions = [
      "Newest",
      "Oldest",
      "Order Number A-Z",
      "Order Number Z-A",
      "Customer A-Z",
      "Customer Z-A",
      "Status A-Z",
      "Status Z-A",
    ];

    await showModalBottomSheet(
      context: context,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ------------------------------------------------
                    // HEADER
                    // ------------------------------------------------

                    Row(
                      children: [
                        Text(
                          "Sort Orders",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ------------------------------------------------
                    // SORT OPTIONS
                    // ------------------------------------------------

                    ...sortOptions.map(
                      (sort) {
                        return RadioListTile<String>(
                          dense: true,
                          value: sort,
                          groupValue: tempSort,
                          title: Text(
                            sort,
                            style: GoogleFonts.poppins(
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
                            selectedSort = tempSort;
                          });

                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Apply Sort",
                        ),
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
          "Manage Orders",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
          ),
        ),

        actions: [
          // Clear search & filters
          IconButton(
            tooltip: "Clear Search & Filters",
            onPressed:
                hasActiveFilters ? _clearAll : null,
            icon: const Icon(
              Icons.filter_alt_off_outlined,
            ),
          ),

          // New order
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOrdersPage(
                    companyId: companyId,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              "New Order",
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),

      // ==========================================================
      // FIRESTORE
      // ==========================================================

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('orders')
            .orderBy(
              'orderNumber',
              descending: true,
            )
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return _emptyState(
              false,
            );
          }

          final orders = snapshot.data!.docs;

          final filteredOrders =
              _applySearchFiltersAndSort(orders);

          return Column(
            children: [
              // ====================================================
              // SEARCH AREA
              // ====================================================

              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16,
                ),
                child: Column(
                  children: [
                    // ------------------------------------------------
                    // SEARCH FIELD
                    // ------------------------------------------------

                    TextField(
                      controller: _searchController,

                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },

                      decoration: InputDecoration(
                        hintText:
                            "Search orders, customers, brands...",

                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),

                        prefixIcon: const Icon(
                          Icons.search,
                        ),

                        suffixIcon:
                            searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController
                                          .clear();

                                      setState(() {
                                        searchQuery = "";
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.clear,
                                    ),
                                  )
                                : null,

                        filled: true,

                        fillColor:
                            const Color(0xFFF4F5F7),

                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // FILTER + SORT BUTTONS
                    // ------------------------------------------------

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openFilterSheet(orders),

                            icon: const Icon(
                              Icons.filter_list,
                              size: 18,
                            ),

                            label: Text(
                              hasActiveFilters
                                  ? "Filters Applied"
                                  : "Filters",

                              style:
                                  GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _openSortSheet,

                            icon: const Icon(
                              Icons.sort,
                              size: 18,
                            ),

                            label: Text(
                              "Sort",
                              style:
                                  GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ====================================================
              // ACTIVE FILTERS
              // ====================================================

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
                  child: SingleChildScrollView(
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

                        if (selectedStatus != "All")
                          _activeChip(
                            "Status: $selectedStatus",
                          ),

                        if (selectedOrderType != "All")
                          _activeChip(
                            "Type: $selectedOrderType",
                          ),

                        if (selectedDateFilter != "All")
                          _activeChip(
                            "Date: $selectedDateFilter",
                          ),
                      ],
                    ),
                  ),
                ),

              // ====================================================
              // RESULT COUNT
              // ====================================================

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
                      "${filteredOrders.length} "
                      "order${filteredOrders.length == 1 ? "" : "s"}",

                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Spacer(),

                    Text(
                      "Sort: $selectedSort",

                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // ====================================================
              // ORDER LIST
              // ====================================================

              Expanded(
                child: filteredOrders.isEmpty
                    ? _emptyState(true)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          24,
                        ),
                        itemCount:
                            filteredOrders.length,

                        itemBuilder:
                            (context, index) {
                          final order =
                              filteredOrders[index];

                          final data =
                              order.data()
                                  as Map<String, dynamic>;

                          return OrderCard(
                            orderId: order.id,
                            orderData: data,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue =
        items.contains(value)
            ? value
            : items.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,

      decoration: InputDecoration(
        filled: true,

        fillColor:
            const Color(0xFFF5F6F8),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),

      items: items.map(
        (item) {
          return DropdownMenuItem<String>(
            value: item,

            child: Text(
              item,
              overflow:
                  TextOverflow.ellipsis,

              style: GoogleFonts.poppins(
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
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.only(
        right: 8,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Text(
        label,

        style: GoogleFonts.poppins(
          fontSize: 11,
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState(
    bool filtered,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              filtered
                  ? Icons.search_off
                  : Icons
                      .shopping_bag_outlined,

              size: 60,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            Text(
              filtered
                  ? "No matching orders"
                  : "No orders found",

              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              filtered
                  ? "Try changing your search or filters."
                  : "Orders created for this company will appear here.",

              textAlign: TextAlign.center,

              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            if (filtered) ...[
              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _clearAll,
                child: const Text(
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

  DateTime _orderDate(
    Map<String, dynamic> order,
  ) {
    final possibleDates = [
      order["updatedAt"],
      order["createdAt"],
      order["timestamp"],
      order["orderDate"],
    ];

    for (final value in possibleDates) {
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

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // ORDER NUMBER COMPARISON
  // ============================================================

  int _compareOrderNumbers(
    String first,
    String second,
  ) {
    final firstNumber =
        int.tryParse(first);

    final secondNumber =
        int.tryParse(second);

    if (firstNumber != null &&
        secondNumber != null) {
      return firstNumber.compareTo(
        secondNumber,
      );
    }

    return first
        .toLowerCase()
        .compareTo(
          second.toLowerCase(),
        );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDateOnly(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return "$day/$month/${date.year}";
  }
}