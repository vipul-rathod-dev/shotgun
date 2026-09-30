import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RawProductOrdersPage extends StatefulWidget {
  const RawProductOrdersPage({super.key});

  @override
  State<RawProductOrdersPage> createState() => _RawProductOrdersPageState();
}

class _RawProductOrdersPageState extends State<RawProductOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Separate search for each tab.
  final TextEditingController _moldingSearchController =
      TextEditingController();

  final TextEditingController _drummingSearchController =
      TextEditingController();

  String _moldingSearchQuery = '';
  String _drummingSearchQuery = '';

  // Separate sort selection for each tab.
  String _moldingSort = 'Newest';
  String _drummingSort = 'Newest';

  // Separate filter state for each tab.
  String _moldingStatus = 'All';
  String _drummingStatus = 'All';

  String _moldingSupplier = 'All';
  String _drummingSupplier = 'All';

  String _moldingDateFilter = 'All';
  String _drummingDateFilter = 'All';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _moldingSearchController.addListener(() {
      setState(() {
        _moldingSearchQuery = _moldingSearchController.text.trim();
      });
    });

    _drummingSearchController.addListener(() {
      setState(() {
        _drummingSearchQuery = _drummingSearchController.text.trim();
      });
    });
  }

  void _openCreateMoldingOrder() {
    Navigator.pushNamed(
      context,
      '/supervisor/create-molding-order',
    );
  }

  void _openCreateDrummingOrder() {
    Navigator.pushNamed(
      context,
      '/supervisor/create-drumming-order',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _moldingSearchController.dispose();
    _drummingSearchController.dispose();
    super.dispose();
  }

  bool get _isMoldingTab => _tabController.index == 0;

  bool get _hasMoldingFilters {
    return _moldingStatus != 'All' ||
        _moldingSupplier != 'All' ||
        _moldingDateFilter != 'All';
  }

  bool get _hasDrummingFilters {
    return _drummingStatus != 'All' ||
        _drummingSupplier != 'All' ||
        _drummingDateFilter != 'All';
  }

  bool get _hasActiveFilters {
    return _isMoldingTab ? _hasMoldingFilters : _hasDrummingFilters;
  }

  String get _currentSort {
    return _isMoldingTab ? _moldingSort : _drummingSort;
  }

  String get _currentSearchQuery {
    return _isMoldingTab
        ? _moldingSearchQuery
        : _drummingSearchQuery;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,

        title: Text(
          'Raw Product Orders',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF343741),
          ),
        ),

        actions: [
          if (_hasActiveFilters)
            IconButton(
              tooltip: 'Clear Filters',
              onPressed: _clearCurrentFilters,
              icon: const Icon(
                Icons.filter_alt_off_outlined,
                color: Color(0xFF3F51B5),
              ),
            ),

          const SizedBox(width: 8),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,

              onTap: (_) {
                setState(() {});
              },

              indicatorColor: const Color(0xFF3F51B5),
              indicatorWeight: 3,

              labelColor: const Color(0xFF3F51B5),
              unselectedLabelColor: const Color(0xFF6B7280),

              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),

              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),

              tabs: const [
                Tab(
                  icon: Icon(Icons.precision_manufacturing_outlined),
                  text: 'Molding Orders',
                ),
                Tab(
                  icon: Icon(Icons.rotate_right_outlined),
                  text: 'Drumming Orders',
                ),
              ],
            ),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMoldingOrdersTab(),
          _buildDrummingOrdersTab(),
        ],
      ),
    );
  }

  // ============================================================
  // MOLDING TAB
  // ============================================================

  Widget _buildMoldingOrdersTab() {
    return _buildOrderTab(
      searchController: _moldingSearchController,
      searchHint: 'Search molding orders, suppliers, products...',
      orderCount: 0,
      emptyIcon: Icons.precision_manufacturing_outlined,
      emptyTitle: 'No Molding Orders',
      emptyMessage:
          'Molding orders will appear here once they are created.',
      onNewOrder: _openCreateMoldingOrder,
      newOrderLabel: 'New Molding Order',
    );
  }

  // ============================================================
  // DRUMMING TAB
  // ============================================================

  Widget _buildDrummingOrdersTab() {
    return _buildOrderTab(
      searchController: _drummingSearchController,
      searchHint: 'Search drumming orders, suppliers, products...',
      orderCount: 0,
      emptyIcon: Icons.rotate_right_outlined,
      emptyTitle: 'No Drumming Orders',
      emptyMessage:
          'Drumming orders will appear here once they are created.',
      onNewOrder: _openCreateDrummingOrder,
      newOrderLabel: 'New Drumming Order',
    );
  }

  // ============================================================
  // COMMON TAB UI
  // ============================================================

  Widget _buildOrderTab({
    required TextEditingController searchController,
    required String searchHint,
    required int orderCount,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    required VoidCallback onNewOrder,
    required String newOrderLabel,
  }) {
    return SafeArea(
      child: Column(
        children: [
          // ------------------------------------------------------
          // SEARCH + FILTER + SORT
          // ------------------------------------------------------

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            child: Column(
              children: [
                _buildSearchField(
                  controller: searchController,
                  hintText: searchHint,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.filter_list_outlined,
                        label: 'Filters',
                        active: _hasActiveFilters,
                        onPressed: _showFilterSheet,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.sort_outlined,
                        label: 'Sort',
                        active: false,
                        onPressed: _showSortSheet,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNewOrder,
                    icon: const Icon(
                      Icons.add,
                      size: 19,
                    ),
                    label: Text(
                      newOrderLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        double.infinity,
                        46,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // ACTIVE FILTER CHIPS
          // ------------------------------------------------------

          if (_hasActiveFilters)
            _buildActiveFilterChips(),

          // ------------------------------------------------------
          // RESULT COUNT
          // ------------------------------------------------------

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8,
            ),
            child: Row(
              children: [
                Text(
                  '$orderCount ${orderCount == 1 ? 'Order' : 'Orders'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    const Icon(
                      Icons.sort,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentSort,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE5E7EB),
          ),

          // ------------------------------------------------------
          // ORDER LIST
          // ------------------------------------------------------

          Expanded(
            child: _buildEmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              hasSearch: _currentSearchQuery.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH FIELD
  // ============================================================

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,

      style: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF343741),
      ),

      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFF9CA3AF),
        ),

        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF6B7280),
        ),

        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: controller.clear,
                icon: const Icon(
                  Icons.clear,
                  size: 19,
                ),
              )
            : null,

        filled: true,
        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF3F51B5),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,

      icon: Icon(
        icon,
        size: 18,
      ),

      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      style: OutlinedButton.styleFrom(
        foregroundColor: active
            ? const Color(0xFF3F51B5)
            : const Color(0xFF4B5563),

        backgroundColor: active
            ? const Color(0xFFEFF2FF)
            : Colors.white,

        side: BorderSide(
          color: active
              ? const Color(0xFF3F51B5)
              : const Color(0xFFD1D5DB),
        ),

        minimumSize: const Size(
          double.infinity,
          44,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
  }

  // ============================================================
  // ACTIVE FILTER CHIPS
  // ============================================================

  Widget _buildActiveFilterChips() {
    final List<Widget> chips = [];

    final status = _isMoldingTab
        ? _moldingStatus
        : _drummingStatus;

    final supplier = _isMoldingTab
        ? _moldingSupplier
        : _drummingSupplier;

    final dateFilter = _isMoldingTab
        ? _moldingDateFilter
        : _drummingDateFilter;

    if (status != 'All') {
      chips.add(
        _buildFilterChip(
          label: 'Status: $status',
        ),
      );
    }

    if (supplier != 'All') {
      chips.add(
        _buildFilterChip(
          label: 'Supplier: $supplier',
        ),
      );
    }

    if (dateFilter != 'All') {
      chips.add(
        _buildFilterChip(
          label: 'Date: $dateFilter',
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        4,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
  }) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF3F51B5),
        ),
      ),

      backgroundColor: const Color(0xFFEFF2FF),

      side: const BorderSide(
        color: Color(0xFFD7DDFF),
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      visualDensity: VisualDensity.compact,
    );
  }

  // ============================================================
  // FILTER SHEET
  // ============================================================

  Future<void> _showFilterSheet() async {
    final isMolding = _isMoldingTab;

    String tempStatus = isMolding
        ? _moldingStatus
        : _drummingStatus;

    String tempSupplier = isMolding
        ? _moldingSupplier
        : _drummingSupplier;

    String tempDateFilter = isMolding
        ? _moldingDateFilter
        : _drummingDateFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Filter ${isMolding ? 'Molding' : 'Drumming'} Orders',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343741),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildDropdownFilter(
                      label: 'Status',
                      value: tempStatus,
                      items: const [
                        'All',
                        'Pending',
                        'In Progress',
                        'Completed',
                        'Cancelled',
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          tempStatus = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    _buildDropdownFilter(
                      label: 'Supplier',
                      value: tempSupplier,
                      items: const [
                        'All',
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          tempSupplier = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    _buildDropdownFilter(
                      label: 'Date',
                      value: tempDateFilter,
                      items: const [
                        'All',
                        'Today',
                        'Yesterday',
                        'Last 7 Days',
                        'Last 30 Days',
                        'Custom',
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          tempDateFilter = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);

                              setState(() {
                                if (isMolding) {
                                  _moldingStatus = 'All';
                                  _moldingSupplier = 'All';
                                  _moldingDateFilter = 'All';
                                } else {
                                  _drummingStatus = 'All';
                                  _drummingSupplier = 'All';
                                  _drummingDateFilter = 'All';
                                }
                              });
                            },
                            child: Text(
                              'Reset',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);

                              setState(() {
                                if (isMolding) {
                                  _moldingStatus = tempStatus;
                                  _moldingSupplier = tempSupplier;
                                  _moldingDateFilter =
                                      tempDateFilter;
                                } else {
                                  _drummingStatus = tempStatus;
                                  _drummingSupplier = tempSupplier;
                                  _drummingDateFilter =
                                      tempDateFilter;
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF3F51B5),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'Apply Filters',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
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
  // DROPDOWN FILTER
  // ============================================================

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),

        const SizedBox(height: 6),

        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                    ),
                  ),
                ),
              )
              .toList(),

          onChanged: onChanged,

          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
              ),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SORT SHEET
  // ============================================================

  Future<void> _showSortSheet() async {
    final isMolding = _isMoldingTab;

    String selectedSort = isMolding
        ? _moldingSort
        : _drummingSort;

    final sortOptions = [
      'Newest',
      'Oldest',
      'Order Number A-Z',
      'Order Number Z-A',
      'Supplier A-Z',
      'Supplier Z-A',
      'Status A-Z',
      'Status Z-A',
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Sort Orders',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343741),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...sortOptions.map(
                      (option) {
                        return RadioListTile<String>(
                          value: option,
                          groupValue: selectedSort,
                          activeColor:
                              const Color(0xFF3F51B5),

                          title: Text(
                            option,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF343741),
                            ),
                          ),

                          onChanged: (value) {
                            setSheetState(() {
                              selectedSort = value!;
                            });
                          },

                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);

                          setState(() {
                            if (isMolding) {
                              _moldingSort = selectedSort;
                            } else {
                              _drummingSort = selectedSort;
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size.fromHeight(46),
                        ),
                        child: Text(
                          'Apply Sort',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
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
      },
    );
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void _clearCurrentFilters() {
    setState(() {
      if (_isMoldingTab) {
        _moldingStatus = 'All';
        _moldingSupplier = 'All';
        _moldingDateFilter = 'All';
      } else {
        _drummingStatus = 'All';
        _drummingSupplier = 'All';
        _drummingDateFilter = 'All';
      }
    });
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required bool hasSearch,
  }) {
    if (hasSearch) {
      title = 'No Orders Found';
      message =
          'No orders match your current search.';
      icon = Icons.search_off_outlined;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 38,
                color: const Color(0xFF3F51B5),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF343741),
              ),
            ),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}