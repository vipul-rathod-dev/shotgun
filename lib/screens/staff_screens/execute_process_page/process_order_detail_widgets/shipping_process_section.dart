import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShippingProcessSection extends StatefulWidget {
  final Map order;
  final List products;
  final DocumentReference orderRef;

  const ShippingProcessSection({
    super.key,
    required this.order,
    required this.products,
    required this.orderRef,
  });

  @override
  State<ShippingProcessSection> createState() =>
      _ShippingProcessSectionState();
}

class _ShippingProcessSectionState extends State<ShippingProcessSection> {
  final TextEditingController _transportNameController =
      TextEditingController();
  final TextEditingController _parcelCountController =
      TextEditingController();

  bool _isShipping = false;

  @override
  void initState() {
    super.initState();

    final existingTransport = widget.order["transportName"];
    final existingParcels = widget.order["numberOfParcels"];

    if (existingTransport != null) {
      _transportNameController.text = existingTransport.toString();
    }
    if (existingParcels != null) {
      _parcelCountController.text = existingParcels.toString();
    }
  }

  @override
  void dispose() {
    _transportNameController.dispose();
    _parcelCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packed = widget.order["productsPacked"] ?? {};

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildSummary(context, packed),
          const SizedBox(height: 18),
          _buildProducts(context, packed),
          const SizedBox(height: 22),
          _buildShippingDetails(context),
          const SizedBox(height: 18),
          _buildShippingButton(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            color: primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shipping Process',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF343741),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Review packed quantities before shipping',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------------

  Widget _buildSummary(
    BuildContext context,
    Map packed,
  ) {
    int totalRequired = 0;
    int totalPacked = 0;
    int totalRemaining = 0;

    for (final product in widget.products) {
      final id = product["productId"];
      final requiredQty = _toInt(product["quantity"]);
      final packedQty = _toInt(packed[id]?["packed"]);

      totalRequired += requiredQty;
      totalPacked += packedQty;
      totalRemaining += requiredQty - packedQty;
    }

    final progress = totalRequired <= 0
        ? 0.0
        : (totalPacked / totalRequired).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final cards = [
          _SummaryData(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            value: '${widget.products.length}',
          ),
          _SummaryData(
            icon: Icons.assignment_outlined,
            label: 'Required',
            value: '$totalRequired',
          ),
          _SummaryData(
            icon: Icons.check_circle_outline,
            label: 'Packed',
            value: '$totalPacked',
          ),
          _SummaryData(
            icon: Icons.pending_outlined,
            label: 'Remaining',
            value: '$totalRemaining',
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context, cards[0])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSummaryCard(context, cards[1])),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context, cards[2])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSummaryCard(context, cards[3])),
                ],
              ),
              const SizedBox(height: 14),
              _buildProgressCard(context, progress),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(
                    child: _buildSummaryCard(context, cards[i]),
                  ),
                  if (i != cards.length - 1)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _buildProgressCard(context, progress),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    _SummaryData data,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 78,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              color: primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF343741),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    double progress,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final percentage = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: primary.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Packing Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF343741),
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // PRODUCTS
  // ------------------------------------------------------------------

  Widget _buildProducts(
    BuildContext context,
    Map packed,
  ) {
    if (widget.products.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;

        if (constraints.maxWidth >= 1100) {
          columns = 3;
        } else if (constraints.maxWidth >= 700) {
          columns = 2;
        } else {
          columns = 1;
        }

        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: widget.products.map<Widget>((product) {
            return SizedBox(
              width: cardWidth,
              child: _buildProductCard(
                context,
                product,
                packed,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Map product,
    Map packed,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    final id = product["productId"];
    final productName = _value(product["productName"]);
    final requiredQty = _toInt(product["quantity"]);
    final packedQty = _toInt(packed[id]?["packed"]);
    final remaining = requiredQty - packedQty;

    final isComplete = requiredQty > 0 && packedQty >= requiredQty;
    final isPartial = packedQty > 0 && !isComplete;

    final status = isComplete
        ? 'Packed'
        : isPartial
            ? 'Partially Packed'
            : 'Not Packed';

    final statusColor = isComplete
        ? Colors.green.shade700
        : isPartial
            ? Colors.orange.shade700
            : Colors.grey.shade700;

    final progress = requiredQty <= 0
        ? 0.0
        : (packedQty / requiredQty).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF343741),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Product ID: ${_value(id)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(status, statusColor),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _quantityMetric(
                  label: 'Required',
                  value: '$requiredQty',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quantityMetric(
                  label: 'Packed',
                  value: '$packedQty',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quantityMetric(
                  label: 'Remaining',
                  value: '$remaining',
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityMetric({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF343741),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(
    String status,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 105),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
          Text(
            'No products found',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF343741),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // SHIPPING DETAILS
  // ------------------------------------------------------------------

  Widget _buildShippingDetails(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Shipping Details',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF343741),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final transportField = _shippingField(
                controller: _transportNameController,
                label: 'Transport Name',
                hint: 'Enter transport / courier name',
                icon: Icons.local_shipping_outlined,
                textInputAction: TextInputAction.next,
              );
              final parcelField = _shippingField(
                controller: _parcelCountController,
                label: 'Number of Parcels',
                hint: 'Enter parcel count',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
              );

              if (isMobile) {
                return Column(
                  children: [
                    transportField,
                    const SizedBox(height: 12),
                    parcelField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: transportField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: parcelField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shippingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: Color(0xFF3F51B5),
            width: 1.5,
          ),
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 11,
          color: Colors.grey,
        ),
      ),
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF343741),
      ),
    );
  }

  // ------------------------------------------------------------------
  // SHIPPING BUTTON
  // ------------------------------------------------------------------

  Widget _buildShippingButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: _isShipping ? null : _markAsShipped,
        icon: _isShipping
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.local_shipping_outlined, size: 19),
        label: Text(
          _isShipping ? 'Marking as Shipped...' : 'Mark as Shipped',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _markAsShipped() async {
    final transportName = _transportNameController.text.trim();
    final parcelText = _parcelCountController.text.trim();
    final parcelCount = int.tryParse(parcelText);

    if (transportName.isEmpty) {
      _showMessage('Please enter the transport name.');
      return;
    }

    if (parcelText.isEmpty || parcelCount == null || parcelCount <= 0) {
      _showMessage('Please enter a valid number of parcels.');
      return;
    }

    setState(() => _isShipping = true);

    try {
      await widget.orderRef.update({
        "orderStatus": "Shipped",
        "shippingTimestamp": FieldValue.serverTimestamp(),
        "transportName": transportName,
        "numberOfParcels": parcelCount,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as shipped successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to mark order as shipped: $e');
    } finally {
      if (mounted) {
        setState(() => _isShipping = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ------------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------------

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _value(dynamic value) {
    if (value == null) {
      return '-';
    }

    final result = value.toString().trim();

    if (result.isEmpty || result == 'null') {
      return '-';
    }

    return result;
  }
}

class _SummaryData {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryData({
    required this.icon,
    required this.label,
    required this.value,
  });
}
