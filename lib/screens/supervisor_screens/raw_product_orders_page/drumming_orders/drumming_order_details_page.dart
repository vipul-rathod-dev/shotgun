import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:share_plus/share_plus.dart';



class DrummingOrderDetailsPage extends StatelessWidget {

  final Map<String, dynamic> order;



  const DrummingOrderDetailsPage({super.key, required this.order});



  // ============================================================*

  // HELPERS*

  // ============================================================*



  int _toInt(dynamic value) {

    if (value is int) return value;

    if (value is double) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;

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

    if (date == null) return '-';



    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');



    return '$day/$month/${date.year}';

  }



  String _formatDateTime(dynamic value) {

    final date = _toDateTime(value);

    if (date == null) return '-';



    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');



    return '$day/$month/${date.year} $hour:$minute';

  }



  List<Map<String, dynamic>> _getItems() {

    final rawItems = order['items'];



    if (rawItems is! List) {

      return [];

    }



    return rawItems

        .whereType<Map>()

        .map((item) => Map<String, dynamic>.from(item))

        .toList();

  }



  String _itemProductName(Map<String, dynamic> item) {

    return _stringValue(

      item['productName'] ?? item['displayName'] ?? item['product'],

    );

  }



  String _itemProductCode(Map<String, dynamic> item) {

    return _stringValue(item['productCode'] ?? item['code']);

  }



  String _itemVariant(Map<String, dynamic> item) {

    return _stringValue(item['variantType'] ?? item['variant']);

  }

  String _itemMaterialType(Map<String, dynamic> item) {
    final value = _stringValue(
      item['materialType'] ??
          item['material'] ??
          item['rawMaterialType'] ??
          item['rawMaterial'],
    );
    if (value.isEmpty) return '-';
    final normalized = value.toLowerCase();
    if (normalized == 'black') return 'Black';
    if (normalized == 'clear') return 'Clear';
    if (normalized == 'pc') return 'PC';
    return value;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
  }

