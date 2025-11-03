import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TaskDetailsPage extends StatefulWidget {
  final String companyId;
  final String taskId;

  const TaskDetailsPage({
    super.key,
    required this.companyId,
    required this.taskId,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Map<String, Map<String, Map<String, int>>> productMaterialSummary = {};

  Future<void> _calculateMaterialSummary(List productDetails) async {
    final productTotals = <String, Map<String, Map<String, int>>>{};

    for (final p in productDetails) {
      final productId = p['productId'] ?? 'Unknown Product';
      final customizations = (p['customizations'] as List?) ?? [];

      final materialTotals = <String, Map<String, int>>{
        'Black': {'focus': 0, 'temple': 0},
        'Clear': {'focus': 0, 'temple': 0},
      };

      for (final c in customizations) {
        final customization = Map<String, dynamic>.from(c);

        final focusMaterial =
            customization['focusBaseMaterial']?.toString() ?? 'Unknown';
        final templeMaterial =
            customization['templeBaseMaterial']?.toString() ?? 'Unknown';

        materialTotals.putIfAbsent(focusMaterial, () => {'focus': 0, 'temple': 0});
        materialTotals.putIfAbsent(templeMaterial, () => {'focus': 0, 'temple': 0});

        materialTotals[focusMaterial]!['focus'] =
            (materialTotals[focusMaterial]!['focus'] ?? 0) +
                ((customization['focusQty'] ?? 0) as num).toInt();

        materialTotals[templeMaterial]!['temple'] =
            (materialTotals[templeMaterial]!['temple'] ?? 0) +
                ((customization['templeQty'] ?? 0) as num).toInt();
      }

      productTotals[productId] = materialTotals;
    }

    setState(() => productMaterialSummary = productTotals);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('tasks')
            .doc(widget.taskId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Task not found.'));
          }

          final task = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final status = task['status'] ?? 'Pending';
          final productDetails = task['productDetails'] as List? ?? [];

          if (productMaterialSummary.isEmpty && productDetails.isNotEmpty) {
            _calculateMaterialSummary(productDetails);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      task['brandName'] ?? 'No Brand',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Order Type: ${task['orderType'] ?? 'N/A'}'),
                    trailing: Chip(
                      label: Text(status),
                      backgroundColor: _statusColor(status),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const Text(
                  'Product Details',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),

                if (productDetails.isEmpty)
                  const Text('No product details available.')
                else
                  ...productDetails.map((p) {
                    final product = Map<String, dynamic>.from(p);
                    final productId = product['productId'] ?? '';
                    // final customizations = (product['customizations'] as List?) ?? [];

                    final materialData = productMaterialSummary[productId] ?? {};

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              product['productName'] ?? 'Unnamed Product',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Qty: ${product['quantity'] ?? 'N/A'}',
                              style:
                                  const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.all(12),
                        children: [
                          // const Text(
                          //   'Customizations:',
                          //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          // ),
                          // const SizedBox(height: 8),

                          // if (customizations.isEmpty)
                          //   const Text('No customizations available.')
                          // else
                          //   SingleChildScrollView(
                          //     scrollDirection: Axis.horizontal,
                          //     child: DataTable(
                          //       headingRowColor: MaterialStateProperty.all<Color>(
                          //         colorScheme.primary.withOpacity(0.1),
                          //       ),
                          //       border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                          //       columns: const [
                          //         DataColumn(label: Text('Focus Color')),
                          //         DataColumn(label: Text('Focus Qty')),
                          //         DataColumn(label: Text('Temple Color')),
                          //         DataColumn(label: Text('Temple Qty')),
                          //       ],
                          //       rows: customizations.map((c) {
                          //         final customization = Map<String, dynamic>.from(c);
                          //         return DataRow(
                          //           cells: [
                          //             DataCell(Text(customization['focusColor'] ?? 'N/A')),
                          //             DataCell(Text('${customization['focusQty'] ?? 0}')),
                          //             DataCell(Text(customization['templeColor'] ?? 'N/A')),
                          //             DataCell(Text('${customization['templeQty'] ?? 0}')),
                          //           ],
                          //         );
                          //       }).toList(),
                          //     ),
                          //   ),

                          // const SizedBox(height: 12),
                          const Text(
                            'Material Summary (for this product):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 8),

                          if (materialData.isEmpty)
                            const Text('Calculating...')
                          else
                            DataTable(
                              headingRowColor: MaterialStateProperty.all<Color>(
                                colorScheme.primary.withOpacity(0.1),
                              ),
                              border: TableBorder.all(color: Colors.grey.shade300),
                              columns: const [
                                DataColumn(label: Text('Material')),
                                DataColumn(label: Text('Focus Total')),
                                DataColumn(label: Text('Temple Total')),
                              ],
                              rows: materialData.entries.map((entry) {
                                final material = entry.key;
                                final focus = entry.value['focus'] ?? 0;
                                final temple = entry.value['temple'] ?? 0;
                                return DataRow(cells: [
                                  DataCell(Text(material)),
                                  DataCell(Text(focus.toString())),
                                  DataCell(Text(temple.toString())),
                                ]);
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 30),
                Center(child: _buildActionButton(context, widget.companyId, widget.taskId, status)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String companyId, String taskId, String status) {
    if (status.toLowerCase() == 'completed') {
      return const Text('✅ Task Completed',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16));
    }

    final nextStatus = status.toLowerCase() == 'pending' ? 'In Progress' : 'Completed';
    final buttonText =
        status.toLowerCase() == 'pending' ? 'Start Task' : 'Mark as Done';
    final buttonColor =
        status.toLowerCase() == 'pending' ? Colors.orange : Colors.green;

    return ElevatedButton.icon(
      icon: Icon(
        status.toLowerCase() == 'pending'
            ? Icons.play_circle_fill
            : Icons.check_circle,
      ),
      label: Text(buttonText),
      onPressed: () async {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('tasks')
            .doc(taskId)
            .update({
          'status': nextStatus,
          '${nextStatus.toLowerCase()}At': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task marked as $nextStatus'),
            backgroundColor: buttonColor,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
