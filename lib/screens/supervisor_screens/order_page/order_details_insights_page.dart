// order_details_insights_page.dart
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/widgets/order_timeline.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class OrderDetailsInsightsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsInsightsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsInsightsPage> createState() =>
      _OrderDetailsInsightsPageState();
}

class _OrderDetailsInsightsPageState extends State<OrderDetailsInsightsPage> with SingleTickerProviderStateMixin {
  int _previousStep = 0;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyId = prefs.getString('cachedCompanyId');
    });
  }

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
    if (_companyId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final orderStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
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
                      orderType: data['orderType'] ?? 'Customized Order',
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
                  final price = (p['price'] ?? 0);
                  final totalAmount = (qty * price);

                  final double grandTotal = products.fold(0.0, (sum, p) {
                    final qty = (p['quantity'] ?? 0) as num;
                    final price = (p['price'] ?? 0) as num;
                    return sum + (qty * price);
                  });

                  final productCustomizations = data['productCustomizations'];
                  final modelGender = p['modelGender'];
                  final perModelOrderQty =qty/data['boxQuantity'][modelGender];

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
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Price: ₹${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87)),
                                Text('Total: ₹${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              ],
                            ),

                            const SizedBox(height: 10),
                            if (productCustomizations.isEmpty)
                              const Text(
                                'No customizations',
                                style: TextStyle(color: Colors.grey),
                              ),
                            if (productCustomizations.isNotEmpty)
                              Column(
                                children: productCustomizations[modelGender].map<Widget>((c) {
                                  final focusColor = (c['focusColor'] ?? '')
                                      .toString()
                                      .trim();
                                  final templeColor = (c['templeColor'] ?? '')
                                      .toString()
                                      .trim();
                                  final focusQty = (c['focusQty'] ?? 0)*perModelOrderQty;
                                  final templeQty = (c['templeQty'] ?? 0)*perModelOrderQty;
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
                                                  focusColor.isEmpty ? '—' : focusColor,
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ),
                                              Text('$focusQty',
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
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
                                                  templeColor.isEmpty ? '—' : templeColor,
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ),
                                              Text('$templeQty',
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
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
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Grand Total:',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                    ),
                                    Text(
                                      '₹${grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final doc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(_companyId)
              .collection('orders')
              .doc(widget.orderId)
              .get();

          if (!doc.exists) return;
          final data = doc.data() as Map<String, dynamic>;
          final products = data['products'] as List<dynamic>? ?? [];

          // 🧠 Ask user which PDF to share
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                    title: const Text('Share Full Order Insights PDF'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _generateAndSharePDF(data, products);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: Colors.deepOrange),
                    title: const Text('Share Product Customizations PDF'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _generateAndShareCustomizationsPdf(data, data['products']);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Share PDF'),
        backgroundColor: Colors.indigo,
      ),
    );
  }
  
  // PDF generator helper
  Future<void> _generateAndSharePDF(Map<String, dynamic> data, List<dynamic> products) async {
    final pdf = pw.Document();
    final totals = _computeTotals(products);

    // Gradient colors for header
    final headerGradient = [
      PdfColors.lightBlue200,
      PdfColors.cyan200,
    ];

    final grandTotal = products.fold<double>(0.0, (sum, p) {
      final qty = (p['quantity'] ?? 0) as num;
      final price = (p['price'] ?? 0) as num;
      return sum + (qty * price);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // ===== Gradient Header =====
          pw.Container(
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: headerGradient,
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 48,
                  height: 48,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    gradient: pw.LinearGradient(
                      colors: [PdfColors.indigo400, PdfColors.blue300],
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Icon(
                      pw.IconData(0xe8cc), // shopping_bag icon
                      color: PdfColors.white,
                      size: 20,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${data['customerName'] ?? 'Unknown Customer'}',
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black)),
                      pw.SizedBox(height: 4),
                      pw.Text('Order ID: ${data['orderNumber'] ?? '-'}',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: _pdfStatusColor(data['orderStatus']),
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Text(
                              (data['orderStatus'] ?? 'Unknown').toUpperCase(),
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Icon(pw.IconData(0xe935),
                              size: 10, color: PdfColors.black),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            _formatDate(data['orderDate']),
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ===== Stats Section =====
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.grey100,
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStatItem('Products', '${totals['totalProducts']}'),
                _pdfStatItem('Quantity', '${totals['totalQty']}'),
                _pdfStatItem('Focus Qty', '${totals['totalFocus']}'),
                _pdfStatItem('Temple Qty', '${totals['totalTemple']}'),
              ],
            ),
          ),

          pw.SizedBox(height: 16),
          pw.Text('Product Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          // ===== Product Cards =====
          ...products.map((p) {
            final productName = p['productName'] ?? 'Unnamed Product';
            final qty = p['quantity'] ?? 0;
            final price = (p['price'] ?? 0).toDouble();
            final totalAmount = qty * price;
            final productCustomizations = data['productCustomizations'];
            final modelGender = p['modelGender'];
            final perModelOrderQty = qty / data['boxQuantity'][modelGender];

            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(productName,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('Qty: $qty',
                          style: pw.TextStyle(
                              color: PdfColors.blue800,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Price: Rs.${price.toStringAsFixed(2)}   |   Total: Rs.${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),

                  pw.SizedBox(height: 6),
                  if (productCustomizations.isNotEmpty)
                    pw.Column(
                      children: productCustomizations[modelGender].map<pw.Widget>((c) {
                        final focusColor = (c['focusColor'] ?? '').toString();
                        final templeColor = (c['templeColor'] ?? '').toString();
                        final focusQty = (c['focusQty'] ?? 0) * perModelOrderQty;
                        final templeQty = (c['templeQty'] ?? 0) * perModelOrderQty;

                        return pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 3),
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            border: pw.Border.all(color: PdfColors.grey200),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              _pdfColorChip(focusColor, 'Focus', focusQty),
                              _pdfColorChip(templeColor, 'Temple', templeQty),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          }).toList(),

          pw.SizedBox(height: 16),

          // ===== Grand Total =====
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green300),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Grand Total:',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.Text('Rs.${grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ],
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/order_${data['orderNumber']}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        text: 'Order report for ${data['customerName']}');
  }

  // PDF helper for status badge colors
  PdfColor _pdfStatusColor(String? status) {
    if (status == null) return PdfColors.grey600;
    final s = status.toLowerCase();

    if (s.contains('shipping')) return PdfColors.deepPurple;
    if (s.contains('packing')) return PdfColors.teal;
    if (s.contains('demo')) return PdfColors.pink;
    if (s.contains('fitting')) return PdfColors.orange;
    if (s.contains('quality')) return PdfColors.amber;
    if (s.contains('color')) return PdfColors.cyan;
    if (s.contains('raw')) return PdfColors.indigo;
    if (s.contains('received')) return PdfColors.blue;
    return PdfColors.grey;
  }

  // PDF helper for stats
  pw.Widget _pdfStatItem(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 2),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    );
  }

  // PDF color preview chip
  pw.Widget _pdfColorChip(String colorLabel, String title, num qty) {
    PdfColor? parsed;
    final cleaned = colorLabel.replaceAll('#', '').replaceAll('0x', '');
    if (cleaned.length == 6 || cleaned.length == 8) {
      try {
        final hex = int.parse(cleaned, radix: 16);
        parsed = PdfColor.fromInt(cleaned.length == 6 ? (0xFF000000 | hex) : hex);
      } catch (_) {
        parsed = null;
      }
    }

    return pw.Row(
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            color: parsed ?? PdfColors.grey400,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text('$title: ${colorLabel.isEmpty ? "-" : colorLabel} ($qty)',
            style: pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // Future<void> _generateAndShareCustomizationsPdf(Map<String, dynamic> data, List<dynamic> products) async {
  //   final pdf = pw.Document();
  //   final totals = _computeTotals(products);
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(24),
  //       build: (context) => [
  //         // ===== Stats Section =====
  //         pw.Container(
  //           decoration: pw.BoxDecoration(
  //             borderRadius: pw.BorderRadius.circular(8),
  //             color: PdfColors.grey100,
  //           ),
  //           padding: const pw.EdgeInsets.all(10),
  //           child: pw.Row(
  //             mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
  //             children: [
  //               _pdfStatItem('Products', '${totals['totalProducts']}'),
  //               _pdfStatItem('Quantity', '${totals['totalQty']}'),
  //               _pdfStatItem('Focus Qty', '${totals['totalFocus']}'),
  //               _pdfStatItem('Temple Qty', '${totals['totalTemple']}'),
  //             ],
  //           ),
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Text('Product Details',
  //             style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
  //         pw.SizedBox(height: 8),
  //         // ===== Product Cards =====
  //         ...products.map((p) {
  //           final productName = p['productName'] ?? 'Unnamed Product';
  //           final qty = p['quantity'] ?? 0;
  //           final productCustomizations = data['productCustomizations'];
  //           final modelGender = p['modelGender'];
  //           final perModelOrderQty = qty / data['boxQuantity'][modelGender];
  //           return pw.Container(
  //             margin: const pw.EdgeInsets.symmetric(vertical: 6),
  //             padding: const pw.EdgeInsets.all(10),
  //             decoration: pw.BoxDecoration(
  //               color: PdfColors.white,
  //               borderRadius: pw.BorderRadius.circular(8),
  //               border: pw.Border.all(color: PdfColors.grey300),
  //             ),
  //             child: pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Row(
  //                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     pw.Text(productName,
  //                         style: pw.TextStyle(
  //                             fontWeight: pw.FontWeight.bold, fontSize: 12)),
  //                     pw.Text('Qty: $qty',
  //                         style: pw.TextStyle(
  //                             color: PdfColors.blue800,
  //                             fontWeight: pw.FontWeight.bold,
  //                             fontSize: 11)),
  //                   ],
  //                 ),
  //                 pw.SizedBox(height: 6),
  //                 if (productCustomizations.isNotEmpty)
  //                   pw.Column(
  //                     children: productCustomizations[modelGender].map<pw.Widget>((c) {
  //                       final focusColor = (c['focusColor'] ?? '').toString();
  //                       final templeColor = (c['templeColor'] ?? '').toString();
  //                       final focusQty = (c['focusQty'] ?? 0) * perModelOrderQty;
  //                       final templeQty = (c['templeQty'] ?? 0) * perModelOrderQty;
  //                       return pw.Container(
  //                         margin: const pw.EdgeInsets.symmetric(vertical: 3),
  //                         padding: const pw.EdgeInsets.all(6),
  //                         decoration: pw.BoxDecoration(
  //                           color: PdfColors.grey50,
  //                           border: pw.Border.all(color: PdfColors.grey200),
  //                           borderRadius: pw.BorderRadius.circular(6),
  //                         ),
  //                         child: pw.Row(
  //                           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                           children: [
  //                             _pdfColorChip(focusColor, 'Focus', focusQty),
  //                             _pdfColorChip(templeColor, 'Temple', templeQty),
  //                           ],
  //                         ),
  //                       );
  //                     }).toList(),
  //                   ),
  //               ],
  //             ),
  //           );
  //         }).toList(),
  //       ],
  //     ),
  //   );
  //   final dir = await getTemporaryDirectory();
  //   final file = File('${dir.path}/order_${data['orderNumber']}.pdf');
  //   await file.writeAsBytes(await pdf.save());
  //   await Share.shareXFiles([XFile(file.path)],
  //       text: 'Order report for ${data['customerName']}');
  // }

  Future<void> _generateAndShareCustomizationsPdf(
    Map<String, dynamic> data,
    List<dynamic> products,
  ) async {
    final pdf = pw.Document();

    final productCustomizations =
        (data['productCustomizations'] ?? {}) as Map<String, dynamic>;
    final boxQtyData = (data['boxQuantity'] ?? {}) as Map<String, dynamic>;

    // Group products by gender
    final groupedProducts = <String, List<Map<String, dynamic>>>{};
    for (final p in products) {
      final gender = (p['modelGender'] ?? 'Unknown').toString();
      groupedProducts.putIfAbsent(gender, () => []).add(p as Map<String, dynamic>);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Product Customizations',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 16),

          ...groupedProducts.entries.map((entry) {
            final gender = entry.key;
            final genderProducts = entry.value;
            final genderCustoms =
                (productCustomizations[gender] ?? []) as List<dynamic>;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  color: PdfColors.blue100,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: pw.Text(
                    gender,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Each Product Card
                ...genderProducts.map((p) {
                  final productName = p['productName'] ?? 'Unnamed Product';
                  final qty = (p['quantity'] ?? 0) as num;
                  final boxQty = (boxQtyData[gender] ?? 1).toDouble();
                  final perModelOrderQty = boxQty == 0 ? 0 : qty / boxQty;

                  return pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 6),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Product title and quantity
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              productName,
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Qty: $qty',
                              style: pw.TextStyle(
                                color: PdfColors.blue800,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),

                        // Customization Table
                        if (genderCustoms.isNotEmpty)
                          pw.Table(
                            border: pw.TableBorder.all(color: PdfColors.grey300),
                            columnWidths: {
                              0: const pw.FlexColumnWidth(2), // Focus Color
                              1: const pw.FlexColumnWidth(1), // Focus Qty
                              2: const pw.FlexColumnWidth(1), // Received Focus
                              3: const pw.FlexColumnWidth(1), // Repairing Focus
                              4: const pw.FlexColumnWidth(2), // Temple Color
                              5: const pw.FlexColumnWidth(1), // Temple Qty
                              6: const pw.FlexColumnWidth(1), // Received Temple Right
                              7: const pw.FlexColumnWidth(1), // Received Temple Left
                              8: const pw.FlexColumnWidth(1), // Repairing Temple Right
                              9: const pw.FlexColumnWidth(1), // Repairing Temple Left
                            },
                            children: [
                              // Header row (existing)
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                                children: [
                                  for (final header in [
                                    'Focus Color', 'Qty', 'Received Focus', 'Repairing Focus',
                                    'Temple Color', 'Qty', 'Received Temple R', 'Received Temple L',
                                    'Repairing Temple R', 'Repairing Temple L'
                                  ])
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text(header,
                                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                    ),
                                ],
                              ),
                              // Data rows
                              ...genderCustoms.map((c) {
                                final focusColor = (c['focusColor'] ?? '').toString();
                                final templeColor = (c['templeColor'] ?? '').toString();

                                String focusQty =
                                    (((c['focusQty'] ?? 0) as num) * perModelOrderQty == 0) ? '' : (((c['focusQty'] ?? 0) as num) * perModelOrderQty).toStringAsFixed(0);
                                String receivedFocus =
                                    (((c['receivedFocus'] ?? 0) as num) == 0) ? '' : (c['receivedFocus'] ?? 0).toString();
                                String repairingFocus =
                                    (((c['repairingFocus'] ?? 0) as num) == 0) ? '' : (c['repairingFocus'] ?? 0).toString();

                                String templeQty =
                                    (((c['templeQty'] ?? 0) as num) * perModelOrderQty == 0) ? '' : (((c['templeQty'] ?? 0) as num) * perModelOrderQty).toStringAsFixed(0);
                                String receivedTempleR =
                                    (((c['receivedTempleR'] ?? 0) as num) == 0) ? '' : (c['receivedTempleR'] ?? 0).toString();
                                String receivedTempleL =
                                    (((c['receivedTempleL'] ?? 0) as num) == 0) ? '' : (c['receivedTempleL'] ?? 0).toString();
                                String repairingTempleR =
                                    (((c['repairingTempleR'] ?? 0) as num) == 0) ? '' : (c['repairingTempleR'] ?? 0).toString();
                                String repairingTempleL =
                                    (((c['repairingTempleL'] ?? 0) as num) == 0) ? '' : (c['repairingTempleL'] ?? 0).toString();

                                return pw.TableRow(
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(focusColor)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(focusQty)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(receivedFocus)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(repairingFocus)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(templeColor)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(templeQty)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(receivedTempleR)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(receivedTempleL)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(repairingTempleR)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(repairingTempleL)),
                                  ],
                                );
                              }).toList(),
                              // Totals row
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                children: [
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Totals', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['focusQty'] ?? 0) as num) * perModelOrderQty == 0 ? 0 : ((c['focusQty'] ?? 0) as num) * perModelOrderQty).toStringAsFixed(0),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['receivedFocus'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['repairingFocus'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')), // Temple Color blank
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['templeQty'] ?? 0) as num) * perModelOrderQty == 0 ? 0 : ((c['templeQty'] ?? 0) as num) * perModelOrderQty).toStringAsFixed(0),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['receivedTempleR'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['receivedTempleL'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['repairingTempleR'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      genderCustoms.fold<num>(0, (sum, c) => sum + ((c['repairingTempleL'] ?? 0) as num)).toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )

                        else
                          pw.Text(
                            'No customizations found for $gender',
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),

                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/customizations_${data['orderNumber']}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Product Customizations for ${data['orderNumber']}',
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