  String _receivedWeightText() {
    final value = _toDouble(order['moldingReceiptWeight'] ?? order['lastReceivedWeight'] ?? order['weight']);
    if (value <= 0) return '-';
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 3)} kg';
  }

  String _receivedBagsText() {
    final value = _toInt(order['moldingReceiptTotalBags'] ?? order['lastReceivedTotalBags'] ?? order['totalBagsReceived'] ?? order['totalBags'] ?? order['bagsReceived']);
    return value > 0 ? '$value bags' : '-';
  }



  String _itemModel(Map<String, dynamic> item) {

    return _stringValue(item['modelName'] ?? item['model']);

  }



  bool _isTempleItem(Map<String, dynamic> item) {

    final values = [

      _stringValue(item['componentType']),

      _stringValue(item['component']),

      _stringValue(item['variantType']),

      _stringValue(item['variant']),

      _stringValue(item['partType']),

    ].map((value) => value.toLowerCase()).where((value) => value.isNotEmpty);



    return values.any((value) => value.contains('temple'));

  }



  String _itemSide(Map<String, dynamic> item) {

    final explicitSide = _stringValue(

      item['side'] ??

          item['templeSide'] ??

          item['sideType'] ??

          item['partSide'] ??

          item['templeType'],

    ).toLowerCase();



    if (explicitSide.contains('right') || explicitSide == 'r') {

      return 'right';

    }



    if (explicitSide.contains('left') || explicitSide == 'l') {

      return 'left';

    }



    // Backward-compatible fallback when the side is included in the*

    // product/variant name rather than a dedicated field.*

    final text = [

      _itemProductName(item),

      _itemVariant(item),

      _stringValue(item['modelName']),

    ].join(' ').toLowerCase();



    if (RegExp(r'(^|[^a-z])right([^a-z]|$)').hasMatch(text)) {

      return 'right';

    }



    if (RegExp(r'(^|[^a-z])left([^a-z]|$)').hasMatch(text)) {

      return 'left';

    }



    return '';

  }



  int _itemOrdered(Map<String, dynamic> item) {

    return _toInt(

      item['orderedQuantity'] ?? item['quantity'] ?? item['pieces'],

    );

  }



  int _itemReceived(Map<String, dynamic> item) {

    return _toInt(item['receivedQuantity']);

  }



  int _itemPending(Map<String, dynamic> item) {

    final ordered = _itemOrdered(item);

    final received = _itemReceived(item);



    return (ordered - received).clamp(0, ordered).toInt();

  }



  String _itemDisplayName(Map<String, dynamic> item) {
    final name = _itemProductName(item).trim();

    // Display the product name only once. Product code, model and variant
    // remain part of the internal grouping key and are not appended here.
    return name.isEmpty ? '-' : name;
  }

  String _quantityText(int value) {

    return value.toString();

  }



  // Group duplicate items for display only.*

  //*

  // Focus/non-Temple items are grouped by:*

  //   productName + productCode + modelName + variant*

  //*

  // Temple items are grouped by the same product/variant key, while*

  // Right/Left quantities are accumulated independently. Firestore data is*

  // never modified by this grouping.*

  List<Map<String, dynamic>> _displayItems() {

    final source = _getItems();

    final result = <Map<String, dynamic>>[];

    final groupedIndexes = <String, int>{};



    String normalize(String value) => value.trim().toLowerCase();



    String baseKey(Map<String, dynamic> item) {

      return [

        normalize(_itemProductName(item)),

        normalize(_itemProductCode(item)),

        normalize(_itemModel(item)),

        normalize(_itemVariant(item)),

      ].join('|');

    }



    Map<String, dynamic> createAggregate(Map<String, dynamic> item) {

      return {

        ...item,

        'orderedQuantity': 0,

        'receivedQuantity': 0,

      };

    }



    void addQuantity(Map<String, dynamic> target, Map<String, dynamic> item) {

      target['orderedQuantity'] =

          _itemOrdered(target) + _itemOrdered(item);

      target['receivedQuantity'] =

          _itemReceived(target) + _itemReceived(item);

    }



    for (final item in source) {

      final isTemple = _isTempleItem(item);

      final base = baseKey(item);



      if (!isTemple) {

        final key = 'normal|$base';

        final existingIndex = groupedIndexes[key];



        if (existingIndex == null) {

          final aggregate = createAggregate(item);

          aggregate['_displayType'] = 'normal';

          addQuantity(aggregate, item);

          result.add(aggregate);

          groupedIndexes[key] = result.length - 1;

        } else {

          addQuantity(result[existingIndex], item);

        }

        continue;

      }



      final side = _itemSide(item);



      // If a Temple row has no identifiable side, still group it by the*

      // product + variant rather than creating duplicate rows.*

      if (side.isEmpty) {

        final key = 'temple|$base|unknown';

        final existingIndex = groupedIndexes[key];



        if (existingIndex == null) {

          final aggregate = createAggregate(item);

          aggregate['_displayType'] = 'temple';

          addQuantity(aggregate, item);

          result.add(aggregate);

          groupedIndexes[key] = result.length - 1;

        } else {

          addQuantity(result[existingIndex], item);

        }

        continue;

      }



      final key = 'temple|$base';

      var existingIndex = groupedIndexes[key];



      if (existingIndex == null) {

        final grouped = createAggregate(item);

        grouped['_displayType'] = 'temple';

        grouped['_leftItem'] = null;

        grouped['_rightItem'] = null;

        result.add(grouped);

        existingIndex = result.length - 1;

        groupedIndexes[key] = existingIndex;

      }



      final grouped = result[existingIndex];

      final sideKey = side == 'left' ? '_leftItem' : '_rightItem';

      final existingSide = grouped[sideKey];



      if (existingSide is Map) {

        final sideMap = Map<String, dynamic>.from(existingSide);

        addQuantity(sideMap, item);

        grouped[sideKey] = sideMap;

      } else {

        final sideMap = createAggregate(item);

        addQuantity(sideMap, item);

        // createAggregate starts at zero, so the explicit add above gives*

        // the first item's quantity. Keep the side's identifying fields too.*

        grouped[sideKey] = sideMap;

      }

    }



    // The first Temple row is used for the product display name/metadata.*

    // The aggregated side maps contain the actual accumulated quantities.*

    return result;

  }



  Map<String, dynamic>? _groupSide(Map<String, dynamic> item, String side) {

    final value = item[side == 'left' ? '_leftItem' : '_rightItem'];

    if (value is Map) return Map<String, dynamic>.from(value);

    return null;

  }



  int _groupOrdered(Map<String, dynamic> item) {

    if (item['_displayType'] != 'temple') return _itemOrdered(item);



    final left = _groupSide(item, 'left');

    final right = _groupSide(item, 'right');



    if (left != null && right != null) {

      return _itemOrdered(right);

    }



    return _itemOrdered(right ?? left ?? item);

  }



  int _groupReceived(Map<String, dynamic> item) {

    if (item['_displayType'] != 'temple') return _itemReceived(item);



    final left = _groupSide(item, 'left');

    final right = _groupSide(item, 'right');



    if (left != null && right != null) {

      return _itemReceived(right);

    }



    return _itemReceived(right ?? left ?? item);

  }



  int _groupPending(Map<String, dynamic> item) {

    final ordered = _groupOrdered(item);

    final received = _groupReceived(item);

    return (ordered - received).clamp(0, ordered).toInt();

  }



  int _groupSideQuantity(

    Map<String, dynamic> item,

    String side,

    String field,

  ) {

    final sideItem = _groupSide(item, side);

    if (sideItem != null) {

      return field == 'ordered'

          ? _itemOrdered(sideItem)

          : field == 'received'

              ? _itemReceived(sideItem)

              : _itemPending(sideItem);

    }



    // If an old Temple document has only one row, use its quantity rather*

    // than showing a misleading zero for both sides.*

    if (item['_displayType'] == 'temple') {

      return field == 'ordered'

          ? _itemOrdered(item)

          : field == 'received'

              ? _itemReceived(item)

              : _itemPending(item);

    }



    return 0;

  }



  // ============================================================*

  // SHARE*

  // ============================================================*



  Future<void> _shareDrummingOrder(BuildContext context) async {

    final orderNumber = _stringValue(order['orderNumber']).isEmpty

        ? '-'

        : _stringValue(order['orderNumber']);



    final supplier = _stringValue(order['supplierName']).isEmpty

        ? '-'

        : _stringValue(order['supplierName']);



    final sourceOrder =

        _stringValue(order['sourceMoldingOrderNumber']).isEmpty

            ? '-'

            : _stringValue(order['sourceMoldingOrderNumber']);



    final buffer = StringBuffer();



    buffer.writeln('DRUMMING ORDER');

    buffer.writeln('━━━━━━━━━━━━━━━━');

    buffer.writeln('Order No: $orderNumber');

    buffer.writeln('Order Date: ${_formatDate(order['orderDate'])}');

    buffer.writeln('Drumming Supplier: $supplier');

    buffer.writeln('Molding Order: $sourceOrder');

    buffer.writeln();



    buffer.writeln('DRUMMING ITEMS');

    buffer.writeln('━━━━━━━━━━━━━━━━');



    for (final item in _displayItems()) {

      final product = _itemDisplayName(item);



      buffer.writeln('Product: $product');



      if (item['_displayType'] == 'temple') {

        final right = _groupSideQuantity(item, 'right', 'ordered');

        final left = _groupSideQuantity(item, 'left', 'ordered');

        buffer.writeln('Right: $right');

        buffer.writeln('Left: $left');

      } else {

        buffer.writeln('Quantity: ${_groupOrdered(item)}');

        buffer.writeln('Received: ${_groupReceived(item)}');

        buffer.writeln('Pending: ${_groupPending(item)}');

      }



      buffer.writeln();

    }



    buffer.writeln('━━━━━━━━━━━━━━━━');

    buffer.writeln('Sent from Shotgun');



    try {

      await Share.share(

        buffer.toString(),

        subject: 'Drumming Order $orderNumber',

      );

    } catch (e) {

      if (!context.mounted) return;



      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Unable to share order: $e',

            style: GoogleFonts.poppins(),

          ),

        ),

      );

    }

  }



  // ============================================================*

  // BUILD*

  // ============================================================*



  @override

  Widget build(BuildContext context) {

    final orderNumber = _stringValue(order['orderNumber']).isEmpty

        ? '-'

        : _stringValue(order['orderNumber']);



    final status = _stringValue(order['status']).isEmpty

        ? 'Pending'

        : _stringValue(order['status']);



    final supplier = _stringValue(order['supplierName']).isEmpty

        ? '-'

        : _stringValue(order['supplierName']);



    final sourceOrder =

        _stringValue(order['sourceMoldingOrderNumber']).isEmpty

            ? '-'

            : _stringValue(order['sourceMoldingOrderNumber']);



    final items = _getItems();

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

              'Drumming Order Details',

              style: GoogleFonts.poppins(

                fontSize: 11,

                color: const Color(0xFF6B7280),

              ),

            ),

          ],

        ),

        actions: [

          IconButton(

            tooltip: 'Share Order',

            onPressed: () => _shareDrummingOrder(context),

            icon: const Icon(Icons.share_outlined),

          ),

        ],

      ),

      body: LayoutBuilder(

        builder: (context, constraints) {

          final isMobile = constraints.maxWidth < 700;



          return SingleChildScrollView(

            padding: EdgeInsets.all(isMobile ? 12 : 24),

            child: Center(

              child: ConstrainedBox(

                constraints: const BoxConstraints(maxWidth: 1200),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    _buildHeaderCard(

                      orderNumber: orderNumber,

                      status: status,

                    ),

                    const SizedBox(height: 16),

                    _buildInformationCard(

                      supplier: supplier,

                      sourceOrder: sourceOrder,

                      itemCount: items.length,

                      receivedWeight: _receivedWeightText(),
                      totalBags: _receivedBagsText(),
                      isMobile: isMobile,

                    ),

                    const SizedBox(height: 16),

                    _buildDateInformation(isMobile: isMobile),

                    const SizedBox(height: 24),

                    _buildSectionTitle(

                      icon: Icons.rotate_right_outlined,

                      title: 'Drumming Items',

                      subtitle:

                          '${_displayItems().length} product${_displayItems().length == 1 ? '' : 's'}',

                    ),

                    const SizedBox(height: 12),

                    _buildItemsSection(isMobile: isMobile),

                    const SizedBox(height: 24),

                    _buildAuditInformation(

                      orderId: orderId,

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



  // ============================================================*

  // HEADER*

  // ============================================================*



  Widget _buildHeaderCard({

    required String orderNumber,

    required String status,

  }) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE0E0E0)),

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

              Icons.rotate_right_outlined,

              color: Color(0xFF3F51B5),

              size: 27,

            ),

          ),

          const SizedBox(width: 14),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

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

                  'Drumming Order',

                  style: GoogleFonts.poppins(

                    fontSize: 12,

                    color: const Color(0xFF6B7280),

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(width: 12),

          _buildStatusChip(status),

        ],

      ),

    );

  }



  // ============================================================*

  // INFORMATION*

  // ============================================================*



  Widget _buildInformationCard({

    required String supplier,

    required String sourceOrder,

    required int itemCount,

    required String receivedWeight,
    required String totalBags,
    required bool isMobile,

  }) {

    final info = [

      _InfoData(

        icon: Icons.person_outline,

        label: 'Drumming Supplier',

        value: supplier,

      ),

      _InfoData(

        icon: Icons.link_outlined,

        label: 'Molding Order',

        value: sourceOrder,

      ),

      _InfoData(

        icon: Icons.inventory_2_outlined,

        label: 'Variants',

        value: itemCount.toString(),

      ),

          _InfoData(
        icon: Icons.scale_outlined,
        label: 'Received Weight',
        value: receivedWeight,
      ),
      _InfoData(
        icon: Icons.workspaces_outlined,
        label: 'Total Bags Received',
        value: totalBags,
      ),
    ];



    return _buildWhiteCard(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _buildCardTitle(

            icon: Icons.info_outline,

            title: 'Order Information',

          ),

          const SizedBox(height: 16),

          if (isMobile)

            Column(

              children: [

                for (int i = 0; i < info.length; i++) ...[

                  _buildInfoItem(info[i]),

                  if (i != info.length - 1) const SizedBox(height: 14),

                ],

              ],

            )

          else

            Wrap(

              spacing: 30,

              runSpacing: 18,

              children: info

                  .map(

                    (item) => SizedBox(

                      width: 250,

                      child: _buildInfoItem(item),

                    ),

                  )

                  .toList(),

            ),

        ],

      ),

    );

  }



  Widget _buildInfoItem(_InfoData data) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Icon(

          data.icon,

          size: 20,

          color: const Color(0xFF3F51B5),

        ),

        const SizedBox(width: 10),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

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

                  fontSize: 13,

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



  // ============================================================*

  // DATE INFORMATION*

  // ============================================================*



  Widget _buildDateInformation({required bool isMobile}) {

    final dates = [

      _InfoData(

        icon: Icons.calendar_today_outlined,

        label: 'Order Date',

        value: _formatDate(order['orderDate']),

      ),

      _InfoData(

        icon: Icons.add_circle_outline,

        label: 'Created At',

        value: _formatDateTime(order['createdAt']),

      ),

      _InfoData(

        icon: Icons.update_outlined,

        label: 'Last Updated',

        value: _formatDateTime(

          order['updatedAt'] ?? order['lastUpdated'] ?? order['modifiedAt'],

        ),

      ),

    ];



    return _buildWhiteCard(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _buildCardTitle(

            icon: Icons.schedule_outlined,

            title: 'Date Information',

          ),

          const SizedBox(height: 16),

          if (isMobile)

            Column(

              children: [

                for (int i = 0; i < dates.length; i++) ...[

                  _buildInfoItem(dates[i]),

                  if (i != dates.length - 1) const SizedBox(height: 14),

                ],

              ],

            )

          else

            Row(

              children: [

                for (int i = 0; i < dates.length; i++) ...[

                  Expanded(child: _buildInfoItem(dates[i])),

                  if (i != dates.length - 1) const SizedBox(width: 20),

                ],

              ],

            ),

        ],

      ),

    );

  }



  // ============================================================*

  // ITEMS*

  // ============================================================*



  Widget _buildItemsSection({required bool isMobile}) {

    final items = _displayItems();



    if (items.isEmpty) {

      return _buildEmptyCard('No drumming item details found.');

    }



    return _buildWhiteCard(

      padding: EdgeInsets.zero,

      child: isMobile

          ? Column(

              children: [

                for (int i = 0; i < items.length; i++) ...[

                  _buildMobileItemCard(

                    item: items[i],

                    index: i + 1,

                  ),

                  if (i != items.length - 1)

                    const Divider(

                      height: 1,

                      color: Color(0xFFE5E7EB),

                    ),

                ],

              ],

            )

          : _buildDesktopItemsTable(items),

    );

  }



  Widget _buildMobileItemCard({

    required Map<String, dynamic> item,

    required int index,

  }) {

    final product = _itemDisplayName(item);

    final isTemple = item['_displayType'] == 'temple';



    final ordered = _groupOrdered(item);

    final received = _groupReceived(item);

    final pending = _groupPending(item);



    final rightOrdered = _groupSideQuantity(item, 'right', 'ordered');

    final leftOrdered = _groupSideQuantity(item, 'left', 'ordered');

    final rightReceived = _groupSideQuantity(item, 'right', 'received');

    final leftReceived = _groupSideQuantity(item, 'left', 'received');

    final rightPending = _groupSideQuantity(item, 'right', 'pending');

    final leftPending = _groupSideQuantity(item, 'left', 'pending');



    return Padding(

      padding: const EdgeInsets.all(16),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 30,

                height: 30,

                alignment: Alignment.center,

                decoration: BoxDecoration(

                  color: const Color(0xFFEFF2FF),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: Text(

                  '$index',

                  style: GoogleFonts.poppins(

                    fontSize: 11,

                    fontWeight: FontWeight.w700,

                    color: const Color(0xFF3F51B5),

                  ),

                ),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Text(

                  product,

                  style: GoogleFonts.poppins(

                    fontSize: 14,

                    fontWeight: FontWeight.w600,

                    color: const Color(0xFF343741),

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'Material: ${_itemMaterialType(item)}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (isTemple) ...[

            _buildSideQuantityRow(

              label: 'Right',

              ordered: rightOrdered,

              received: rightReceived,

              pending: rightPending,

            ),

            const SizedBox(height: 8),

            _buildSideQuantityRow(

              label: 'Left',

              ordered: leftOrdered,

              received: leftReceived,

              pending: leftPending,

            ),

          ] else

            Container(

              padding: const EdgeInsets.all(10),

              decoration: BoxDecoration(

                color: const Color(0xFFF9FAFB),

                borderRadius: BorderRadius.circular(9),

              ),

              child: Row(

                children: [

                  Expanded(child: _buildMiniQuantity('Quantity', ordered)),

                  _buildVerticalDivider(),

                  Expanded(child: _buildMiniQuantity('Received', received)),

                  _buildVerticalDivider(),

                  Expanded(child: _buildMiniQuantity('Pending', pending)),

                ],

              ),

            ),

        ],

      ),

    );

  }



  Widget _buildSideQuantityRow({

    required String label,

    required int ordered,

    required int received,

    required int pending,

  }) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(

        color: const Color(0xFFF9FAFB),

        borderRadius: BorderRadius.circular(9),

      ),

      child: Row(

        children: [

          SizedBox(

            width: 55,

            child: Text(

              label,

              style: GoogleFonts.poppins(

                fontSize: 11,

                fontWeight: FontWeight.w600,

                color: const Color(0xFF343741),

              ),

            ),

          ),

          Expanded(child: _buildMiniQuantity('Ordered', ordered)),

          _buildVerticalDivider(),

          Expanded(child: _buildMiniQuantity('Received', received)),

          _buildVerticalDivider(),

          Expanded(child: _buildMiniQuantity('Pending', pending)),

        ],

      ),

    );

  }



  Widget _buildDesktopItemsTable(List<Map<String, dynamic>> items) {

    return Column(

      children: [

        Container(

          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

          decoration: const BoxDecoration(

            color: Color(0xFFF9FAFB),

            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),

          ),

          child: Row(

            children: [

              Expanded(flex: 4, child: _tableHeader('Product')),

              Expanded(flex: 2, child: _tableHeader('Quantity')),

              Expanded(flex: 2, child: _tableHeader('Received')),

              Expanded(flex: 2, child: _tableHeader('Pending')),

            ],

          ),

        ),

        ...items.map((item) {

          final isTemple = item['_displayType'] == 'temple';

          final product = _itemDisplayName(item);



          return Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),

            decoration: const BoxDecoration(

              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),

            ),

            child: isTemple

                ? Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF343741),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Material: ${_itemMaterialType(item)}',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(

                        children: [

                          Expanded(

                            flex: 4,

                            child: Text(

                              'Right',

                              style: GoogleFonts.poppins(

                                fontSize: 11,

                                fontWeight: FontWeight.w600,

                                color: const Color(0xFF6B7280),

                              ),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'right', 'ordered')

                                  .toString(),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'right', 'received')

                                  .toString(),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'right', 'pending')

                                  .toString(),

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 7),

                      Row(

                        children: [

                          Expanded(

                            flex: 4,

                            child: Text(

                              'Left',

                              style: GoogleFonts.poppins(

                                fontSize: 11,

                                fontWeight: FontWeight.w600,

                                color: const Color(0xFF6B7280),

                              ),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'left', 'ordered')

                                  .toString(),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'left', 'received')

                                  .toString(),

                            ),

                          ),

                          Expanded(

                            flex: 2,

                            child: _tableText(

                              _groupSideQuantity(item, 'left', 'pending')

                                  .toString(),

                            ),

                          ),

                        ],

                      ),

                    ],

                  )

                : Row(

                    children: [

                      Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _tableText(product),
                              const SizedBox(height: 2),
                              _tableText('Material: ${_itemMaterialType(item)}'),
                            ],
                          ),
                        ),

                      Expanded(

                        flex: 2,

                        child: _tableText(_groupOrdered(item).toString()),

                      ),

                      Expanded(

                        flex: 2,

                        child: _tableText(_groupReceived(item).toString()),

                      ),

                      Expanded(

                        flex: 2,

                        child: _tableText(_groupPending(item).toString()),

                      ),

                    ],

                  ),

          );

        }),

      ],

    );

  }



  Widget _tableHeader(String value) {

    return Text(

      value,

      style: GoogleFonts.poppins(

        fontSize: 10,

        fontWeight: FontWeight.w600,

        color: const Color(0xFF6B7280),

      ),

    );

  }



  Widget _tableText(String value) {

    return Text(

      value.isEmpty ? '-' : value,

      style: GoogleFonts.poppins(

        fontSize: 11,

        color: const Color(0xFF343741),

      ),

    );

  }



  Widget _buildMiniQuantity(String label, int value) {

    return Column(

      children: [

        Text(

          label,

          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(

            fontSize: 9,

            color: const Color(0xFF9CA3AF),

          ),

        ),

        const SizedBox(height: 2),

        Text(

          _quantityText(value),

          style: GoogleFonts.poppins(

            fontSize: 13,

            fontWeight: FontWeight.w700,

            color: const Color(0xFF343741),

          ),

        ),

      ],

    );

  }



  Widget _buildVerticalDivider() {

    return Container(

      width: 1,

      height: 30,

      color: const Color(0xFFE5E7EB),

    );

  }



  // ============================================================*

  // AUDIT INFORMATION*

  // ============================================================*



  Widget _buildAuditInformation({

    required String orderId,

    required bool isMobile,

  }) {

    final createdBy = _stringValue(order['createdByName']).isEmpty

        ? _stringValue(order['createdBy']).isEmpty

            ? '-'

            : _stringValue(order['createdBy'])

        : _stringValue(order['createdByName']);



    final createdByUid = _stringValue(order['createdByUid']).isEmpty

        ? '-'

        : _stringValue(order['createdByUid']);



    final updatedBy = _stringValue(order['updatedByName']).isEmpty

        ? _stringValue(order['updatedBy']).isEmpty

            ? '-'

            : _stringValue(order['updatedBy'])

        : _stringValue(order['updatedByName']);



    final info = [

      _InfoData(

        icon: Icons.person_outline,

        label: 'Created By',

        value: createdBy,

      ),

      _InfoData(

        icon: Icons.badge_outlined,

        label: 'Created By UID',

        value: createdByUid,

      ),

      _InfoData(

        icon: Icons.edit_outlined,

        label: 'Updated By',

        value: updatedBy,

      ),

      _InfoData(

        icon: Icons.fingerprint_outlined,

        label: 'Firestore Order ID',

        value: orderId.isEmpty ? '-' : orderId,

      ),

    ];



    return _buildWhiteCard(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _buildCardTitle(

            icon: Icons.history_outlined,

            title: 'Audit Information',

          ),

          const SizedBox(height: 16),

          if (isMobile)

            Column(

              children: [

                for (int i = 0; i < info.length; i++) ...[

                  _buildInfoItem(info[i]),

                  if (i != info.length - 1) const SizedBox(height: 14),

                ],

              ],

            )

          else

            Wrap(

              spacing: 30,

              runSpacing: 18,

              children: info

                  .map(

                    (item) => SizedBox(

                      width: 250,

                      child: _buildInfoItem(item),

                    ),

                  )

                  .toList(),

            ),

        ],

      ),

    );

  }



  // ============================================================*

  // COMMON UI*

  // ============================================================*



  Widget _buildSectionTitle({

    required IconData icon,

    required String title,

    required String subtitle,

  }) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.center,

      children: [

        Container(

          width: 38,

          height: 38,

          decoration: BoxDecoration(

            color: const Color(0xFFEFF2FF),

            borderRadius: BorderRadius.circular(10),

          ),

          child: Icon(

            icon,

            size: 20,

            color: const Color(0xFF3F51B5),

          ),

        ),

        const SizedBox(width: 10),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                title,

                style: GoogleFonts.poppins(

                  fontSize: 15,

                  fontWeight: FontWeight.w700,

                  color: const Color(0xFF343741),

                ),

              ),

              const SizedBox(height: 1),

              Text(

                subtitle,

                style: GoogleFonts.poppins(

                  fontSize: 10,

                  color: const Color(0xFF9CA3AF),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }



  Widget _buildCardTitle({

    required IconData icon,

    required String title,

  }) {

    return Row(

      children: [

        Icon(

          icon,

          size: 19,

          color: const Color(0xFF3F51B5),

        ),

        const SizedBox(width: 8),

        Text(

          title,

          style: GoogleFonts.poppins(

            fontSize: 14,

            fontWeight: FontWeight.w600,

            color: const Color(0xFF343741),

          ),

        ),

      ],

    );

  }



  Widget _buildWhiteCard({

    required Widget child,

    EdgeInsetsGeometry padding = const EdgeInsets.all(18),

  }) {

    return Container(

      width: double.infinity,

      padding: padding,

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE0E0E0)),

      ),

      child: child,

    );

  }



  Widget _buildEmptyCard(String message) {

    return _buildWhiteCard(

      child: Center(

        child: Padding(

          padding: const EdgeInsets.symmetric(vertical: 28),

          child: Text(

            message,

            textAlign: TextAlign.center,

            style: GoogleFonts.poppins(

              fontSize: 12,

              color: const Color(0xFF6B7280),

            ),

          ),

        ),

      ),

    );

  }



  Widget _buildStatusChip(String status) {

    final normalized = status.toLowerCase().trim();



    Color backgroundColor = const Color(0xFFEFF2FF);

    Color foregroundColor = const Color(0xFF3F51B5);



    if (normalized == 'received' ||

        normalized == 'completed' ||

        normalized == 'complete') {

      backgroundColor = const Color(0xFFE8F5E9);

      foregroundColor = const Color(0xFF2E7D32);

    } else if (normalized == 'partial' || normalized == 'processing') {

      backgroundColor = const Color(0xFFFFF4E5);

      foregroundColor = const Color(0xFFB45309);

    } else if (normalized == 'cancelled' || normalized == 'canceled') {

      backgroundColor = const Color(0xFFFDECEC);

      foregroundColor = const Color(0xFFC62828);

    }



    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(

        color: backgroundColor,

        borderRadius: BorderRadius.circular(20),

      ),

      child: Text(

        status,

        style: GoogleFonts.poppins(

          fontSize: 10,

          fontWeight: FontWeight.w600,

          color: foregroundColor,

        ),

      ),

    );

  }

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
