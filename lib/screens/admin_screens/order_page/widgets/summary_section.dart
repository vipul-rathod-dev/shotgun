import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  double getTotal(AddOrderController controller) {
    return controller.products.fold<double>(
      0,
      (sum, p) => sum + ((p['price'] ?? 0) * (p['quantity'] ?? 0)),
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AddOrderController>(
      builder: (context, controller, _) {
        final total = getTotal(controller);
        final products = controller.products;
        final customizations = controller.productCustomizations;

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

                  _buildInfoRow(
                    Icons.person,
                    'Customer',
                    controller.customerName ?? '-',
                  ),
                  _buildInfoRow(
                    Icons.phone,
                    'Phone Number',
                    controller.customerPhone ?? '-',
                  ),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Order Date',
                    formatDate(controller.orderDate),
                  ),
                  _buildInfoRow(
                    Icons.local_shipping,
                    'Shipping Date',
                    formatDate(controller.shippingDate),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  if (products.isEmpty)
                    const Text(
                      'No products added.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children:
                            products.map((p) {
                              final qty = p['quantity'] ?? 0;
                              final price = p['price'] ?? 0.0;
                              final lineTotal = (qty * price).toStringAsFixed(
                                2,
                              );
                              final productId = p['productId'];
                              final productCustoms =
                                  customizations[productId] ?? [];

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 6,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      Colors
                                          .blue
                                          .shade50, // 🔹 Highlight product row
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🔹 Product row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            p['productName'] ?? '-',
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
                                            '₹$lineTotal',
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

                                    // 🔸 Color Customization Section
                                    if (productCustoms.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Color Customizations',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            ...productCustoms.map((c) {
                                              final color =
                                                  c['colorName'] ?? '-';
                                              final colorQty =
                                                  c['colorQty'] ?? 0;
                                              final temple =
                                                  c['templeName'] ?? '-';
                                              final templeQty =
                                                  c['templeQty'] ?? 0;

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '🎨 $color (x$colorQty)',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        '🏛 $temple (x$templeQty)',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 💰 Grand Total
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

                  // ✅ Submit Button
                  ElevatedButton.icon(
                    onPressed: () => controller.generateOrderPdf(context),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Export PDF'),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
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
}
