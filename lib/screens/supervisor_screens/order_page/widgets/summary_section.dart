import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/controllers/add_order_controller.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  double _getTotal(AddOrderController c) =>
      c.products.fold<double>(0, (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)));

  String _fmtDate(DateTime? date) =>
      date == null ? '-' : DateFormat('dd MMM yyyy').format(date);

  /// 🔹 Aggregate total Focus and Temple quantities by baseMaterial
  Map<String, Map<String, Map<String, int>>> _getBaseMaterialSummary(
    Map<String, List<Map<String, dynamic>>> customizations,
    Map<String, dynamic> productsMap) {
    final Map<String, Map<String, Map<String, int>>> summary = {};

    for (final entry in customizations.entries) {
      final productId = entry.key;
      final productName = productsMap[productId]?['productName'] ?? 'Unknown Product';
      final productCustomizations = entry.value;

      for (final c in productCustomizations) {
        final base = (c['focusBaseMaterial'] ?? 'Unknown').toString();
        final focusQty = (c['focusQty'] ?? 0) as int;
        final templeQty = (c['templeQty'] ?? 0) as int;

        summary.putIfAbsent(base, () => {});
        summary[base]!.putIfAbsent(productName, () => {'focus': 0, 'temple': 0});
        summary[base]![productName]!['focus'] =
            summary[base]![productName]!['focus']! + focusQty;
        summary[base]![productName]!['temple'] =
            summary[base]![productName]!['temple']! + templeQty;
      }
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AddOrderController>(
      builder: (context, c, _) {
        final total = _getTotal(c);
        final products = c.products;
        final customizations = c.productCustomizations;
        final Map<String, Map<String, dynamic>> productsMap = {
          for (var p in c.products)
            (p['productId'] ?? '').toString(): p,
        };

        final baseMaterialSummary = _getBaseMaterialSummary(customizations, productsMap);

        return Card(
          margin: const EdgeInsets.only(top: 12),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),

                  InfoRow(Icons.person, 'Customer', c.customerName ?? '-'),
                  InfoRow(Icons.phone, 'Phone Number', c.customerPhone ?? '-'),
                  InfoRow(Icons.branding_watermark_outlined, 'Brand Name', c.brandName ?? '-'),
                  InfoRow(Icons.calendar_today, 'Order Date', _fmtDate(c.orderDate)),
                  InfoRow(Icons.local_shipping, 'Shipping Date', _fmtDate(c.shippingDate)),

                  const SizedBox(height: 16),
                  const Text('Products',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  if (products.isEmpty)
                    const Text('No products added.', style: TextStyle(color: Colors.grey))
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: products
                            .map((p) => ProductTile(
                                  product: p,
                                  customizations: customizations[p['productId']] ?? [],
                                ))
                            .toList(),
                      ),
                    ),

                  const SizedBox(height: 20),

                  /// 🔹 Base Material Summary Section
                  if (baseMaterialSummary.isNotEmpty) ...[
                    const Text('Focus & Temple Summary by Base Material',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: baseMaterialSummary.entries.map((baseEntry) {
                          final base = baseEntry.key;
                          final productEntries = baseEntry.value;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(base,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 4),
                                ...productEntries.entries.map((productEntry) {
                                  final productName = productEntry.key;
                                  final focus = productEntry.value['focus'] ?? 0;
                                  final temple = productEntry.value['temple'] ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            flex: 3,
                                            child: Text(productName,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Focus: $focus',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 13))),
                                        Expanded(
                                            flex: 2,
                                            child: Text('Temple: $temple',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 13))),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(thickness: 0.5),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () => c.generateOrderPdf(context, shareInstead: true),
                    icon: const Icon(Icons.share),
                    label: const Text('Share PDF'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$label: $value', style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
}

class ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> customizations;
  const ProductTile({super.key, required this.product, required this.customizations});

  @override
  Widget build(BuildContext context) {
    final qty = product['quantity'] ?? 0;
    final price = product['price'] ?? 0.0;
    final total = (qty * price).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 4,
              child: Text(product['productName'] ?? '-',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            Expanded(
              flex: 2,
              child: Text('Qty: $qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text('₹$price',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text('₹$total',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
          ],
        ),

        // 🔸 Color Customizations Section
        if (customizations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Color Customizations',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text('🎯 Focus Color',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13))),
                        Expanded(
                            child: Text('🏛 Temple Color',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...customizations.map((c) => CustomizationTile(c: c)),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

class CustomizationTile extends StatelessWidget {
  final Map<String, dynamic> c;
  const CustomizationTile({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final focusColor = c['focusColor'] ?? '-';
    final focusQty = c['focusQty'] ?? 0;
    final templeColor = c['templeColor'] ?? '-';
    final templeQty = c['templeQty'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text('$focusColor (x$focusQty)',
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              child: Text('$templeColor (x$templeQty)',
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
