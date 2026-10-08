import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:share_plus/share_plus.dart';

import 'create_molding_order_page.dart';

class MoldingOrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const MoldingOrderDetailsPage({super.key, required this.order});

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
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _getMolds() {
    final rawMolds = order['molds'];

    if (rawMolds is List) {
      final molds =
          rawMolds
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
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
        'orderedShots': _toInt(order['orderedShots']),
        'receivedShots': _toInt(order['receivedShots']),

        'items': allItems,
      },
    ];
  }

  List<Map<String, dynamic>> _getMoldItems(Map<String, dynamic> mold) {
    final rawItems = mold['items'];

    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
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

  // ============================================================
  // MOLDING SHOTS
  // ============================================================
  // This page stores physical quantities in Firestore, but the View page
  // displays molding shots. A shot is one molding cycle.
  //
  // piecesPerCycle comes from the selected mold cavity. If it is missing
  // or zero, one physical piece is treated as one shot.
  //
  // For multiple cavities, the cavities operate in the same cycle.
  // Therefore the mold's shot count is the highest shot requirement
  // among its selected cavities, not the sum of the cavities.
  // ============================================================

  int _shotsFromPieces(dynamic pieces, dynamic piecesPerCycle) {
    final pieceCount = _toInt(pieces);
    if (pieceCount <= 0) return 0;

    final cyclePieces = _toInt(piecesPerCycle);
    if (cyclePieces <= 0) return pieceCount;

    // A partial cycle still requires one complete molding shot.
    return (pieceCount + cyclePieces - 1) ~/ cyclePieces;
  }

  int _itemShots(Map<String, dynamic> item, String field) {
    return _shotsFromPieces(item[field], item['piecesPerCycle']);
  }

  int _calculateMoldShots(Map<String, dynamic> mold, String field) {
    // IMPORTANT:
    // orderedQuantity / receivedQuantity are PHYSICAL PIECES.
    // Never use stored orderedShots/receivedShots here because older
    // documents may contain piece quantities in those fields.
    //
    // A molding shot is one complete molding cycle. For a multi-cavity
    // mold, all cavities are produced in the same shot, so quantities
    // from different cavities must NOT be added together.
    //
    // Temple Left + Right are also two physical records for the same
    // molding quantity, so they must not be added together either.
    // Taking the maximum quantity within each cavity handles both cases.

    final items = _getMoldItems(mold);
    if (items.isEmpty) return 0;

    final piecesByCavity = <String, int>{};

    for (final item in items) {
      final cavity = _stringValue(item['cavityNumber'] ?? item['cavity']);
      final key = cavity.isEmpty ? '__default__' : cavity;
      final pieces = _toInt(item[field]);

      final current = piecesByCavity[key] ?? 0;
      if (pieces > current) {
        piecesByCavity[key] = pieces;
      }
    }

    // Cavities of the same mold run simultaneously, therefore the
    // number of molding shots is the largest cavity quantity.
    return piecesByCavity.values.fold<int>(
      0,
      (maximum, pieces) => pieces > maximum ? pieces : maximum,
    );
  }

  int _calculateMoldOrderedShots(Map<String, dynamic> mold) {
    return _calculateMoldShots(mold, 'orderedQuantity');
  }

  int _calculateMoldReceivedShots(Map<String, dynamic> mold) {
    return _calculateMoldShots(mold, 'receivedQuantity');
  }

  int _calculateMoldPendingShots(Map<String, dynamic> mold) {
    // Pending shots are calculated from pending physical pieces.
    // Never trust legacy pendingShots values.
    final items = _getMoldItems(mold);
    if (items.isEmpty) return 0;

    final shotsByCavity = <String, int>{};

    for (final item in items) {
      final cavity = _stringValue(item['cavityNumber'] ?? item['cavity']);
      final key = cavity.isEmpty ? '__default__' : cavity;

      final ordered = _toInt(item['orderedQuantity']);
      final received = _toInt(item['receivedQuantity']);
      final pendingPieces = (ordered - received).clamp(0, ordered).toInt();

      // One molding shot produces one piece from each active cavity.
      // Temple Left/Right are duplicate physical records, so the maximum
      // quantity in a cavity represents the actual molding quantity.
      final shots = pendingPieces;

      final current = shotsByCavity[key] ?? 0;
      if (shots > current) {
        shotsByCavity[key] = shots;
      }
    }

    return shotsByCavity.values.fold<int>(
      0,
      (maximum, shots) => shots > maximum ? shots : maximum,
    );
  }

  int _calculateTotalOrderedShots() {
    // Always calculate from physical pieces. Do not trust legacy
    // orderedShots because it may actually contain piece quantities.
    final molds = _getMolds();
    if (molds.isNotEmpty) {
      return molds.fold<int>(
        0,
        (total, mold) => total + _calculateMoldOrderedShots(mold),
      );
    }

    final items = _getItems();
    if (items.isEmpty) return 0;

    return items.fold<int>(0, (maximum, item) {
      final shots = _itemShots(item, 'orderedQuantity');
      return shots > maximum ? shots : maximum;
    });
  }

  int _calculateTotalReceivedShots() {
    // Always calculate from physical pieces. Do not trust legacy
    // receivedShots because it may actually contain piece quantities.
    final molds = _getMolds();
    if (molds.isNotEmpty) {
      return molds.fold<int>(
        0,
        (total, mold) => total + _calculateMoldReceivedShots(mold),
      );
    }

    final items = _getItems();
    if (items.isEmpty) return 0;

    return items.fold<int>(0, (maximum, item) {
      final shots = _itemShots(item, 'receivedQuantity');
      return shots > maximum ? shots : maximum;
    });
  }

  int _calculateTotalPendingShots() {
    // Always derive pending shots from physical pieces.
    final molds = _getMolds();
    if (molds.isNotEmpty) {
      return molds.fold<int>(
        0,
        (total, mold) => total + _calculateMoldPendingShots(mold),
      );
    }

    final items = _getItems();
    if (items.isEmpty) return 0;

    return items.fold<int>(0, (maximum, item) {
      final ordered = _toInt(item['orderedQuantity']);
      final received = _toInt(item['receivedQuantity']);
      final pendingPieces = (ordered - received).clamp(0, ordered).toInt();

      final shots = pendingPieces;

      return shots > maximum ? shots : maximum;
    });
  }

  // ============================================================
  // SHARE ORDER DETAILS
  // ============================================================
  // Future<void> _shareMoldingOrder(BuildContext context) async {
  //   final orderNumber = _stringValue(order['orderNumber']).isEmpty
  //       ? '-'
  //       : _stringValue(order['orderNumber']);
  //   final status = _stringValue(order['status']).isEmpty
  //       ? 'Unknown'
  //       : _stringValue(order['status']);
  //   final supplier = _stringValue(order['supplierName']).isEmpty
  //       ? '-'
  //       : _stringValue(order['supplierName']);
  //   final orderDate = _formatDate(order['orderDate']);
  //   // These methods already exist in your page.
  //   final orderedQuantity = _calculateTotalOrdered();
  //   final receivedQuantity = _calculateTotalReceived();
  //   final pendingQuantity = (orderedQuantity - receivedQuantity).clamp(
  //     0,
  //     orderedQuantity,
  //   );
  //   final molds = _getMolds();
  //   final buffer = StringBuffer();
  //   // ============================================================
  //   // HEADER
  //   // ============================================================
  //   buffer.writeln('MOLDING ORDER');
  //   buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
  //   buffer.writeln('Order Number: $orderNumber');
  //   buffer.writeln('Status: $status');
  //   buffer.writeln('Supplier: $supplier');
  //   buffer.writeln('Order Date: $orderDate');
  //   buffer.writeln();
  //   // ============================================================
  //   // QUANTITY
  //   // ============================================================
  //   buffer.writeln('QUANTITY');
  //   buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
  //   buffer.writeln('Ordered: $orderedQuantity');
  //   buffer.writeln('Received: $receivedQuantity');
  //   buffer.writeln('Pending: $pendingQuantity');
  //   buffer.writeln();
  //   // ============================================================
  //   // MOLD DETAILS
  //   // ============================================================
  //   buffer.writeln('MOLD DETAILS');
  //   buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
  //   for (final mold in molds) {
  //     final moldName = _stringValue(
  //       mold['moldName'] ?? mold['name'],
  //     );
  //     final cavityCount = _toInt(
  //       mold['cavityCount'] ?? mold['cavitiesCount'],
  //     );
  //     buffer.writeln('Mold: ${moldName.isEmpty ? '-' : moldName}');
  //     buffer.writeln('Cavities: $cavityCount');
  //     final items = _getMoldItems(mold);
  //     for (final item in items) {
  //       final productName = _stringValue(
  //         item['productName'] ?? item['displayName'],
  //       );
  //       final variant = _stringValue(
  //         item['variantType'] ?? item['variant'],
  //       );
  //       final cavity = _stringValue(
  //         item['cavityNumber'] ?? item['cavity'],
  //       );
  //       final ordered = _toInt(
  //         item['orderedQuantity'] ?? item['quantity'],
  //       );
  //       final received = _toInt(
  //         item['receivedQuantity'],
  //       );
  //       final pending = (ordered - received).clamp(
  //         0,
  //         ordered,
  //       );
  //       final virginRatio = _toDouble(
  //         item['virginRatio'],
  //       );
  //       final grindingRatio = _toDouble(
  //         item['grindingRatio'],
  //       );
  //       buffer.writeln();
  //       buffer.writeln(
  //         'Product: ${productName.isEmpty ? '-' : productName}',
  //       );
  //       buffer.writeln(
  //         'Variant: ${variant.isEmpty ? '-' : variant}',
  //       );
  //       buffer.writeln(
  //         'Cavity: ${cavity.isEmpty ? '-' : cavity}',
  //       );
  //       buffer.writeln('Ordered: $ordered');
  //       buffer.writeln('Received: $received');
  //       buffer.writeln('Pending: $pending');
  //       buffer.writeln(
  //         'Virgin Ratio: ${_decimal(virginRatio)}%',
  //       );
  //       buffer.writeln(
  //         'Grinding Ratio: ${_decimal(grindingRatio)}%',
  //       );
  //     }
  //     buffer.writeln();
  //   }
  //   // ============================================================
  //   // FOOTER
  //   // ============================================================
  //   buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
  //   buffer.writeln('Sent from Shotgun');
  //   try {
  //     await Share.share(
  //       buffer.toString(),
  //       subject: 'Molding Order $orderNumber',
  //     );
  //   } catch (e) {
  //     if (!context.mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Unable to share order: $e',
  //           style: GoogleFonts.poppins(),
  //         ),
  //       ),
  //     );
  //   }
  // }
  Future<void> _shareMoldingOrder(BuildContext context) async {
    final orderNumber =
        _stringValue(order['orderNumber']).isEmpty
            ? '-'
            : _stringValue(order['orderNumber']);

    final orderDate = _formatDate(order['orderDate']);

    final molds = _getMolds();

    final buffer = StringBuffer();

    // ============================================================
    // HEADER
    // ============================================================
    buffer.writeln('MOLDING ORDER');
    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Date: $orderDate');
    buffer.writeln('Order No: $orderNumber');
    buffer.writeln();

    // ============================================================
    // VARIANT ORDER
    // Black -> Clear -> PC
    //
    // IMPORTANT:
    // Share quantities are MOLDEING SHOTS, not physical pieces.
    //
    // Temple Left + Right are stored as two physical item records,
    // but they represent the same molding quantity. Therefore the
    // Left/Right quantities must never be added together.
    // ============================================================
    const variantOrder = ['Black', 'Clear', 'PC'];

    for (final mold in molds) {
      final items = _getMoldItems(mold);

      if (items.isEmpty) {
        continue;
      }

      final cavityCount = _toInt(mold['cavityCount']);

      // ============================================================
      // 1 CAVITY
      // Show Product Name
      // ============================================================
      if (cavityCount <= 1) {
        final moldName = _stringValue(mold['moldName'] ?? mold['name']);

        buffer.writeln(
          'Mold Name: ${moldName.isEmpty ? '-' : '$moldName (Single Cavity)'}',
        );

        String productName = '';

        for (final item in items) {
          final value = _stringValue(item['productName']);

          if (value.isNotEmpty) {
            productName = value;
            break;
          }
        }

        buffer.writeln('Product: ${productName.isEmpty ? '-' : productName}');
      }

      // ============================================================
      // 2 CAVITIES
      // Show Mold Name
      // ============================================================
      if (cavityCount >= 2) {
        final moldName = _stringValue(mold['moldName'] ?? mold['name']);

        buffer.writeln('Mold Name: ${moldName.isEmpty ? '-' : moldName}');
      }

      // ============================================================
      // VARIANTS
      // Black -> Clear -> PC
      //
      // The value shared here is always SHOTS.
      // ============================================================
      for (final variant in variantOrder) {
        final variantItems =
            items.where((item) {
              return _stringValue(item['variantType']).toLowerCase() ==
                  variant.toLowerCase();
            }).toList();

        if (variantItems.isEmpty) {
          continue;
        }

        int shots = 0;
        Map<String, dynamic>? ratioItem;

        final hasTemple = variantItems.any(_isTempleItem);

        if (hasTemple) {
          // ----------------------------------------------------------
          // TEMPLE
          // ----------------------------------------------------------
          // Left and Right are separate physical records but one
          // molding quantity. Take the maximum shot count instead of
          // adding Left + Right.
          for (final item in variantItems) {
            final itemShots = _itemShots(item, 'orderedQuantity');

            if (itemShots > shots) {
              shots = itemShots;
            }

            if (ratioItem == null &&
                (item.containsKey('virginRatio') ||
                    item.containsKey('grindingRatio'))) {
              ratioItem = item;
            }
          }
        } else if (cavityCount >= 2) {
          // ----------------------------------------------------------
          // TWO CAVITIES
          // ----------------------------------------------------------
          // Both cavities are produced in the same molding cycle, so
          // do not add their quantities. Use the highest shot count.
          for (final item in variantItems) {
            final itemShots = _itemShots(item, 'orderedQuantity');

            if (itemShots > shots) {
              shots = itemShots;
            }

            if (ratioItem == null &&
                (item.containsKey('virginRatio') ||
                    item.containsKey('grindingRatio'))) {
              ratioItem = item;
            }
          }
        } else {
          // ----------------------------------------------------------
          // SINGLE CAVITY NON-TEMPLE
          // ----------------------------------------------------------
          // Different physical products, if present, are separate
          // production quantities, so their shot counts are added.
          for (final item in variantItems) {
            shots += _itemShots(item, 'orderedQuantity');

            if (ratioItem == null &&
                (item.containsKey('virginRatio') ||
                    item.containsKey('grindingRatio'))) {
              ratioItem = item;
            }
          }
        }

        if (shots <= 0) {
          continue;
        }

        final virginRatio =
            ratioItem == null ? 0 : _toDouble(ratioItem['virginRatio']);

        final grindingRatio =
            ratioItem == null ? 0 : _toDouble(ratioItem['grindingRatio']);

        buffer.writeln(
          '$variant: $shots shots '
          '(Virgin: ${_decimal(virginRatio)}kg, '
          'Grinding: ${_decimal(grindingRatio)}kg)',
        );

        buffer.writeln();
      }
    }

    // ============================================================
    // SHARE
    // ============================================================
    try {
      await Share.share(
        buffer.toString(),
        subject: 'Molding Order $orderNumber',
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

    final totalOrdered = _calculateTotalOrderedShots();
    final totalReceived = _calculateTotalReceivedShots();
    final totalPending = _calculateTotalPendingShots();

    final variantCount =
        _toInt(order['variantCount']) > 0
            ? _toInt(order['variantCount'])
            : _getItems().length;

    final moldCount =
        _toInt(order['moldCount']) > 0
            ? _toInt(order['moldCount'])
            : molds.length;

    final cavityCount = _toInt(order['cavityCount']);

    final orderId = _stringValue(order['id']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: AppBar(
        elevation: 0,

        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF343741)),

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
          IconButton(
            tooltip: 'Share Order',

            onPressed: () {
              _shareMoldingOrder(context);
            },

            icon: const Icon(Icons.share_outlined),
          ),

          if (orderId.isNotEmpty && status == 'Ordered')
            Padding(
              padding: const EdgeInsets.only(right: 10),

              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder:
                          (_) => CreateMoldingOrderPage(
                            isEditMode: true,

                            orderId: orderId,
                          ),
                    ),
                  );
                },

                icon: const Icon(Icons.edit_outlined, size: 18),

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

                    _buildDateInformation(isMobile: isMobile),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.precision_manufacturing_outlined,

                      title: 'Mold Details',

                      subtitle:
                          '${molds.length} mold${molds.length == 1 ? '' : 's'} in this order',
                    ),

                    const SizedBox(height: 12),

                    if (molds.isEmpty)
                      _buildEmptyCard('No mold details found.')
                    else
                      ...molds.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),

                          child: _buildMoldCard(
                            mold: entry.value,

                            index: entry.key + 1,

                            isMobile: isMobile,
                          ),
                        );
                      }),

                    const SizedBox(height: 8),

                    _buildSectionTitle(
                      icon: Icons.inventory_2_outlined,

                      title: 'All Order Items',

                      subtitle: '${_getItems().length} variants',
                    ),

                    const SizedBox(height: 12),

                    _buildAllItemsSection(isMobile: isMobile),

                    const SizedBox(height: 24),

                    _buildAuditInformation(isMobile: isMobile),

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
              Icons.precision_manufacturing_outlined,

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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),

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
        title: 'Ordered Shots',

        value: ordered,

        icon: Icons.inventory_2_outlined,

        color: const Color(0xFF3F51B5),
      ),

      _QuantityData(
        title: 'Received Shots',

        value: received,

        icon: Icons.check_circle_outline,

        color: const Color(0xFF2E7D32),
      ),

      _QuantityData(
        title: 'Pending Shots',

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

        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),

      child:
          isMobile
              ? Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    _buildQuantityCard(cards[i]),

                    if (i != cards.length - 1) const SizedBox(height: 8),
                  ],
                ],
              )
              : Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: _buildQuantityCard(cards[i])),

                    if (i != cards.length - 1)
                      Container(
                        width: 1,

                        height: 50,

                        margin: const EdgeInsets.symmetric(horizontal: 12),

                        color: const Color(0xFFE5E7EB),
                      ),
                  ],
                ],
              ),
    );
  }

  Widget _buildQuantityCard(_QuantityData data) {
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

            child: Icon(data.icon, size: 20, color: data.color),
          ),

          const SizedBox(width: 11),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

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

      _InfoData(icon: Icons.factory_outlined, label: 'Process', value: process),

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
        crossAxisAlignment: CrossAxisAlignment.start,

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

              children:
                  items.map((item) {
                    return SizedBox(width: 205, child: _buildInfoRow(item));
                  }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDateInformation({required bool isMobile}) {
    return _buildWhiteCard(
      child:
          isMobile
              ? Column(
                children: [
                  _buildInfoRow(
                    _InfoData(
                      icon: Icons.calendar_today_outlined,

                      label: 'Order Date',

                      value: _formatDate(order['orderDate']),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    _InfoData(
                      icon: Icons.schedule_outlined,

                      label: 'Created At',

                      value: _formatDateTime(order['createdAt']),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    _InfoData(
                      icon: Icons.update_outlined,

                      label: 'Last Updated',

                      value: _formatDateTime(order['updatedAt']),
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

                        value: _formatDate(order['orderDate']),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: _buildInfoRow(
                      _InfoData(
                        icon: Icons.schedule_outlined,

                        label: 'Created At',

                        value: _formatDateTime(order['createdAt']),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: _buildInfoRow(
                      _InfoData(
                        icon: Icons.update_outlined,

                        label: 'Last Updated',

                        value: _formatDateTime(order['updatedAt']),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildInfoRow(_InfoData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          width: 34,

          height: 34,

          decoration: BoxDecoration(
            color: const Color(0xFFF3F5FF),

            borderRadius: BorderRadius.circular(8),
          ),

          child: Icon(data.icon, size: 18, color: const Color(0xFF3F51B5)),
        ),

        const SizedBox(width: 9),

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

    final moldId = _stringValue(mold['moldId']);

    final cavityCount = _toInt(mold['cavityCount']);

    final items = _getMoldItems(mold);

    final ordered = _calculateMoldOrderedShots(mold);

    final received = _calculateMoldReceivedShots(mold);

    final pending = _calculateMoldPendingShots(mold);

    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),

      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),

            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFF),

              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  width: 42,

                  height: 42,

                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2FF),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: const Icon(
                    Icons.view_in_ar_outlined,

                    color: Color(0xFF3F51B5),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

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

                          color: const Color(0xFF343741),
                        ),
                      ),

                      if (moldId.isNotEmpty) ...[
                        const SizedBox(height: 2),

                        Text(
                          'ID: $moldId',

                          style: GoogleFonts.poppins(
                            fontSize: 10,

                            color: const Color(0xFF9CA3AF),
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

                      color: const Color(0xFF343741),
                    ),
                  ),
                ),

                const SizedBox(height: 9),

                if (items.isEmpty)
                  _buildEmptyCard('No variants found for this mold.')
                else
                  _buildMoldItems(items, isMobile: isMobile),
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
      ('Ordered Shots', ordered, const Color(0xFF3F51B5)),

      ('Received Shots', received, const Color(0xFF2E7D32)),

      ('Pending Shots', pending, const Color(0xFFE65100)),
    ];

    return isMobile
        ? Column(
          children: [
            for (final item in values) ...[
              _buildSmallQuantity(item.$1, item.$2, item.$3),

              if (item != values.last) const SizedBox(height: 7),
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

              if (i != values.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
  }

  Widget _buildSmallQuantity(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),

        borderRadius: BorderRadius.circular(9),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

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
  // TEMPLE LEFT / RIGHT DISPLAY GROUPING
  //
  // Firestore still keeps Left and Right as separate item records.
  // These helpers only combine them for the View page.
  // ============================================================

  bool _isTempleItem(Map<String, dynamic> item) {
    final component =
        _stringValue(
          item['componentType'] ?? item['component'] ?? item['component_type'],
        ).toLowerCase();

    if (component == 'temple') {
      return true;
    }

    final text =
        [
          item['productName'],
          item['displayName'],
          item['modelName'],
          item['productCode'],
          item['side'],
          item['templeSide'],
          item['componentSide'],
          item['sideName'],
        ].map(_stringValue).join(' ').toLowerCase();

    return text.contains('temple');
  }

  String _itemSide(Map<String, dynamic> item) {
    final directSideKeys = [
      'side',
      'templeSide',
      'componentSide',
      'sideName',
      'productSide',
    ];

    for (final key in directSideKeys) {
      final side = _stringValue(item[key]).toLowerCase();
      if (side == 'left' || side == 'l' || side.startsWith('left ')) {
        return 'left';
      }
      if (side == 'right' || side == 'r' || side.startsWith('right ')) {
        return 'right';
      }
    }

    final searchableText =
        [
          item['productName'],
          item['displayName'],
          item['modelName'],
          item['productCode'],
        ].map(_stringValue).join(' ').toLowerCase();

    final hasLeft = RegExp(r'\bleft\b|\(\s*l\s*\)').hasMatch(searchableText);
    final hasRight = RegExp(r'\bright\b|\(\s*r\s*\)').hasMatch(searchableText);

    if (hasLeft && !hasRight) {
      return 'left';
    }
    if (hasRight && !hasLeft) {
      return 'right';
    }

    return '';
  }

  String _templeGroupKey(Map<String, dynamic> item) {
    final moldProductId =
        _stringValue(item['moldProductId'] ?? item['moldId']).toLowerCase();

    final variant =
        _stringValue(item['variantType'] ?? item['variant']).toLowerCase();

    final cavity =
        _stringValue(item['cavityNumber'] ?? item['cavity']).toLowerCase();

    return '$moldProductId|$variant|$cavity';
  }

  List<Map<String, dynamic>> _groupTempleItems(
    List<Map<String, dynamic>> items,
  ) {
    final result = <Map<String, dynamic>>[];
    final consumed = <int>{};

    for (var i = 0; i < items.length; i++) {
      if (consumed.contains(i)) {
        continue;
      }

      final item = items[i];

      if (!_isTempleItem(item)) {
        result.add(item);
        consumed.add(i);
        continue;
      }

      final side = _itemSide(item);

      // If the item has no identifiable Left/Right side, keep it as-is.
      if (side.isEmpty) {
        result.add(item);
        consumed.add(i);
        continue;
      }

      Map<String, dynamic>? leftItem;
      Map<String, dynamic>? rightItem;
      int leftIndex = -1;
      int rightIndex = -1;

      for (var j = i; j < items.length; j++) {
        if (consumed.contains(j)) {
          continue;
        }

        final candidate = items[j];

        if (!_isTempleItem(candidate)) {
          continue;
        }

        if (_templeGroupKey(candidate) != _templeGroupKey(item)) {
          continue;
        }

        final candidateSide = _itemSide(candidate);

        if (candidateSide == 'left' && leftItem == null) {
          leftItem = candidate;
          leftIndex = j;
        } else if (candidateSide == 'right' && rightItem == null) {
          rightItem = candidate;
          rightIndex = j;
        }
      }

      // Only create a grouped row when both sides exist.
      if (leftItem != null && rightItem != null) {
        final grouped = <String, dynamic>{...item};

        grouped['_isTempleSideGroup'] = true;
        grouped['_templeLeft'] = leftItem;
        grouped['_templeRight'] = rightItem;
        grouped['_templeSides'] = <Map<String, dynamic>>[leftItem, rightItem];

        // Keep common values from the first item. Quantity display is
        // handled separately by _quantityText/_pendingTotal.
        result.add(grouped);

        consumed.add(leftIndex);
        consumed.add(rightIndex);
      } else {
        result.add(item);
        consumed.add(i);
      }
    }

    return result;
  }

  bool _isTempleSideGroup(Map<String, dynamic> item) {
    return item['_isTempleSideGroup'] == true && item['_templeSides'] is List;
  }

  List<Map<String, dynamic>> _templeSides(Map<String, dynamic> item) {
    final raw = item['_templeSides'];

    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  String _shotsText(Map<String, dynamic> item, String field) {
    if (!_isTempleSideGroup(item)) {
      return _itemShots(item, field).toString();
    }

    final sides = _templeSides(item);
    var left = 0;
    var right = 0;

    for (final sideItem in sides) {
      final side = _itemSide(sideItem);
      final shots = _itemShots(sideItem, field);

      if (side == 'left') {
        left = shots;
      } else if (side == 'right') {
        right = shots;
      }
    }

    return 'L $left  •  R $right';
  }

  String _pendingShotsText(Map<String, dynamic> item) {
    int pendingShotsFor(Map<String, dynamic> sideItem) {
      final ordered = _toInt(sideItem['orderedQuantity']);
      final received = _toInt(sideItem['receivedQuantity']);
      final pendingPieces = (ordered - received).clamp(0, ordered).toInt();

      return _shotsFromPieces(pendingPieces, sideItem['piecesPerCycle']);
    }

    if (!_isTempleSideGroup(item)) {
      return pendingShotsFor(item).toString();
    }

    final sides = _templeSides(item);
    var left = 0;
    var right = 0;

    for (final sideItem in sides) {
      final side = _itemSide(sideItem);
      final shots = pendingShotsFor(sideItem);

      if (side == 'left') {
        left = shots;
      } else if (side == 'right') {
        right = shots;
      }
    }

    return 'L $left  •  R $right';
  }

  int _pendingShotsTotal(Map<String, dynamic> item) {
    if (!_isTempleSideGroup(item)) {
      final ordered = _toInt(item['orderedQuantity']);
      final received = _toInt(item['receivedQuantity']);
      final pendingPieces = (ordered - received).clamp(0, ordered).toInt();

      return _shotsFromPieces(pendingPieces, item['piecesPerCycle']);
    }

    return _templeSides(item).fold<int>(0, (maximum, sideItem) {
      final ordered = _toInt(sideItem['orderedQuantity']);
      final received = _toInt(sideItem['receivedQuantity']);
      final pendingPieces = (ordered - received).clamp(0, ordered).toInt();

      final shots = _shotsFromPieces(pendingPieces, sideItem['piecesPerCycle']);

      return shots > maximum ? shots : maximum;
    });
  }

  Widget _templeSideProductInfo(Map<String, dynamic> item) {
    final sides = _templeSides(item);

    if (sides.isEmpty) {
      return _productInfo(item);
    }

    Map<String, dynamic>? left;
    Map<String, dynamic>? right;

    for (final sideItem in sides) {
      final side = _itemSide(sideItem);

      if (side == 'left' && left == null) {
        left = sideItem;
      } else if (side == 'right' && right == null) {
        right = sideItem;
      }
    }

    String nameFor(Map<String, dynamic>? value) {
      if (value == null) {
        return '-';
      }

      final name = _stringValue(value['productName'] ?? value['displayName']);

      final code = _stringValue(value['productCode']);

      if (name.isEmpty && code.isEmpty) {
        return '-';
      }

      if (code.isEmpty) {
        return name;
      }

      if (name.isEmpty) {
        return code;
      }

      return '$name ($code)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Left: ${nameFor(left)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _tableValueStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Right: ${nameFor(right)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOLD ITEMS
  // ============================================================
  Widget _buildMoldItems(
    List<Map<String, dynamic>> items, {
    required bool isMobile,
  }) {
    final displayItems = _groupTempleItems(items);

    if (isMobile) {
      return Column(
        children:
            displayItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildItemCard(item),
              );
            }).toList(),
      );
    }

    return Column(
      children: [
        _buildDesktopItemHeader(),
        const SizedBox(height: 5),
        ...displayItems.map((item) => _buildDesktopItemRow(item)),
      ],
    );
  }

  Widget _buildDesktopItemHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),

      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        children: [
          const SizedBox(width: 75),

          Expanded(flex: 3, child: _tableHeader('Product')),

          Expanded(flex: 2, child: _tableHeader('Variant')),

          Expanded(child: _tableHeader('Cavity')),

          Expanded(child: _tableHeader('Shots Ordered')),

          Expanded(child: _tableHeader('Shots Received')),

          Expanded(child: _tableHeader('Shots Pending')),

          Expanded(child: _tableHeader('Virgin')),

          Expanded(child: _tableHeader('Grinding')),
        ],
      ),
    );
  }

  Widget _buildDesktopItemRow(Map<String, dynamic> item) {
    final orderedText = _shotsText(item, 'orderedQuantity');

    final receivedText = _shotsText(item, 'receivedQuantity');

    final pendingText = _pendingShotsText(item);
    final pendingTotal = _pendingShotsTotal(item);

    final isTempleGroup = _isTempleSideGroup(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isTempleGroup ? const Color(0xFFFCFCFF) : Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: _variantBadge(_stringValue(item['variantType'])),
          ),

          Expanded(
            flex: 3,
            child:
                isTempleGroup
                    ? _templeSideProductInfo(item)
                    : _productInfo(item),
          ),

          Expanded(
            flex: 2,
            child: Text(
              _stringValue(item['variantType']).isEmpty
                  ? '-'
                  : _stringValue(item['variantType']),
              style: _tableValueStyle(),
            ),
          ),

          Expanded(
            child: Text(
              _stringValue(item['cavityNumber']).isEmpty
                  ? '-'
                  : _stringValue(item['cavityNumber']),
              style: _tableValueStyle(),
            ),
          ),

          Expanded(child: _numberText(orderedText)),

          Expanded(
            child: _numberText(receivedText, color: const Color(0xFF2E7D32)),
          ),

          Expanded(
            child: _numberText(
              pendingText,
              color:
                  pendingTotal > 0
                      ? const Color(0xFFE65100)
                      : const Color(0xFF6B7280),
            ),
          ),

          Expanded(child: _ratioText(item['virginRatio'])),

          Expanded(child: _ratioText(item['grindingRatio'])),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final orderedText = _shotsText(item, 'orderedQuantity');

    final receivedText = _shotsText(item, 'receivedQuantity');

    final pendingText = _pendingShotsText(item);
    final pendingTotal = _pendingShotsTotal(item);

    final isTempleGroup = _isTempleSideGroup(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isTempleGroup ? const Color(0xFFFCFCFF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _variantBadge(_stringValue(item['variantType'])),

              const SizedBox(width: 9),

              Expanded(
                child:
                    isTempleGroup
                        ? _templeSideProductInfo(item)
                        : Text(
                          _stringValue(item['productName']).isEmpty
                              ? '-'
                              : _stringValue(item['productName']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF343741),
                          ),
                        ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          if (!isTempleGroup && _stringValue(item['productCode']).isNotEmpty)
            _mobileDetail('Product Code', _stringValue(item['productCode'])),

          if (!isTempleGroup && _stringValue(item['modelName']).isNotEmpty)
            _mobileDetail('Model', _stringValue(item['modelName'])),

          _mobileDetail(
            'Cavity',
            _stringValue(item['cavityNumber']).isEmpty
                ? '-'
                : _stringValue(item['cavityNumber']),
          ),

          _mobileDetail('Quantity', 'Molding shots'),

          if (isTempleGroup) _mobileDetail('Sides', 'Left + Right grouped'),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _mobileQuantity(
                  'Shots',
                  orderedText,
                  const Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileQuantity(
                  'Shots',
                  receivedText,
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _mobileQuantity(
                  'Shots',
                  pendingText,
                  pendingTotal > 0
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ratioColumn('Virgin Ratio', item['virginRatio']),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: _ratioColumn('Grinding Ratio', item['grindingRatio']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productInfo(Map<String, dynamic> item) {
    final productName = _stringValue(item['productName']);

    final productCode = _stringValue(item['productCode']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          productName.isEmpty ? '-' : productName,

          maxLines: 2,

          overflow: TextOverflow.ellipsis,

          style: _tableValueStyle(fontWeight: FontWeight.w600),
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

  Widget _mobileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),

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

                color: const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileQuantity(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),

      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),

        borderRadius: BorderRadius.circular(7),
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

  Widget _ratioColumn(String label, dynamic value) {
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
    return Text(_decimal(value), style: _tableValueStyle());
  }

  Widget _numberText(dynamic value, {Color color = const Color(0xFF343741)}) {
    return Text(
      value.toString(),

      style: _tableValueStyle(color: color, fontWeight: FontWeight.w600),
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
    return Text(text, style: _tableHeaderStyle());
  }

  Widget _variantBadge(String variant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),

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
  Widget _buildAllItemsSection({required bool isMobile}) {
    final items = _getItems();

    if (items.isEmpty) {
      return _buildEmptyCard('No order items found.');
    }

    final displayItems = _groupTempleItems(items);

    if (isMobile) {
      return Column(
        children:
            displayItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildItemCard(item),
              );
            }).toList(),
      );
    }

    return _buildWhiteCard(
      child: Column(
        children: [
          _buildDesktopItemHeader(),
          const SizedBox(height: 5),
          ...displayItems.map((item) => _buildDesktopItemRow(item)),
        ],
      ),
    );
  }

  // ============================================================
  // AUDIT
  // ============================================================
  Widget _buildAuditInformation({required bool isMobile}) {
    final createdByName = _stringValue(order['createdByName']);

    final createdByUid = _stringValue(order['createdByUid']);

    final orderId = _stringValue(order['id']);

    return _buildWhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

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

                    value: createdByName.isEmpty ? '-' : createdByName,
                  ),
                ),

                const SizedBox(height: 12),

                _buildInfoRow(
                  _InfoData(
                    icon: Icons.fingerprint_outlined,

                    label: 'Created By UID',

                    value: createdByUid.isEmpty ? '-' : createdByUid,
                  ),
                ),

                const SizedBox(height: 12),

                _buildInfoRow(
                  _InfoData(
                    icon: Icons.description_outlined,

                    label: 'Firestore Order ID',

                    value: orderId.isEmpty ? '-' : orderId,
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

                      value: createdByName.isEmpty ? '-' : createdByName,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.fingerprint_outlined,

                      label: 'Created By UID',

                      value: createdByUid.isEmpty ? '-' : createdByUid,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: _buildInfoRow(
                    _InfoData(
                      icon: Icons.description_outlined,

                      label: 'Firestore Order ID',

                      value: orderId.isEmpty ? '-' : orderId,
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

            borderRadius: BorderRadius.circular(9),
          ),

          child: Icon(icon, size: 19, color: const Color(0xFF3F51B5)),
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

                  fontWeight: FontWeight.w600,

                  color: const Color(0xFF343741),
                ),
              ),

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

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE0E0E0)),
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

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: const Color(0xFFE5E7EB)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),

        borderRadius: BorderRadius.circular(6),
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
