import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProcessHeader extends StatefulWidget {
  final String taskTitle;
  final String stage;
  final Map order;

  const ProcessHeader({
    super.key,
    required this.taskTitle,
    required this.stage,
    required this.order,
  });

  @override
  State<ProcessHeader> createState() => _ProcessHeaderState();
}

class _ProcessHeaderState extends State<ProcessHeader> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
        children: [
          _buildAccordionHeader(context),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _buildExpandedContent(context),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionHeader(BuildContext context) {
    final orderNumber = _value(widget.order['orderNumber']);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 450;

            if (isNarrow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProcessIcon(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.taskTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF343741),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildExpandIcon(),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Stage',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            _stageBadge(context),
                          ],
                        ),
                        if (!_isExpanded) ...[
                          const SizedBox(height: 8),
                          _collapsedOrderNumber(orderNumber),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProcessIcon(context),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.taskTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF343741),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Stage',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          _stageBadge(context),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!_isExpanded) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: _collapsedOrderNumber(orderNumber),
                  ),
                ],
                const SizedBox(width: 8),
                _buildExpandIcon(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandIcon() {
    return AnimatedRotation(
      turns: _isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 250),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 28,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _collapsedOrderNumber(String orderNumber) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Text(
        orderNumber,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF343741),
        ),
      ),
    );
  }

  Widget _buildProcessIcon(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: primary,
        size: 24,
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final orderNumber = _value(widget.order['orderNumber']);
    final brand = _value(widget.order['brandName']);
    final orderType = _value(widget.order['orderType']);
    final orderStatus = _value(widget.order['orderStatus']);
    final customerName = _value(widget.order['customerName']);
    final customerPhone = _value(widget.order['customerPhone']);

    return Column(
      children: [
        Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            final items = [
              _InfoItem(
                icon: Icons.receipt_long_outlined,
                label: 'Order Number',
                value: orderNumber,
              ),
              _InfoItem(
                icon: Icons.business_outlined,
                label: 'Brand',
                value: brand,
              ),
              _InfoItem(
                icon: Icons.category_outlined,
                label: 'Order Type',
                value: orderType,
              ),
              _InfoItem(
                icon: Icons.sync_outlined,
                label: 'Order Status',
                value: orderStatus,
                isStatus: true,
              ),
              _InfoItem(
                icon: Icons.person_outline,
                label: 'Customer',
                value: customerName,
              ),
              _InfoItem(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: customerPhone,
              ),
            ];

            if (isMobile) {
              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    _buildInfoCard(context, items[i]),
                    if (i != items.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((item) {
                return SizedBox(
                  width: _getCardWidth(constraints.maxWidth),
                  child: _buildInfoCard(context, item),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  double _getCardWidth(double width) {
    if (width >= 1100) {
      return (width - 36) / 4;
    }

    if (width >= 800) {
      return (width - 24) / 3;
    }

    return (width - 12) / 2;
  }

  Widget _stageBadge(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.stage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    _InfoItem item,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                item.isStatus
                    ? _statusBadge(context, item.value)
                    : Text(
                        item.value,
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
      ),
    );
  }

  Widget _statusBadge(
    BuildContext context,
    String status,
  ) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains('completed') ||
        value.contains('complete') ||
        value.contains('packed')) {
      return Colors.green.shade700;
    }

    if (value.contains('progress') ||
        value.contains('process') ||
        value.contains('started')) {
      return Colors.orange.shade700;
    }

    if (value.contains('pending') ||
        value.contains('received')) {
      return Colors.blue.shade700;
    }

    return Colors.grey.shade700;
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

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final bool isStatus;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isStatus = false,
  });
}
