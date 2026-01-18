import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  double _getTotal(AddOrderController c) =>
      c.products.fold<double>(0, (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)));

  String _fmtDate(DateTime? date) =>
      date == null ? '-' : DateFormat('dd MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return Consumer<AddOrderController>(
      builder: (context, c, _) {
        final total = _getTotal(c);
        final products = c.products;
        final customizations = c.productCustomizations;
        final boxQuantity = c.boxQuantity;

        // 🔹 Group products by gender
        final Map<String, List<Map<String, dynamic>>> genderGroups = {};
        for (final p in products) {
          final gender = (p['modelGender'] ?? 'Unknown').toString();
          genderGroups.putIfAbsent(gender, () => []);
          genderGroups[gender]!.add(p);
        }

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
                  const Text('Products by Gender',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  if (products.isEmpty)
                    const Text('No products added.', style: TextStyle(color: Colors.grey))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: genderGroups.entries.map((entry) {
                        final gender = entry.key;
                        final productList = entry.value;
                        final genderCustomizations = customizations[gender] ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                              child: Text(
                                gender,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: productList
                                    .map((p) => ProductTile(
                                          product: p,
                                          customizations: genderCustomizations,
                                          boxQuantity: boxQuantity,
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

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
                    onPressed: () => c.generateOrderPdf1(context, shareInstead: true),
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
  final Map<String, int> boxQuantity;

  const ProductTile({
    super.key,
    required this.product,
    required this.customizations,
    required this.boxQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final qty = (product['quantity'] ?? 0) as int;
    final price = (product['price'] ?? 0).toDouble();
    final total = (qty * price).toStringAsFixed(2);

    final gender = product['modelGender'] ?? 'Unknown';
    final genderBoxQty = (boxQuantity[gender] ?? 0);

    // prevent divide-by-zero
    final ratio = genderBoxQty > 0 ? (qty / genderBoxQty) : 0.0;

    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  product['productName'] ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Qty: $qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹$price',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹$total',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),

          // 🔸 Gender-level Color Customizations
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
                    // 🔥 Focus & Temple Base Material totals (Black / Clear / PC)
                    if (customizations.isNotEmpty)
                      Builder(builder: (_) {
                        double focusBlack = 0, focusClear = 0, focusPC = 0;
                        double templeBlack = 0, templeClear = 0, templePC = 0;

                        for (final c in customizations) {
                          // --- FOCUS MATERIAL ---
                          final focusMaterial = c['focusBaseMaterial'] ?? '';
                          final focusBaseQty = (c['focusQty'] ?? 0).toDouble();
                          final focusComputed = focusBaseQty * ratio;

                          if (focusMaterial == 'Black') focusBlack += focusComputed;
                          if (focusMaterial == 'Clear') focusClear += focusComputed;
                          if (focusMaterial == 'PC') focusPC += focusComputed;

                          // --- TEMPLE MATERIAL ---
                          final templeMaterial = c['templeBaseMaterial'] ?? '';
                          final templeBaseQty = (c['templeQty'] ?? 0).toDouble();
                          final templeComputed = templeBaseQty * ratio;

                          if (templeMaterial == 'Black') templeBlack += templeComputed;
                          if (templeMaterial == 'Clear') templeClear += templeComputed;
                          if (templeMaterial == 'PC') templePC += templeComputed;
                        }

                        final showFocus = focusBlack > 0 || focusClear > 0 || focusPC > 0;
                        final showTemple = templeBlack > 0 || templeClear > 0 || templePC > 0;

                        return Column(
                          children: [
                            // ---------------- FOCUS MATERIAL TOTALS ----------------
                            if (showFocus)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Focus Black: ${focusBlack.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Focus Clear: ${focusClear.toStringAsFixed(1)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Focus PC: ${focusPC.toStringAsFixed(1)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ---------------- TEMPLE MATERIAL TOTALS ----------------
                            if (showTemple)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Temple Black: ${templeBlack.toStringAsFixed(1)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Temple Clear: ${templeClear.toStringAsFixed(1)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Temple PC: ${templePC.toStringAsFixed(1)}',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      }),


                    const Text(
                      'Color Customizations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
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
                            child: Text(
                              '🎯 Focus Color',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '🏛 Temple Color',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...customizations.map(
                      (c) => CustomizationTile(
                        c: c,
                        ratio: ratio,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CustomizationTile extends StatelessWidget {
  final Map<String, dynamic> c;
  final double ratio;

  const CustomizationTile({
    super.key,
    required this.c,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final focusColor = c['focusColor'] ?? '-';
    final focusQty = ((c['focusQty'] ?? 0) * ratio).toStringAsFixed(1);
    final templeColor = c['templeColor'] ?? '-';
    final templeQty = ((c['templeQty'] ?? 0) * ratio).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$focusColor = $focusQty',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '$templeColor = $templeQty',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
