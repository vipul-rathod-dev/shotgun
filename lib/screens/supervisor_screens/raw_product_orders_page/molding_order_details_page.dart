import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'create_molding_order_page.dart';

class MoldingOrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const MoldingOrderDetailsPage({
    super.key,
    required this.order,
  });

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

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

  String _formatDate(dynamic value) {
    final date = _toDateTime(value);

    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatDateTime(dynamic value) {
    final date = _toDateTime(value);

    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  String _decimal(dynamic value) {
    final number = _toDouble(value);

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  List<Map<String, dynamic>> _getItems() {
    final rawItems = order['items'];

    if (rawItems is! List) {
      return [];
    }

    return rawItems
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  List<Map<String, dynamic>> _getMolds() {
    final rawMolds = order['molds'];

    if (rawMolds is List) {
      final molds = rawMolds
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      if (molds.isNotEmpty) {
        return molds;
      }
    }

    // ------------------------------------------------------------
    // Backward compatibility for old single-mold orders
    // ------------------------------------------------------------

    final moldName = _stringValue(order['moldName']);
    final moldId = _stringValue(order['moldId']);

    if (moldName.isEmpty && moldId.isEmpty) {
      return [];
    }

    final allItems = _getItems();

    return [
      {
        'moldId': moldId,
        'moldName': moldName,
        'cavityCount': _toInt(order['cavityCount']),
        'orderedPieces': _toInt(order['orderedPieces']),
        'items': allItems,
      },
    ];
  }

  List<Map<String, dynamic>> _getMoldItems(
    Map<String, dynamic> mold,
  ) {
    final rawItems = mold['items'];

    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    final moldId = _stringValue(mold['moldId']);
    final allItems = _getItems();

    if (moldId.isEmpty) {
      return allItems;
    }

    return allItems.where((item) {
      final itemMoldId = _stringValue(item['moldProductId']);

      return itemMoldId == moldId;
    }).toList();
  }

  int _calculateMoldOrderedQuantity(
    Map<String, dynamic> mold,
  ) {
    final stored = _toInt(mold['orderedPieces']);

    if (stored > 0) {
      return stored;
    }

    final items = _getMoldItems(mold);

    return items.fold<int>(
      0,
      (total, item) =>
          total + _toInt(item['orderedQuantity']),
    );
  }

  int _calculateMoldReceivedQuantity(
    Map<String, dynamic> mold,
  ) {
    final items = _getMoldItems(mold);

    return items.fold<int>(
      0,
      (total, item) =>
          total + _toInt(item['receivedQuantity']),
    );
  }

  int _calculateItemPending(Map<String, dynamic> item) {
    final ordered = _toInt(item['orderedQuantity']);
    final received = _toInt(item['receivedQuantity']);

    return (ordered - received).clamp(0, ordered);
  }

  int _calculateTotalOrdered() {
    final stored = _toInt(order['orderedPieces']);

    if (stored > 0) {
      return stored;
    }

    final items = _getItems();

    return items.fold<int>(
      0,
      (total, item) =>
          total + _toInt(item['orderedQuantity']),
    );
  }

  int _calculateTotalReceived() {
    final stored = _toInt(order['receivedPieces']);

    if (stored > 0) {
      return stored;
    }

    final items = _getItems();

    return items.fold<int>(
      0,
      (total, item) =>
          total + _toInt(item['receivedQuantity']),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final orderNumber =
        _stringValue(order['orderNumber']).isEmpty
            ? '-'
            : _stringValue(order['orderNumber']);

    final status =
        _stringValue(order['status']).isEmpty
            ? 'Unknown'
            : _stringValue(order['status']);

    final supplier =
        _stringValue(order['supplierName']).isEmpty
            ? '-'
            : _stringValue(order['supplierName']);

    final process =
        _stringValue(order['process']).isEmpty
            ? 'Molding'
            : _stringValue(order['process']);

    final molds = _getMolds();

    final totalOrdered = _calculateTotalOrdered();
    final totalReceived = _calculateTotalReceived();

    final totalPending =
        (totalOrdered - totalReceived).clamp(
      0,
      totalOrdered,
    );

    final variantCount =
        _toInt(order['variantCount']) > 0
            ? _toInt(order['variantCount'])
            : _getItems().length;

    final moldCount =
        _toInt(order['moldCount']) > 0
            ? _toInt(order['moldCount'])
            : molds.length;

    final cavityCount =
        _toInt(order['cavityCount']);

    final orderId = _stringValue(order['id']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF343741),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              orderNumber,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF343741),
              ),
            ),
            Text(
              'Molding Order Details',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          if (orderId.isNotEmpty && status == 'Ordered')
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateMoldingOrderPage(
                        isEditMode: true,
                        orderId: orderId,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(
                  'Edit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(
              isMobile ? 12 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(
                      orderNumber: orderNumber,
                      status: status,
                      process: process,
                    ),

                    const SizedBox(height: 16),

                    _buildQuantitySummary(
                      ordered: totalOrdered,
                      received: totalReceived,
                      pending: totalPending,
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 16),

                    _buildInformationCard(
                      supplier: supplier,
                      process: process,
                      moldCount: moldCount,
                      cavityCount: cavityCount,
                      variantCount: variantCount,
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 16),

                    _buildDateInformation(
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'Mold Details',
                      subtitle:
                          '${molds.length} mold${molds.length == 1 ? '' : 's'} in this order',
                    ),

                    const SizedBox(height: 12),

                    if (molds.isEmpty)
                      _buildEmptyCard(
                        'No mold details found.',
                      )
                    else
                      ...molds.asMap().entries.map(
                        (entry) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 16,
                            ),
                            child: _buildMoldCard(
                              mold: entry.value,
                              index: entry.key + 1,
                              isMobile: isMobile,
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 8),

                    _buildSectionTitle(
                      icon: Icons.inventory_2_outlined,
                      title: 'All Order Items',
                      subtitle:
                          '${_getItems().length} variants',
                    ),

                    const SizedBox(height: 12),

                    _buildAllItemsSection(
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 24),

                    _buildAuditInformation(
                      isMobile: isMobile,
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderCard({
    required String orderNumber,
    required String status,
    required String process,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              color: Color(0xFF3F51B5),
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF343741),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$process Order',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          _buildStatusChip(status),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color background;
    Color foreground;

    switch (status.toLowerCase()) {
      case 'ordered':
        background = const Color(0xFFEFF2FF);
        foreground = const Color(0xFF3F51B5);
        break;

      case 'received':
      case 'completed':
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        break;

      case 'partial':
      case 'partially received':
        background = const Color(0xFFFFF4E5);
        foreground = const Color(0xFFE65100);
        break;

      case 'cancelled':
        background = const Color(0xFFFFEBEE);
        foreground = const Color(0xFFC62828);
        break;

      default:
        background = const Color(0xFFF3F4F6);
        foreground = const Color(0xFF4B5563);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  // ============================================================
  // QUANTITY SUMMARY
  // ============================================================

  Widget _buildQuantitySummary({
    required int ordered,
    required int received,
    required int pending,
    required bool isMobile,
  }) {
    final cards = [
      _QuantityData(
        title: 'Ordered',
        value: ordered,
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF3F51B5),
      ),
      _QuantityData(
        title: 'Received',
        value: received,
        icon: Icons.check_circle_outline,
        color: const Color(0xFF2E7D32),
      ),
      _QuantityData(
        title: 'Pending',
        value: pending,
        icon: Icons.pending_outlined,
        color: const Color(0xFFE65100),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  _buildQuantityCard(cards[i]),
                  if (i != cards.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(
                    child: _buildQuantityCard(
                      cards[i],
                    ),
                  ),
                  if (i != cards.length - 1)
                    Container(
                      width: 1,
                      height: 50,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      color: const Color(0xFFE5E7EB),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _buildQuantityCard(
    _QuantityData data,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              data.icon,
              size: 20,
              color: data.color,
            ),
          ),

          const SizedBox(width: 11),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                data.value.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF343741),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION
  // ============================================================

  Widget _buildInformationCard({
    required String supplier,
    required String process,
    required int moldCount,
    required int cavityCount,
    required int variantCount,
    required bool isMobile,
  }) {
    final items = [
      _InfoData(
        icon: Icons.person_outline,
        label: 'Molding Supplier',
        value: supplier,
      ),
      _InfoData(
        icon: Icons.factory_outlined,
        label: 'Process',
        value: process,
      ),
      _InfoData(
        icon: Icons.view_in_ar_outlined,
        label: 'Molds',
        value: moldCount.toString(),
      ),
      _InfoData(
        icon: Icons.grid_view_outlined,
        label: 'Cavities',
        value: cavityCount.toString(),
      ),
      _InfoData(
        icon: Icons.category_outlined,
        label: 'Variants',
        value: variantCount.toString(),
      ),
    ];

    return _buildWhiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Order Information',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF343741),
            ),
          ),

          const SizedBox(height: 14),

          if (isMobile)
            Column(
              children: [
                for (final item in items) ...[
                  _buildInfoRow(item),
                  const SizedBox(height: 10),
                ],
              ],
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 18,
              children: items.map(
                (item) {
                  return SizedBox(
                    width: 205,
                    child: _buildInfoRow(item),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDateInformation({
    required bool isMobile,
  }) {
    return _buildWhiteCard(
      child: isMobile
          ? Column(
              children: [
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.calendar_today_outlined,
                    label: 'Order Date',
                    value: _formatDate(
                      order['orderDate'],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.schedule_outlined,
                    label: 'Created At',
                    value: _formatDateTime(
                      order['createdAt'],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.update_outlined,
                    label: 'Last Updated',
                    value: _formatDateTime(
                      order['updatedAt'],
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.calendar_today_outlined,
                      label: 'Order Date',
                      value: _formatDate(
                        order['orderDate'],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.schedule_outlined,
                      label: 'Created At',
                      value: _formatDateTime(
                        order['createdAt'],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.update_outlined,
                      label: 'Last Updated',
                      value: _formatDateTime(
                        order['updatedAt'],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(
    _InfoData data,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            data.icon,
            size: 18,
            color: const Color(0xFF3F51B5),
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF343741),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOLD
  // ============================================================

  Widget _buildMoldCard({
    required Map<String, dynamic> mold,
    required int index,
    required bool isMobile,
  }) {
    final moldName =
        _stringValue(mold['moldName']).isEmpty
            ? '-'
            : _stringValue(mold['moldName']);

    final moldId =
        _stringValue(mold['moldId']);

    final cavityCount =
        _toInt(mold['cavityCount']);

    final items = _getMoldItems(mold);

    final ordered =
        _calculateMoldOrderedQuantity(mold);

    final received =
        _calculateMoldReceivedQuantity(mold);

    final pending =
        (ordered - received).clamp(
      0,
      ordered,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFF),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2FF),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.view_in_ar_outlined,
                    color: Color(0xFF3F51B5),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mold $index',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        moldName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              const Color(0xFF343741),
                        ),
                      ),
                      if (moldId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: $moldId',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color:
                                const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (cavityCount > 0)
                  _smallBadge(
                    '$cavityCount Cavity${cavityCount == 1 ? '' : 'ies'}',
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildMoldQuantitySummary(
                  ordered: ordered,
                  received: received,
                  pending: pending,
                  isMobile: isMobile,
                ),

                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mold Variants',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          const Color(0xFF343741),
                    ),
                  ),
                ),

                const SizedBox(height: 9),

                if (items.isEmpty)
                  _buildEmptyCard(
                    'No variants found for this mold.',
                  )
                else
                  _buildMoldItems(
                    items,
                    isMobile: isMobile,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoldQuantitySummary({
    required int ordered,
    required int received,
    required int pending,
    required bool isMobile,
  }) {
    final values = [
      ('Ordered', ordered, const Color(0xFF3F51B5)),
      ('Received', received, const Color(0xFF2E7D32)),
      ('Pending', pending, const Color(0xFFE65100)),
    ];

    return isMobile
        ? Column(
            children: [
              for (final item in values) ...[
                _buildSmallQuantity(
                  item.$1,
                  item.$2,
                  item.$3,
                ),
                if (item != values.last)
                  const SizedBox(height: 7),
              ],
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                Expanded(
                  child: _buildSmallQuantity(
                    values[i].$1,
                    values[i].$2,
                    values[i].$3,
                  ),
                ),
                if (i != values.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          );
  }

  Widget _buildSmallQuantity(
    String label,
    int value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOLD ITEMS
  // ============================================================

  Widget _buildMoldItems(
    List<Map<String, dynamic>> items, {
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: items.map(
          (item) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _buildItemCard(item),
            );
          },
        ).toList(),
      );
    }

    return Column(
      children: [
        _buildDesktopItemHeader(),
        const SizedBox(height: 5),
        ...items.map(
          (item) => _buildDesktopItemRow(item),
        ),
      ],
    );
  }

  Widget _buildDesktopItemHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 75),
          Expanded(
            flex: 3,
            child: _tableHeader('Product'),
          ),
          Expanded(
            flex: 2,
            child: _tableHeader('Variant'),
          ),
          Expanded(
            child: _tableHeader('Cavity'),
          ),
          Expanded(
            child: _tableHeader('Ordered'),
          ),
          Expanded(
            child: _tableHeader('Received'),
          ),
          Expanded(
            child: _tableHeader('Pending'),
          ),
          Expanded(
            child: _tableHeader('Virgin'),
          ),
          Expanded(
            child: _tableHeader('Grinding'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopItemRow(
    Map<String, dynamic> item,
  ) {
    final ordered =
        _toInt(item['orderedQuantity']);

    final received =
        _toInt(item['receivedQuantity']);

    final pending =
        _calculateItemPending(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: _variantBadge(
              _stringValue(
                item['variantType'],
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: _productInfo(item),
          ),

          Expanded(
            flex: 2,
            child: Text(
              _stringValue(
                item['variantType'],
              ).isEmpty
                  ? '-'
                  : _stringValue(
                      item['variantType'],
                    ),
              style: _tableValueStyle(),
            ),
          ),

          Expanded(
            child: Text(
              _stringValue(
                item['cavityNumber'],
              ).isEmpty
                  ? '-'
                  : _stringValue(
                      item['cavityNumber'],
                    ),
              style: _tableValueStyle(),
            ),
          ),

          Expanded(
            child: _numberText(
              ordered,
            ),
          ),

          Expanded(
            child: _numberText(
              received,
              color: const Color(0xFF2E7D32),
            ),
          ),

          Expanded(
            child: _numberText(
              pending,
              color: pending > 0
                  ? const Color(0xFFE65100)
                  : const Color(0xFF6B7280),
            ),
          ),

          Expanded(
            child: _ratioText(
              item['virginRatio'],
            ),
          ),

          Expanded(
            child: _ratioText(
              item['grindingRatio'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
  ) {
    final ordered =
        _toInt(item['orderedQuantity']);

    final received =
        _toInt(item['receivedQuantity']);

    final pending =
        _calculateItemPending(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _variantBadge(
                _stringValue(
                  item['variantType'],
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  _stringValue(
                    item['productName'],
                  ).isEmpty
                      ? '-'
                      : _stringValue(
                          item['productName'],
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        const Color(0xFF343741),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          if (_stringValue(
            item['productCode'],
          ).isNotEmpty)
            _mobileDetail(
              'Product Code',
              _stringValue(
                item['productCode'],
              ),
            ),

          if (_stringValue(
            item['modelName'],
          ).isNotEmpty)
            _mobileDetail(
              'Model',
              _stringValue(
                item['modelName'],
              ),
            ),

          _mobileDetail(
            'Cavity',
            _stringValue(
              item['cavityNumber'],
            ).isEmpty
                ? '-'
                : _stringValue(
                    item['cavityNumber'],
                  ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _mobileQuantity(
                  'Ordered',
                  ordered,
                  const Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileQuantity(
                  'Received',
                  received,
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileQuantity(
                  'Pending',
                  pending,
                  pending > 0
                      ? const Color(0xFFE65100)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ratioColumn(
                    'Virgin Ratio',
                    item['virginRatio'],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: _ratioColumn(
                    'Grinding Ratio',
                    item['grindingRatio'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productInfo(
    Map<String, dynamic> item,
  ) {
    final productName =
        _stringValue(item['productName']);

    final productCode =
        _stringValue(item['productCode']);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          productName.isEmpty
              ? '-'
              : productName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _tableValueStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (productCode.isNotEmpty)
          Text(
            productCode,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: const Color(0xFF9CA3AF),
            ),
          ),
      ],
    );
  }

  Widget _mobileDetail(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 4,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color:
                    const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileQuantity(
    String label,
    int value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioColumn(
    String label,
    dynamic value,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _decimal(value),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF343741),
          ),
        ),
      ],
    );
  }

  Widget _ratioText(dynamic value) {
    return Text(
      _decimal(value),
      style: _tableValueStyle(),
    );
  }

  Widget _numberText(
    int value, {
    Color color = const Color(0xFF343741),
  }) {
    return Text(
      value.toString(),
      style: _tableValueStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  TextStyle _tableValueStyle({
    Color color = const Color(0xFF4B5563),
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: fontWeight,
      color: color,
    );
  }

  TextStyle _tableHeaderStyle() {
    return GoogleFonts.poppins(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF6B7280),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: _tableHeaderStyle(),
    );
  }

  Widget _variantBadge(String variant) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        variant.isEmpty ? '-' : variant,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF3F51B5),
        ),
      ),
    );
  }

  // ============================================================
  // ALL ITEMS
  // ============================================================

  Widget _buildAllItemsSection({
    required bool isMobile,
  }) {
    final items = _getItems();

    if (items.isEmpty) {
      return _buildEmptyCard(
        'No order items found.',
      );
    }

    if (isMobile) {
      return Column(
        children: items.map(
          (item) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _buildItemCard(item),
            );
          },
        ).toList(),
      );
    }

    return _buildWhiteCard(
      child: Column(
        children: [
          _buildDesktopItemHeader(),
          const SizedBox(height: 5),
          ...items.map(
            (item) => _buildDesktopItemRow(item),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AUDIT
  // ============================================================

  Widget _buildAuditInformation({
    required bool isMobile,
  }) {
    final createdByName =
        _stringValue(order['createdByName']);

    final createdByUid =
        _stringValue(order['createdByUid']);

    final orderId =
        _stringValue(order['id']);

    return _buildWhiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Order Record',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF343741),
            ),
          ),

          const SizedBox(height: 14),

          if (isMobile)
            Column(
              children: [
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.badge_outlined,
                    label: 'Created By',
                    value: createdByName.isEmpty
                        ? '-'
                        : createdByName,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.fingerprint_outlined,
                    label: 'Created By UID',
                    value: createdByUid.isEmpty
                        ? '-'
                        : createdByUid,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  _InfoData(
                    icon: Icons.description_outlined,
                    label: 'Firestore Order ID',
                    value: orderId.isEmpty
                        ? '-'
                        : orderId,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.badge_outlined,
                      label: 'Created By',
                      value: createdByName.isEmpty
                          ? '-'
                          : createdByName,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.fingerprint_outlined,
                      label: 'Created By UID',
                      value: createdByUid.isEmpty
                          ? '-'
                          : createdByUid,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.description_outlined,
                      label: 'Firestore Order ID',
                      value: orderId.isEmpty
                          ? '-'
                          : orderId,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON UI
  // ============================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF2FF),
            borderRadius:
                BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFF3F51B5),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      const Color(0xFF343741),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color:
                      const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: child,
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _smallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ============================================================
// SUPPORT CLASSES
// ============================================================

class _QuantityData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _QuantityData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _InfoData {
  final IconData icon;
  final String label;
  final String value;

  const _InfoData({
    required this.icon,
    required this.label,
    required this.value,
  });
}