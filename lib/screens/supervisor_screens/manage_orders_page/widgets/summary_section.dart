import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  double _getTotal(AddOrderController c) => c.products.fold<double>(
    0,
    (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)),
  );

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

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Order Summary',

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const Divider(height: 24),

                  InfoRow(Icons.person, 'Customer', c.customerName ?? '-'),

                  InfoRow(Icons.phone, 'Phone Number', c.customerPhone ?? '-'),

                  InfoRow(
                    Icons.branding_watermark_outlined,
                    'Brand Name',
                    c.brandName ?? '-',
                  ),

                  InfoRow(
                    Icons.calendar_today,
                    'Order Date',
                    _fmtDate(c.orderDate),
                  ),

                  InfoRow(
                    Icons.local_shipping,
                    'Shipping Date',
                    _fmtDate(c.shippingDate),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Products by Gender',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 8),

                  if (products.isEmpty)
                    const Text(
                      'No products added.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children:
                          genderGroups.entries.map((entry) {
                            final gender = entry.key;

                            final productList = entry.value;

                            final genderCustomizations =
                                customizations[gender] ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                    horizontal: 4.0,
                                  ),

                                  child: Text(
                                    gender,

                                    style: const TextStyle(
                                      fontSize: 15,

                                      fontWeight: FontWeight.bold,

                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),

                                    borderRadius: BorderRadius.circular(8),
                                  ),

                                  child: Column(
                                    children:
                                        productList
                                            .map(
                                              (p) => ProductTile(
                                                product: p,

                                                customizations:
                                                    genderCustomizations,

                                                boxQuantity: boxQuantity,
                                                isCustomized:
                                                    c.orderType == 'Customized',
                                              ),
                                            )
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
                      const Text(
                        'Grand Total:',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      Text(
                        '₹${total.toStringAsFixed(2)}',

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed:
                        () => c.generateOrderPdf1(context, shareInstead: true),

                    icon: const Icon(Icons.share),

                    label: const Text('Share PDF'),

                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
  final bool isCustomized;

  const ProductTile({
    super.key,

    required this.product,

    required this.customizations,

    required this.boxQuantity,
    required this.isCustomized,
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

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Expanded(
                flex: 2,

                child: Text(
                  '₹$price',

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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

                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(8),

                  border: Border.all(color: Colors.grey.shade300),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // For customized orders, show the actual raw models linked
                    // to this finished product and the required variant quantities.
                    if (isCustomized)
                      _CustomizedRawMaterialSummary(
                        product: product,
                        customizations: customizations,
                        ratio: ratio,
                      )
                    else
                      _StandardMaterialSummary(
                        customizations: customizations,
                        ratio: ratio,
                      ),

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
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),

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
                      (c) => CustomizationTile(c: c, ratio: ratio),
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

class _CustomizedRawMaterialSummary extends StatelessWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> customizations;
  final double ratio;

  const _CustomizedRawMaterialSummary({
    required this.product,
    required this.customizations,
    required this.ratio,
  });

  String _rawModelName(String component) {
    final keys =
        component == 'Focus'
            ? ['rawFocusModelName', 'rawFocusName']
            : ['rawTempleModelName', 'rawTempleName'];

    for (final key in keys) {
      final value = (product[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Raw $component model not selected';
  }

  Widget _componentCard({
    required String component,
    required String modelName,
    required Map<String, double> quantities,
  }) {
    final visible = quantities.entries.where((e) => e.value > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$component • $modelName',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children:
                visible
                    .map(
                      (e) => Text(
                        '${e.key}: ${e.value.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = <String, double>{'Black': 0, 'Clear': 0, 'PC': 0};
    final temple = <String, double>{'Black': 0, 'Clear': 0, 'PC': 0};

    for (final customization in customizations) {
      final focusMaterial =
          (customization['focusBaseMaterial'] ?? '').toString();
      final focusQty = (customization['focusQty'] ?? 0).toDouble() * ratio;
      if (focus.containsKey(focusMaterial)) {
        focus[focusMaterial] = focus[focusMaterial]! + focusQty;
      }

      final templeMaterial =
          (customization['templeBaseMaterial'] ?? '').toString();
      final templeQty = (customization['templeQty'] ?? 0).toDouble() * ratio;
      if (temple.containsKey(templeMaterial)) {
        temple[templeMaterial] = temple[templeMaterial]! + templeQty;
      }
    }

    final hasFocus = focus.values.any((value) => value > 0);
    final hasTemple = temple.values.any((value) => value > 0);
    if (!hasFocus && !hasTemple) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Raw Products Required',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (hasFocus)
          _componentCard(
            component: 'Raw Focus',
            modelName: _rawModelName('Focus'),
            quantities: focus,
          ),
        if (hasTemple)
          _componentCard(
            component: 'Raw Temple',
            modelName: _rawModelName('Temple'),
            quantities: temple,
          ),
      ],
    );
  }
}

class _StandardMaterialSummary extends StatelessWidget {
  final List<Map<String, dynamic>> customizations;
  final double ratio;

  const _StandardMaterialSummary({
    required this.customizations,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    double focusBlack = 0, focusClear = 0, focusPC = 0;
    double templeBlack = 0, templeClear = 0, templePC = 0;

    for (final c in customizations) {
      final focusMaterial = c['focusBaseMaterial'] ?? '';
      final focusQty = (c['focusQty'] ?? 0).toDouble() * ratio;
      if (focusMaterial == 'Black') focusBlack += focusQty;
      if (focusMaterial == 'Clear') focusClear += focusQty;
      if (focusMaterial == 'PC') focusPC += focusQty;

      final templeMaterial = c['templeBaseMaterial'] ?? '';
      final templeQty = (c['templeQty'] ?? 0).toDouble() * ratio;
      if (templeMaterial == 'Black') templeBlack += templeQty;
      if (templeMaterial == 'Clear') templeClear += templeQty;
      if (templeMaterial == 'PC') templePC += templeQty;
    }

    final showFocus = focusBlack > 0 || focusClear > 0 || focusPC > 0;
    final showTemple = templeBlack > 0 || templeClear > 0 || templePC > 0;
    if (!showFocus && !showTemple) return const SizedBox.shrink();

    Widget line(String label, double black, double clear, double pc) {
      final values = <String>[
        if (black > 0) 'Black: ${black.toStringAsFixed(1)}',
        if (clear > 0) 'Clear: ${clear.toStringAsFixed(1)}',
        if (pc > 0) 'PC: ${pc.toStringAsFixed(1)}',
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '$label  ${values.join('   ')}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFocus) line('Focus', focusBlack, focusClear, focusPC),
          if (showTemple) line('Temple', templeBlack, templeClear, templePC),
        ],
      ),
    );
  }
}

class CustomizationTile extends StatelessWidget {
  final Map<String, dynamic> c;

  final double ratio;

  const CustomizationTile({super.key, required this.c, required this.ratio});

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
