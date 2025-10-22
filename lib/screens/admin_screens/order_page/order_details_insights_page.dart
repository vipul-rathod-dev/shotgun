// order_details_insights_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shotgun/screens/admin_screens/order_page/models/order_pdf_data.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/order_timeline.dart';
import 'package:shotgun/utils/pdf_generator.dart';

class OrderDetailsInsightsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsInsightsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsInsightsPage> createState() =>
      _OrderDetailsInsightsPageState();
}

class _OrderDetailsInsightsPageState extends State<OrderDetailsInsightsPage> with SingleTickerProviderStateMixin {
  int _previousStep = 0;

  @override
  void didUpdateWidget(covariant OrderDetailsInsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reset animation when order changes
    _previousStep = 0;
  }

  // Formatting helper
  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    try {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    } catch (_) {
      return DateFormat.yMMMd().format(ts.toDate());
    }
  }

  // Map status string to step index for the stepper
  // Steps: 0 Created, 1 Processing, 2 Shipped, 3 Delivered
  int _statusToStepIndex(String? status) {
    if (status == null) return 0;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return 7;
    if (s.contains('packing')) return 6;
    if (s.contains('demo')) return 5;
    if (s.contains('fitting')) return 4;
    if (s.contains('quality')) return 3;
    if (s.contains('color')) return 2;
    if (s.contains('raw')) return 1;
    if (s.contains('received')) return 0;

    return 0;
  }

  // Generate PDF via injected utility and share
  Future<void> _sharePdfFromMap(Map<String, dynamic> data) async {
    try {
      final orderData = OrderPdfData.fromMap(data);
      final pdfBytes = await PdfGenerator.generateOrderPdf(orderData);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Order_${orderData.customerName}.pdf',
      );
    } catch (e) {
      // graceful error
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF share failed: $e')));
      }
    }
  }

  // Compute totals from products list
  Map<String, int> _computeTotals(List<dynamic> products) {
    int totalProducts = products.length;
    int totalQty = 0;
    int totalFocus = 0;
    int totalTemple = 0;

    for (final p in products) {
      try {
        final qty = (p['quantity'] is int) ? p['quantity'] as int : int.tryParse('${p['quantity']}') ?? 0;
        totalQty += qty;

        final customizations = (p['customizations'] as List<dynamic>?) ?? [];
        for (final c in customizations) {
          final fq = (c['focusQty'] is int) ? c['focusQty'] as int : int.tryParse('${c['focusQty']}') ?? 0;
          final tq = (c['templeQty'] is int) ? c['templeQty'] as int : int.tryParse('${c['templeQty']}') ?? 0;
          totalFocus += fq;
          totalTemple += tq;
        }
      } catch (_) {
        // ignore malformed product entries
      }
    }

    return {
      'totalProducts': totalProducts,
      'totalQty': totalQty,
      'totalFocus': totalFocus,
      'totalTemple': totalTemple,
    };
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Order Insights'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final products = data['products'] as List<dynamic>? ?? [];

          // Determine current step from status field primarily, fallback to dates
          final statusField = data['orderStatus'] as String?;
          int currentStep = _statusToStepIndex(statusField);

          // orderStatus: "Received"
          // orderStatus: "Raw Process"
          // orderStatus: "Color Process"
          // orderStatus: "Quality Check"
          // orderStatus: "Fitting Process"
          // orderStatus: "Demo Process"
          // orderStatus: "Packing"
          // orderStatus: "Shipping"


          switch (statusField) {
            case 'Created':
            // case 'Pending':
              currentStep = 0;
              break;
            case 'Processing':
              currentStep = 1;
              break;
            case 'Shipped':
              currentStep = 2;
              break;
            case 'Delivered':
              currentStep = 3;
              break;
            default:
              currentStep = 0;
          }

          // If status is missing, infer from dates
          if (statusField == null || statusField.trim().isEmpty) {
            final hasOrderDate = data['orderDate'] != null;
            final hasShippingDate = data['shippingDate'] != null;
            final hasDeliveryDate = data['deliveryDate'] != null;
            if (hasDeliveryDate) currentStep = 3;
            else if (hasShippingDate) currentStep = 2;
            else if (hasOrderDate) currentStep = 1;
            else currentStep = 0;
            if (currentStep != _previousStep) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {
                    _previousStep = currentStep;
                  });
                }
              });
            }
          }

          final totals = _computeTotals(products);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== Order Insights Gradient Header =====
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB3E5FC), Color(0xFF80DEEA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Top row: customer + status badge + order id
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar / icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Colors.indigo.shade400,
                              Colors.blue.shade300,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.shopping_bag,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['customerName'] ?? 'Unknown Customer'}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Order ID: ${data['orderNumber']}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusToBadgeColor(
                                          (data['orderStatus'] as String?)),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _statusToBadgeColor(
                                                  (data['orderStatus'] as String?))
                                              .withOpacity(0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      (data['orderStatus'] as String? ?? 'Unknown')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Dates summary
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 14, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDate(data['orderDate']),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ===== Animated Timeline (custom step progress bar with tooltips) =====
                    OrderTimeline(
                      status: data['orderStatus'] ?? 'Received',
                      statusDates: {
                        "Received": data['receivedDate']?.toDate(),
                        "Raw Process": data['rawProcessDate']?.toDate(),
                        "Color Process": data['colorProcessDate']?.toDate(),
                        "Quality Check": data['qualityCheckDate']?.toDate(),
                        "Fitting Process": data['fittingProcessDate']?.toDate(),
                        "Demo Process": data['demoProcessDate']?.toDate(),
                        "Packing": data['packingDate']?.toDate(),
                        "Shipping": data['shippingDate']?.toDate(),
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ===== Stats Card =====
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statItem(
                        title: 'Products',
                        value: '${totals['totalProducts']}',
                        icon: Icons.widgets,
                      ),
                      _statItem(
                        title: 'Quantity',
                        value: '${totals['totalQty']}',
                        icon: Icons.format_list_numbered,
                      ),
                      _statItem(
                        title: 'Focus Qty',
                        value: '${totals['totalFocus']}',
                        icon: Icons.color_lens,
                      ),
                      _statItem(
                        title: 'Temple Qty',
                        value: '${totals['totalTemple']}',
                        icon: Icons.straighten,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== Products header =====
              const Text(
                'Product Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // ===== Products list =====
              if (products.isEmpty)
                const Text('No products in this order.')
              else
                ...products.map((p) {
                  final productName = p['productName'] ?? 'Unnamed Product';
                  final qty = p['quantity'] ?? 0;
                  final customizations =
                      (p['customizations'] as List<dynamic>?) ?? [];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$productName',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Qty: $qty',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700)),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (customizations.isEmpty)
                              const Text(
                                'No customizations',
                                style: TextStyle(color: Colors.grey),
                              ),
                            if (customizations.isNotEmpty)
                              Column(
                                children: customizations.map<Widget>((c) {
                                  final focusColor = (c['focusColor'] ?? '')
                                      .toString()
                                      .trim();
                                  final templeColor = (c['templeColor'] ?? '')
                                      .toString()
                                      .trim();
                                  final focusQty = c['focusQty'] ?? 0;
                                  final templeQty = c['templeQty'] ?? 0;
                                  // final notes = c['notes'] ?? '';

                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        // Focus color chip
                                        Expanded(
                                          child: Row(
                                            children: [
                                              _colorPreviewChip(focusColor),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Focus: ${focusColor.isEmpty ? '—' : focusColor}',
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ),
                                              Text('x$focusQty',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),

                                        // Temple color chip
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              _colorPreviewChip(templeColor),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Temple: ${templeColor.isEmpty ? '—' : templeColor}',
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ),
                                              Text('x$templeQty',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (p['remarks'] != null &&
                                (p['remarks'] as String).trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Remarks: ${p['remarks']}',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                              )
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 80),
            ],
          );
        },
      ),

      // Floating Action Buttons (Share PDF) - uses current snapshot data to generate pdf
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return FloatingActionButton.extended(
            onPressed: () => _sharePdfFromMap(data),
            label: const Text('Share PDF'),
            icon: const Icon(Icons.share),
            backgroundColor: Colors.indigo,
          );
        },
      ),
    );
  }

  // Helper to render stat items in the stats card
  Widget _statItem(
      {required String title, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.indigo.shade300,
              Colors.blue.shade200,
            ]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54))
      ],
    );
  }

  // Small color preview chip: tries to parse hex or show a text circle fallback
  Widget _colorPreviewChip(String colorLabel) {
    // Try parse hex like "#FF0000" or "FF0000" or "0xFFFF0000"
    Color? parsed;
    final cleaned = colorLabel.replaceAll('#', '').replaceAll('0x', '');
    if (cleaned.length == 6 || cleaned.length == 8) {
      try {
        final hex = int.parse(cleaned, radix: 16);
        parsed = cleaned.length == 6 ? Color(0xFF000000 | hex) : Color(hex);
      } catch (_) {
        parsed = null;
      }
    }

    if (parsed != null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: parsed,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
      );
    }

    // fallback: show first char
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade200,
      child: Text(
        colorLabel.isNotEmpty ? colorLabel[0].toUpperCase() : '-',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  // Map textual status to badge background color (vivid)
  Color _statusToBadgeColor(String? status) {
    if (status == null) return Colors.grey.shade600;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return Colors.teal.shade700;
    if (s.contains('packing')) return Colors.orange.shade700;
    if (s.contains('demo')) return Colors.purple.shade600;
    if (s.contains('fitting')) return Colors.indigo.shade600;
    if (s.contains('quality')) return Colors.blue.shade600;
    if (s.contains('color')) return Colors.pink.shade400;
    if (s.contains('raw')) return Colors.amber.shade700;
    if (s.contains('received')) return Colors.green.shade600;

    return Colors.grey.shade600;
  }

}
