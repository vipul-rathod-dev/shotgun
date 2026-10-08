import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/molding_orders/create_molding_order_page.dart';

import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/molding_orders/molding_order_details_page.dart';
import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/molding_orders/receive_molding_goods_page.dart';
import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/drumming_orders/drumming_order_details_page.dart';
import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/drumming_orders/receive_drumming_goods_page.dart';
import 'package:shotgun/screens/supervisor_screens/raw_product_orders_page/drumming_orders/edit_drumming_order_page.dart';

class RawProductOrdersPage extends StatefulWidget {
  const RawProductOrdersPage({super.key});

  @override
  State<RawProductOrdersPage> createState() => _RawProductOrdersPageState();
}

class _RawProductOrdersPageState extends State<RawProductOrdersPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _companyId;

  late TabController _tabController;

  // Separate search for each tab.*

  final TextEditingController _moldingSearchController =
      TextEditingController();

  final TextEditingController _drummingSearchController =
      TextEditingController();

  String _moldingSearchQuery = '';

  String _drummingSearchQuery = '';

  // Separate sort selection for each tab.*

  String _moldingSort = 'Newest';

  String _drummingSort = 'Newest';

  // Separate filter state for each tab.*

  String _moldingStatus = 'All';

  String _drummingStatus = 'All';

  String _moldingSupplier = 'All';

  String _drummingSupplier = 'All';

  String _moldingDateFilter = 'All';

  String _drummingDateFilter = 'All';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

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

    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();

    final companyId = prefs.getString('cachedCompanyId');

    if (!mounted) return;

    setState(() {
      _companyId = companyId;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _moldingOrdersStream {
    if (_companyId == null || _companyId!.isEmpty) {
      return null;
    }

    return _firestore
        .collection('companies')
        .doc(_companyId)
        .collection('raw_orders')
        .where('process', isEqualTo: 'Molding')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _drummingOrdersStream {
    if (_companyId == null || _companyId!.isEmpty) return null;
    return _firestore
        .collection('companies')
        .doc(_companyId)
        .collection('raw_orders')
        .where('process', isEqualTo: 'Drumming')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _openCreateMoldingOrder() {
    Navigator.pushNamed(context, '/supervisor/create-molding-order');
  }

  void _openCreateDrummingOrder() {
    Navigator.pushNamed(context, '/supervisor/create-drumming-order');
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

              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
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

        children: [_buildMoldingOrdersTab(), _buildDrummingOrdersTab()],
      ),
    );
  }

  // ============================================================*

  // MOLDING TAB*

  // ============================================================*

  DateTime _getOrderDate(Map<String, dynamic> order) {
    final value = order['orderDate'];

    if (value is Timestamp) {
      return value.toDate();
    }

    final createdAt = order['createdAt'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _compareStrings(dynamic a, dynamic b) {
    return (a?.toString() ?? '').toLowerCase().compareTo(
      (b?.toString() ?? '').toLowerCase(),
    );
  }

  List<Map<String, dynamic>> _filterAndSortMoldingOrders(
    List<Map<String, dynamic>> orders,
  ) {
    var result = List<Map<String, dynamic>>.from(orders);

    // ------------------------------------------------------------*

    // SEARCH*

    // ------------------------------------------------------------*

    final query = _moldingSearchQuery.toLowerCase();

    if (query.isNotEmpty) {
      result =
          result.where((order) {
            final orderNumber =
                order['orderNumber']?.toString().toLowerCase() ?? '';

            final supplierName =
                order['supplierName']?.toString().toLowerCase() ?? '';

            final moldName = order['moldName']?.toString().toLowerCase() ?? '';

            final status = order['status']?.toString().toLowerCase() ?? '';

            final items = order['items'] as List? ?? [];

            final productText =
                items
                    .map((item) {
                      if (item is! Map) return '';

                      return [
                        item['productName']?.toString() ?? '',

                        item['productCode']?.toString() ?? '',

                        item['variantType']?.toString() ?? '',

                        item['modelName']?.toString() ?? '',
                      ].join(' ');
                    })
                    .join(' ')
                    .toLowerCase();

            return orderNumber.contains(query) ||
                supplierName.contains(query) ||
                moldName.contains(query) ||
                status.contains(query) ||
                productText.contains(query);
          }).toList();
    }

    // ------------------------------------------------------------*

    // STATUS*

    // ------------------------------------------------------------*

    if (_moldingStatus != 'All') {
      result =
          result.where((order) {
            final status = order['status']?.toString() ?? '';

            return status == _moldingStatus;
          }).toList();
    }

    // ------------------------------------------------------------*

    // SUPPLIER*

    // ------------------------------------------------------------*

    if (_moldingSupplier != 'All') {
      result =
          result.where((order) {
            return order['supplierName']?.toString() == _moldingSupplier;
          }).toList();
    }

    // ------------------------------------------------------------*

    // DATE*

    // ------------------------------------------------------------*

    if (_moldingDateFilter != 'All') {
      final now = DateTime.now();

      result =
          result.where((order) {
            final timestamp = order['orderDate'];

            if (timestamp is! Timestamp) {
              return false;
            }

            final date = timestamp.toDate();

            final today = DateTime(now.year, now.month, now.day);

            final orderDay = DateTime(date.year, date.month, date.day);

            if (_moldingDateFilter == 'Today') {
              return orderDay == today;
            }

            if (_moldingDateFilter == 'Yesterday') {
              final yesterday = today.subtract(const Duration(days: 1));

              return orderDay == yesterday;
            }

            if (_moldingDateFilter == 'Last 7 Days') {
              final start = today.subtract(const Duration(days: 6));

              return !orderDay.isBefore(start);
            }

            if (_moldingDateFilter == 'Last 30 Days') {
              final start = today.subtract(const Duration(days: 29));

              return !orderDay.isBefore(start);
            }

            return true;
          }).toList();
    }

    // ------------------------------------------------------------*

    // SORT*

    // ------------------------------------------------------------*

    result.sort((a, b) {
      final aDate = _getOrderDate(a);

      final bDate = _getOrderDate(b);

      switch (_moldingSort) {
        case 'Newest':
          return bDate.compareTo(aDate);

        case 'Oldest':
          return aDate.compareTo(bDate);

        case 'Order Number A-Z':
          return _compareStrings(a['orderNumber'], b['orderNumber']);

        case 'Order Number Z-A':
          return _compareStrings(b['orderNumber'], a['orderNumber']);

        case 'Supplier A-Z':
          return _compareStrings(a['supplierName'], b['supplierName']);

        case 'Supplier Z-A':
          return _compareStrings(b['supplierName'], a['supplierName']);

        case 'Status A-Z':
          return _compareStrings(a['status'], b['status']);

        case 'Status Z-A':
          return _compareStrings(b['status'], a['status']);

        default:
          return bDate.compareTo(aDate);
      }
    });

    return result;
  }

  Widget _buildOrderInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF6B7280)),

        const SizedBox(width: 8),

        Text(
          '$label:',

          style: GoogleFonts.poppins(
            fontSize: 12,

            color: const Color(0xFF6B7280),
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            value,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.poppins(
              fontSize: 12,

              fontWeight: FontWeight.w500,

              color: const Color(0xFF343741),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityInfo(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),

          style: GoogleFonts.poppins(
            fontSize: 14,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,

          style: GoogleFonts.poppins(
            fontSize: 10,

            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color background;

    Color foreground;

    switch (status) {
      case 'Received':
        background = const Color(0xFFE8F5E9);

        foreground = const Color(0xFF2E7D32);

        break;

      case 'Partially Received':
        background = const Color(0xFFFFF4E5);

        foreground = const Color(0xFFE65100);

        break;

      case 'Cancelled':
        background = const Color(0xFFFFEBEE);

        foreground = const Color(0xFFC62828);

        break;

      case 'Ordered':
      default:
        background = const Color(0xFFEFF2FF);

        foreground = const Color(0xFF3F51B5);

        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: background,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status,

        style: GoogleFonts.poppins(
          fontSize: 10,

          fontWeight: FontWeight.w600,

          color: foreground,
        ),
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _editMoldingOrder(BuildContext context, String orderId) {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder:
            (_) => CreateMoldingOrderPage(isEditMode: true, orderId: orderId),
      ),
    );
  }

  Widget _buildMoldingActionButton({
    required IconData icon,

    required String label,

    required Color color,

    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,

      child: OutlinedButton.icon(
        onPressed: onTap,

        icon: Icon(icon, size: 14),

        label: Text(
          label,

          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        ),

        style: OutlinedButton.styleFrom(
          foregroundColor: color,

          side: BorderSide(color: color.withOpacity(0.35)),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Future<void> _deleteMoldingOrder(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Molding Order'),

          content: const Text(
            'Are you sure you want to delete this molding order?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,

                foregroundColor: Colors.white,
              ),

              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final companyId = prefs.getString('cachedCompanyId');

      final currentUser = FirebaseAuth.instance.currentUser;

      if (companyId == null ||
          companyId.trim().isEmpty ||
          currentUser == null) {
        throw Exception('Missing user or company information.');
      }

      final orderRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('raw_orders')
          .doc(orderId);

      final snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw Exception('Molding order not found.');
      }

      final data = snapshot.data()!;

      final createdByUid = data['createdByUid']?.toString();

      if (createdByUid != currentUser.uid) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete orders you created.'),

            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final status = data['status']?.toString() ?? '';

      if (status != 'Ordered') {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This order cannot be deleted after receiving has started.',
            ),

            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      await orderRef.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Molding order deleted successfully.'),

          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete molding order: $e'),

          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _shotsFromPieces(dynamic pieces, dynamic piecesPerCycle) {
    final pieceCount = _toInt(pieces);
    final cyclePieces = _toInt(piecesPerCycle);

    if (pieceCount <= 0) return 0;
    if (cyclePieces <= 0) return pieceCount;

    return (pieceCount + cyclePieces - 1) ~/ cyclePieces;
  }

  int _calculateMoldShots(
    Map<String, dynamic> mold,
    List<Map<String, dynamic>> fallbackItems,
    String quantityField,
  ) {
    final rawItems = mold['items'];

    final items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : fallbackItems.where((item) {
              final moldId = mold['moldId']?.toString() ?? '';
              final itemMoldId = item['moldProductId']?.toString() ?? '';
              return moldId.isEmpty || itemMoldId == moldId;
            }).toList();

    if (items.isEmpty) return 0;

    // One cavity can have multiple material variants. The operator's
    // quantity for a variant is physical pieces, so convert each item
    // to shots using that cavity's piecesPerCycle.
    //
    // Temple Left and Right are persisted as separate inventory rows,
    // but the operator enters one quantity for both sides. Therefore
    // Left/Right must never be added together here.
    final shotsByCavity = <String, int>{};

    for (final item in items) {
      final cavity =
          item['cavityNumber']?.toString().trim().isNotEmpty == true
              ? item['cavityNumber'].toString()
              : item['cavity']?.toString() ?? '1';

      final itemShots = _shotsFromPieces(
        item[quantityField],
        item['piecesPerCycle'],
      );

      if (itemShots <= 0) continue;

      final current = shotsByCavity[cavity] ?? 0;

      // For Temple Left/Right the two records represent the same
      // molding quantity, so max() prevents double counting.
      //
      // For other variants, max() also matches the molding-cycle view:
      // simultaneous cavities are one shot cycle, not two shot cycles.
      if (itemShots > current) {
        shotsByCavity[cavity] = itemShots;
      }
    }

    if (shotsByCavity.isEmpty) return 0;

    final cavityCount = _toInt(mold['cavityCount'] ?? mold['cavitiesCount']);

    if (cavityCount >= 2) {
      // Two cavities operate simultaneously:
      // Cavity 1 = 100 pieces, Cavity 2 = 100 pieces => 100 shots.
      return shotsByCavity.values.reduce((a, b) => a > b ? a : b);
    }

    return shotsByCavity.values.reduce((a, b) => a + b);
  }

  int _calculateOrderShots(Map<String, dynamic> order, String quantityField) {
    final fallbackItems =
        order['items'] is List
            ? List<dynamic>.from(order['items'])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

    final rawMolds = order['molds'];
    if (rawMolds is List && rawMolds.isNotEmpty) {
      var total = 0;

      for (final rawMold in rawMolds) {
        if (rawMold is! Map) continue;

        total += _calculateMoldShots(
          Map<String, dynamic>.from(rawMold),
          fallbackItems,
          quantityField,
        );
      }

      if (total > 0) return total;
    }

    // Backward compatibility for old single-mold orders.
    final oldMold = <String, dynamic>{
      'moldId': order['moldId'],
      'moldName': order['moldName'],
      'cavityCount': order['cavityCount'],
      'items': fallbackItems,
    };

    return _calculateMoldShots(oldMold, fallbackItems, quantityField);
  }

  Widget _buildMoldingOrderCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';

    final orderNumber = order['orderNumber']?.toString() ?? '-';

    final supplierName = order['supplierName']?.toString() ?? '-';

    final molds =
        order['molds'] is List
            ? List<dynamic>.from(order['molds'])
            : <dynamic>[];

    final moldNames = <String>[];

    for (final mold in molds) {
      if (mold is Map) {
        final name = mold['moldName']?.toString().trim() ?? '';

        if (name.isNotEmpty && !moldNames.contains(name)) {
          moldNames.add(name);
        }
      }
    }

    // Backward compatibility with old single-mold orders.*

    if (moldNames.isEmpty) {
      final oldMoldName = order['moldName']?.toString().trim() ?? '';

      if (oldMoldName.isNotEmpty) {
        moldNames.add(oldMoldName);
      }
    }

    final moldDisplayName = moldNames.isEmpty ? '-' : moldNames.join(', ');

    final status = order['status']?.toString() ?? 'Unknown';

    final orderedShots = _calculateOrderShots(order, 'orderedQuantity');

    final receivedShots = _calculateOrderShots(order, 'receivedQuantity');

    final pendingShots = (orderedShots - receivedShots).clamp(0, orderedShots);

    final variantCount = _toInt(order['variantCount']);

    final moldCount = _toInt(order['moldCount']);

    final orderDate = _getOrderDate(order);

    final items =
        order['items'] is List
            ? List<dynamic>.from(order['items'])
            : <dynamic>[];

    final hasPendingPieces = items.any((rawItem) {
      if (rawItem is! Map) return false;
      final ordered = _toInt(rawItem['orderedQuantity'] ?? rawItem['quantity']);
      final received = _toInt(rawItem['receivedQuantity']);
      return received < ordered;
    });

    final currentUser = FirebaseAuth.instance.currentUser;

    final createdByUid = order['createdByUid']?.toString();

    final isCreatedByCurrentUser =
        currentUser != null &&
        createdByUid != null &&
        createdByUid.isNotEmpty &&
        createdByUid == currentUser.uid;

    final canEdit = isCreatedByCurrentUser && status == 'Ordered';

    final canDelete = isCreatedByCurrentUser && status == 'Ordered';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: const Color(0xFFE5E7EB)),

        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),

            blurRadius: 8,

            offset: Offset(0, 2),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // --------------------------------------------------*

            // HEADER*

            // --------------------------------------------------*
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),

                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2FF),

                    borderRadius: BorderRadius.circular(9),
                  ),

                  child: const Icon(
                    Icons.precision_manufacturing_outlined,

                    size: 20,

                    color: Color(0xFF3F51B5),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        orderNumber,

                        style: GoogleFonts.poppins(
                          fontSize: 15,

                          fontWeight: FontWeight.w600,

                          color: const Color(0xFF343741),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _formatDate(orderDate),

                        style: GoogleFonts.poppins(
                          fontSize: 11,

                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildStatusChip(status),
              ],
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------*

            // ORDER INFORMATION*

            // --------------------------------------------------*
            _buildOrderInfoRow(
              Icons.person_outline,

              'Molding Supplier',

              supplierName,
            ),

            const SizedBox(height: 9),

            _buildOrderInfoRow(
              Icons.view_in_ar_outlined,

              'Mold',

              moldDisplayName,
            ),

            const SizedBox(height: 9),

            _buildOrderInfoRow(
              Icons.layers_outlined,

              'Mold / Variants',

              '$moldCount / $variantCount',
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------*

            // QUANTITY*

            // --------------------------------------------------*
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),

                borderRadius: BorderRadius.circular(9),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: _buildQuantityInfo('Ordered Shots', orderedShots),
                  ),

                  Container(
                    width: 1,

                    height: 34,

                    color: const Color(0xFFE5E7EB),
                  ),

                  Expanded(
                    child: _buildQuantityInfo('Received Shots', receivedShots),
                  ),

                  Container(
                    width: 1,

                    height: 34,

                    color: const Color(0xFFE5E7EB),
                  ),

                  Expanded(
                    child: _buildQuantityInfo('Pending Shots', pendingShots),
                  ),
                ],
              ),
            ),

            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),

              Text(
                '${items.length} variant'
                '${items.length == 1 ? '' : 's'}',

                style: GoogleFonts.poppins(
                  fontSize: 11,

                  fontWeight: FontWeight.w500,

                  color: const Color(0xFF6B7280),
                ),
              ),
            ],

            const SizedBox(height: 12),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            const SizedBox(height: 10),

            // --------------------------------------------------*

            // ACTIONS*

            // --------------------------------------------------*
            Row(
              children: [
                // VIEW*

                Expanded(
                  child: _buildMoldingActionButton(
                    icon: Icons.visibility_outlined,

                    label: 'View',

                    color: Colors.blue,

                    onTap: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder: (_) => MoldingOrderDetailsPage(order: order),
                        ),
                      );
                    },
                  ),
                ),

                if (hasPendingPieces && status != 'Cancelled') ...[
                  const SizedBox(width: 7),
                  Expanded(
                    child: _buildMoldingActionButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Receive',
                      color: Colors.green,
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ReceiveMoldingGoodsPage(
                                  orderId: orderId,
                                  order: order,
                                ),
                          ),
                        );
                        if (changed == true && mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],

                if (canEdit) ...[
                  const SizedBox(width: 7),

                  // EDIT*
                  Expanded(
                    child: _buildMoldingActionButton(
                      icon: Icons.edit_outlined,

                      label: 'Edit',

                      color: Colors.orange,

                      onTap: () {
                        _editMoldingOrder(context, orderId);
                      },
                    ),
                  ),
                ],

                if (canDelete) ...[
                  const SizedBox(width: 7),

                  // DELETE*
                  Expanded(
                    child: _buildMoldingActionButton(
                      icon: Icons.delete_outline,

                      label: 'Delete',

                      color: Colors.red,

                      onTap: () {
                        _deleteMoldingOrder(context, orderId);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoldingOrdersContent(
    List<Map<String, dynamic>> orders, {

    required int totalOrders,
  }) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),

            child: Column(
              children: [
                _buildSearchField(
                  controller: _moldingSearchController,

                  hintText: 'Search molding orders, suppliers, products...',
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.filter_list_outlined,

                        label: 'Filters',

                        active: _hasMoldingFilters,

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

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton.icon(
                    onPressed: _openCreateMoldingOrder,

                    icon: const Icon(Icons.add, size: 19),

                    label: Text(
                      'New Molding Order',

                      style: GoogleFonts.poppins(
                        fontSize: 13,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),

                      foregroundColor: Colors.white,

                      minimumSize: const Size(double.infinity, 46),

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

          if (_hasMoldingFilters) _buildActiveFilterChips(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),

            child: Row(
              children: [
                Text(
                  '${orders.length} ${orders.length == 1 ? 'Order' : 'Orders'}',

                  style: GoogleFonts.poppins(
                    fontSize: 14,

                    fontWeight: FontWeight.w600,

                    color: const Color(0xFF343741),
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    const Icon(Icons.sort, size: 16, color: Color(0xFF6B7280)),

                    const SizedBox(width: 4),

                    Text(
                      _moldingSort,

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

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          Expanded(
            child:
                orders.isEmpty
                    ? _buildEmptyState(
                      icon: Icons.precision_manufacturing_outlined,

                      title:
                          _moldingSearchQuery.isNotEmpty
                              ? 'No Orders Found'
                              : 'No Molding Orders',

                      message:
                          _moldingSearchQuery.isNotEmpty
                              ? 'No orders match your current search.'
                              : 'Molding orders will appear here once they are created.',

                      hasSearch: _moldingSearchQuery.isNotEmpty,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),

                      itemCount: orders.length,

                      separatorBuilder: (_, __) => const SizedBox(height: 12),

                      itemBuilder: (context, index) {
                        return _buildMoldingOrderCard(orders[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoldingOrdersTab() {
    final stream = _moldingOrdersStream;

    if (stream == null) {
      return _buildEmptyState(
        icon: Icons.business_outlined,

        title: 'Company Not Found',

        message: 'Unable to load company information.',

        hasSearch: false,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3F51B5)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Text(
                'Unable to load molding orders.\n\n${snapshot.error}',

                textAlign: TextAlign.center,

                style: GoogleFonts.poppins(
                  fontSize: 13,

                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }

        final orders =
            snapshot.data?.docs.map((doc) {
              final data = doc.data();

              return <String, dynamic>{'id': doc.id, ...data};
            }).toList() ??
            [];

        final filteredOrders = _filterAndSortMoldingOrders(orders);

        return _buildMoldingOrdersContent(
          filteredOrders,

          totalOrders: orders.length,
        );
      },
    );
  }

  // ============================================================*

  // DRUMMING TAB*

  // ============================================================*

  Widget _buildDrummingOrdersTab() {
    final stream = _drummingOrdersStream;
    if (stream == null) {
      return _buildEmptyState(
        icon: Icons.business_outlined,
        title: 'Company Not Found',
        message: 'Unable to load company information.',
        hasSearch: false,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3F51B5)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load drumming orders.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }

        var orders =
            snapshot.data?.docs.map((doc) {
              return <String, dynamic>{'id': doc.id, ...doc.data()};
            }).toList() ??
            <Map<String, dynamic>>[];

        final query = _drummingSearchQuery.toLowerCase();
        if (query.isNotEmpty) {
          orders =
              orders.where((order) {
                final orderNumber =
                    order['orderNumber']?.toString().toLowerCase() ?? '';
                final supplier =
                    order['supplierName']?.toString().toLowerCase() ?? '';
                final source =
                    order['sourceMoldingOrderNumber']
                        ?.toString()
                        .toLowerCase() ??
                    '';
                final rawItems = order['items'];
                final items = rawItems is List ? rawItems : const <dynamic>[];
                final products =
                    items
                        .map((item) {
                          if (item is! Map) return '';
                          return [
                            item['productName']?.toString() ?? '',
                            item['productCode']?.toString() ?? '',
                            item['variantType']?.toString() ?? '',
                            item['modelName']?.toString() ?? '',
                          ].join(' ');
                        })
                        .join(' ')
                        .toLowerCase();
                return orderNumber.contains(query) ||
                    supplier.contains(query) ||
                    source.contains(query) ||
                    products.contains(query);
              }).toList();
        }

        if (_drummingSort == 'Oldest') {
          orders = orders.reversed.toList();
        }

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    _buildSearchField(
                      controller: _drummingSearchController,
                      hintText:
                          'Search drumming orders, suppliers, products...',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.filter_list_outlined,
                            label: 'Filters',
                            active: _hasDrummingFilters,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openCreateDrummingOrder,
                        icon: const Icon(Icons.add, size: 19),
                        label: Text(
                          'New Drumming Order',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${orders.length} ${orders.length == 1 ? 'Order' : 'Orders'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF343741),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _drummingSort,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child:
                    orders.isEmpty
                        ? _buildEmptyState(
                          icon: Icons.rotate_right_outlined,
                          title:
                              _drummingSearchQuery.isNotEmpty
                                  ? 'No Orders Found'
                                  : 'No Drumming Orders',
                          message:
                              _drummingSearchQuery.isNotEmpty
                                  ? 'No orders match your current search.'
                                  : 'Drumming orders will appear here once molding goods are received.',
                          hasSearch: _drummingSearchQuery.isNotEmpty,
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder:
                              (context, index) =>
                                  _buildDrummingOrderCard(orders[index]),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteDrummingOrder(Map<String, dynamic> order) async {
    final companyId = _companyId;
    final orderId = order['id']?.toString() ?? '';
    final orderNumber = order['orderNumber']?.toString() ?? '-';
    final receivedPieces = _toInt(order['receivedPieces']);

    if (companyId == null || companyId.isEmpty || orderId.isEmpty) {
      _showDrummingMessage('Unable to delete this order.', error: true);
      return;
    }

    // Never remove an order after receiving goods because the receiving flow
    // has already affected inventory.
    if (receivedPieces > 0) {
      _showDrummingMessage(
        'Order $orderNumber cannot be deleted because goods have already been received.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              'Delete Drumming Order?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'This will permanently delete $orderNumber. This action cannot be undone.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: Text(
                  'Delete',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('raw_orders')
          .doc(orderId)
          .delete();

      if (mounted) {
        _showDrummingMessage('Drumming order $orderNumber deleted.');
      }
    } catch (e) {
      if (mounted) {
        _showDrummingMessage(
          'Unable to delete order: ${e.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    }
  }

  void _showDrummingMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildDrummingActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildDrummingOrderCard(Map<String, dynamic> order) {
    final orderNumber = order['orderNumber']?.toString() ?? '-';
    final status = order['status']?.toString() ?? 'Pending';
    final supplier = order['supplierName']?.toString() ?? '-';
    final source = order['sourceMoldingOrderNumber']?.toString() ?? '-';
    final orderedPieces = _toInt(order['orderedPieces']);
    final receivedPieces = _toInt(order['receivedPieces']);
    final pendingPieces = (orderedPieces - receivedPieces).clamp(
      0,
      orderedPieces,
    );
    final rawItems = order['items'];
    final items = rawItems is List ? rawItems : const <dynamic>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rotate_right_outlined, color: Color(0xFF3F51B5)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  orderNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          _buildOrderInfoRow(
            Icons.person_outline,
            'Drumming Supplier',
            supplier,
          ),
          const SizedBox(height: 8),
          _buildOrderInfoRow(Icons.link_outlined, 'Molding Order', source),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuantityInfo('Ordered Pieces', orderedPieces),
                ),
                Container(width: 1, height: 34, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: _buildQuantityInfo('Received Pieces', receivedPieces),
                ),
                Container(width: 1, height: 34, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: _buildQuantityInfo('Pending Pieces', pendingPieces),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            const SizedBox(height: 10),

            Row(
              children: [
                // VIEW
                Expanded(
                  child: _buildDrummingActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => DrummingOrderDetailsPage(order: order),
                        ),
                      );
                    },
                  ),
                ),

                // RECEIVE
                if (pendingPieces > 0 && status != 'Cancelled') ...[
                  const SizedBox(width: 7),
                  Expanded(
                    child: _buildDrummingActionButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Receive',
                      color: Colors.green,
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ReceiveDrummingGoodsPage(
                                  orderId: order['id']?.toString() ?? '',
                                  order: order,
                                ),
                          ),
                        );
                        if (changed == true && mounted) setState(() {});
                      },
                    ),
                  ),
                ],

                // EDIT
                const SizedBox(width: 7),
                Expanded(
                  child: _buildDrummingActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: Colors.orange,
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => EditDrummingOrderPage(
                                orderId: order['id']?.toString() ?? '',
                                order: order,
                              ),
                        ),
                      );
                      if (changed == true && mounted) setState(() {});
                    },
                  ),
                ),

                // DELETE
                const SizedBox(width: 7),
                Expanded(
                  child: _buildDrummingActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: () => _deleteDrummingOrder(order),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================*

  // SEARCH FIELD*

  // ============================================================*

  Widget _buildSearchField({
    required TextEditingController controller,

    required String hintText,
  }) {
    return TextField(
      controller: controller,

      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF343741)),

      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: GoogleFonts.poppins(
          fontSize: 13,

          color: const Color(0xFF9CA3AF),
        ),

        prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),

        suffixIcon:
            controller.text.isNotEmpty
                ? IconButton(
                  onPressed: controller.clear,

                  icon: const Icon(Icons.clear, size: 19),
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

          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),

          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),

          borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5),
        ),
      ),
    );
  }

  // ============================================================*

  // ACTION BUTTON*

  // ============================================================*

  Widget _buildActionButton({
    required IconData icon,

    required String label,

    required bool active,

    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,

      icon: Icon(icon, size: 18),

      label: Text(
        label,

        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),

      style: OutlinedButton.styleFrom(
        foregroundColor:
            active ? const Color(0xFF3F51B5) : const Color(0xFF4B5563),

        backgroundColor: active ? const Color(0xFFEFF2FF) : Colors.white,

        side: BorderSide(
          color: active ? const Color(0xFF3F51B5) : const Color(0xFFD1D5DB),
        ),

        minimumSize: const Size(double.infinity, 44),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  // ============================================================*

  // ACTIVE FILTER CHIPS*

  // ============================================================*

  Widget _buildActiveFilterChips() {
    final List<Widget> chips = [];

    final status = _isMoldingTab ? _moldingStatus : _drummingStatus;

    final supplier = _isMoldingTab ? _moldingSupplier : _drummingSupplier;

    final dateFilter = _isMoldingTab ? _moldingDateFilter : _drummingDateFilter;

    if (status != 'All') {
      chips.add(_buildFilterChip(label: 'Status: $status'));
    }

    if (supplier != 'All') {
      chips.add(_buildFilterChip(label: 'Supplier: $supplier'));
    }

    if (dateFilter != 'All') {
      chips.add(_buildFilterChip(label: 'Date: $dateFilter'));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),

      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _buildFilterChip({required String label}) {
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

      side: const BorderSide(color: Color(0xFFD7DDFF)),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      visualDensity: VisualDensity.compact,
    );
  }

  // ============================================================*

  // FILTER SHEET*

  // ============================================================*

  Future<void> _showFilterSheet() async {
    final isMolding = _isMoldingTab;

    String tempStatus = isMolding ? _moldingStatus : _drummingStatus;

    String tempSupplier = isMolding ? _moldingSupplier : _drummingSupplier;

    String tempDateFilter =
        isMolding ? _moldingDateFilter : _drummingDateFilter;

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

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

                      items: const ['All'],

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

                                  _moldingDateFilter = tempDateFilter;
                                } else {
                                  _drummingStatus = tempStatus;

                                  _drummingSupplier = tempSupplier;

                                  _drummingDateFilter = tempDateFilter;
                                }
                              });
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3F51B5),

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

  // ============================================================*

  // DROPDOWN FILTER*

  // ============================================================*

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

          items:
              items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,

                      child: Text(
                        item,

                        style: GoogleFonts.poppins(fontSize: 13),
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

              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),

              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================*

  // SORT SHEET*

  // ============================================================*

  Future<void> _showSortSheet() async {
    final isMolding = _isMoldingTab;

    String selectedSort = isMolding ? _moldingSort : _drummingSort;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

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

                    ...sortOptions.map((option) {
                      return RadioListTile<String>(
                        value: option,

                        groupValue: selectedSort,

                        activeColor: const Color(0xFF3F51B5),

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
                    }),

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
                          backgroundColor: const Color(0xFF3F51B5),

                          foregroundColor: Colors.white,

                          minimumSize: const Size.fromHeight(46),
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

  // ============================================================*

  // CLEAR FILTERS*

  // ============================================================*

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

  // ============================================================*

  // EMPTY STATE*

  // ============================================================*

  Widget _buildEmptyState({
    required IconData icon,

    required String title,

    required String message,

    required bool hasSearch,
  }) {
    if (hasSearch) {
      title = 'No Orders Found';

      message = 'No orders match your current search.';

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

              child: Icon(icon, size: 38, color: const Color(0xFF3F51B5)),
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
