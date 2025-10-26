import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/controllers/add_order_controller.dart';

class ColorTempleRequirements extends StatefulWidget {
  final AddOrderController controller;

  const ColorTempleRequirements({super.key, required this.controller});

  @override
  State<ColorTempleRequirements> createState() => _ColorTempleRequirementsState();
}

class _ColorTempleRequirementsState extends State<ColorTempleRequirements> {
  List<Map<String, dynamic>> _availableColors = [];
  List<Map<String, dynamic>> _availableTemples = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// 🔹 Fetch colors and temples from Firestore
  Future<void> _fetchData() async {
    try {
      final colorSnapshot =
          await FirebaseFirestore.instance.collection('focus_colors').orderBy('name').get();
      final templeSnapshot =
          await FirebaseFirestore.instance.collection('temple_colors').orderBy('name').get();

      setState(() {
        _availableColors = colorSnapshot.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed'})
            .toList();
        _availableTemples = templeSnapshot.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed'})
            .toList();
        _isLoading = false;
      });

      setState(() {});
    } catch (e) {
      debugPrint('⚠️ Failed to load colors or temples: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading colors/temples')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.controller.products;
    final customizations = widget.controller.productCustomizations;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return const Center(
        child: Text(
          'Please add products first before customizing.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Form(
      key: widget.controller.formKeys[3],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: products.map((product) {
          final productId = product['productId'];
          final entries = customizations[productId] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['productName'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              ...entries.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;

                final selectedColorId = _availableColors.any((c) => c['id'] == data['focusColorId'])
                    ? data['focusColorId']
                    : null;
                final selectedTempleId = _availableTemples.any((t) => t['id'] == data['templeColorId'])
                    ? data['templeColorId']
                    : null;


                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                /// 🎨 Color Dropdown
                                Flexible(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: selectedColorId,
                                    decoration: const InputDecoration(labelText: 'Color'),
                                    items: _availableColors.map((color) {
                                      return DropdownMenuItem<String>(
                                        value: color['id'],
                                        child: Text(color['name']),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        data['focusColorId'] = value;
                                        data['focusColor'] = _availableColors
                                            .firstWhere((c) => c['id'] == value)['name'];
                                      });
                                      widget.controller.updateCustomization(productId, index, data);
                                    },
                                    validator: (value) =>
                                        value == null ? 'Select color' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                /// 🎨 Color Qty
                                Flexible(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: data['focusQty']?.toString(),
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      final n = int.tryParse(v);
                                      if (n == null || n <= 0) return 'Invalid qty';
                                      return null;
                                    },
                                    onChanged: (value) {
                                      final newQty = int.tryParse(value) ?? 0;
                                      setState(() {
                                        data['focusQty'] = newQty;
                                      });
                                      widget.controller.updateCustomization(productId, index, data);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                /// 🏛 Temple Dropdown
                                Flexible(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: selectedTempleId,
                                    decoration: const InputDecoration(labelText: 'Temple'),
                                    items: _availableTemples.map((temple) {
                                      return DropdownMenuItem<String>(
                                        value: temple['id'],
                                        child: Text(temple['name']),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        data['templeColorId'] = value;
                                        data['templeColor'] = _availableTemples
                                            .firstWhere((t) => t['id'] == value)['name'];
                                      });
                                      widget.controller.updateCustomization(productId, index, data);
                                    },
                                    validator: (value) =>
                                        value == null ? 'Select temple' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                /// 🏛 Temple Qty
                                Flexible(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: data['templeQty']?.toString(),
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      final n = int.tryParse(v);
                                      if (n == null || n <= 0) return 'Invalid qty';
                                      return null;
                                    },
                                    onChanged: (value) {
                                      final newQty = int.tryParse(value) ?? 0;
                                      setState(() {
                                        data['templeQty'] = newQty;
                                      });
                                      widget.controller.updateCustomization(productId, index, data);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      /// ❌ Remove Button
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              widget.controller.removeCustomization(productId, index);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),

              /// ➕ Add Option Button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                  onPressed: () {
                    setState(() {
                      widget.controller.addCustomization(productId, {
                        'focusColorId': null,
                        'focusColor': '',
                        'focusQty': 0,
                        'templeColorId': null,
                        'templeColor': '',
                        'templeQty': 0,
                      });
                    });
                  },
                ),
              ),
              const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }
}
