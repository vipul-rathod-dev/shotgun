import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';

class ColorTempleRequirements extends StatefulWidget {
  final AddOrderController controller;

  const ColorTempleRequirements({super.key, required this.controller});

  @override
  State<ColorTempleRequirements> createState() =>
      _ColorTempleRequirementsState();
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

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null) throw Exception('No cached company ID found.');

      final colorSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('focus_colors')
          .orderBy('name')
          .get();

      final templeSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('temple_colors')
          .orderBy('name')
          .get();

      setState(() {
        _availableColors = colorSnapshot.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed', 'focusBaseMaterial': d['focusBaseMaterial']})
            .toList();

        _availableTemples = templeSnapshot.docs
            .map((d) => {'id': d.id, 'name': d['name'] ?? 'Unnamed', 'templeBaseMaterial': d['templeBaseMaterial']})
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading focus or temple colors')),
        );
      }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: products.map((product) {
          final productId = product['productId'];
          final entries = customizations[productId] ?? [];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🏷 Product Title
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    product['productName'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),

                /// 🎨 Customization Cards
                ...entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Stack(
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                /// 🎯 Focus Color Row
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: SearchableDropdown(
                                        labelText: 'Focus Color',
                                        keyName: 'name',
                                        items: _availableColors,
                                        // value: customizations[productId]!.isNotEmpty ? customizations[productId]![index] : null,
                                        value: _availableColors.firstWhere(
                                          (color) =>
                                              color['id'] ==
                                              (customizations[productId]![index]['focusColorId'] ?? ''),
                                          orElse: () => {},
                                        ),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            data['focusColorId'] = value['id'];
                                            data['focusColor'] = value['name'];
                                            data['focusBaseMaterial'] = value['focusBaseMaterial'];
                                          });
                                          widget.controller.updateCustomization(
                                              productId, index, data);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    /// 🎯 Focus Qty
                                    Flexible(
                                      flex: 1,
                                      child: TextFormField(
                                        initialValue:
                                            data['focusQty']?.toString() ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Req';
                                          }
                                          final n = int.tryParse(v);
                                          if (n == null || n <= 0) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          final newQty =
                                              int.tryParse(value) ?? 0;
                                          setState(() =>
                                              data['focusQty'] = newQty);
                                          widget.controller.updateCustomization(
                                              productId, index, data);
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                /// 🏛 Temple Color Row
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: SearchableDropdown(
                                        labelText: 'Temple Color',
                                        keyName: 'name',
                                        items: _availableTemples,
                                        // value: data,
                                        value: _availableTemples.firstWhere(
                                          (temple) =>
                                              temple['id'] ==
                                              (customizations[productId]![index]['templeColorId'] ?? ''),
                                          orElse: () => {},
                                        ),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            data['templeColorId'] = value['id'];
                                            data['templeColor'] = value['name'];
                                            data['templeBaseMaterial'] = value['templeBaseMaterial'];
                                          });
                                          widget.controller.updateCustomization(
                                              productId, index, data);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    /// 🏛 Temple Qty
                                    Flexible(
                                      flex: 1,
                                      child: TextFormField(
                                        initialValue:
                                            data['templeQty']?.toString() ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Req';
                                          }
                                          final n = int.tryParse(v);
                                          if (n == null || n <= 0) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          final newQty =
                                              int.tryParse(value) ?? 0;
                                          setState(() =>
                                              data['templeQty'] = newQty);
                                          widget.controller.updateCustomization(
                                              productId, index, data);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// ❌ Remove Button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  widget.controller
                                      .removeCustomization(productId, index);
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.redAccent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                /// ➕ Add Option Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Add Option',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      setState(() {
                        widget.controller.addCustomization(productId, {
                          'focusColorId': null,
                          'focusColor': '',
                          'focusQty': 0,
                          'focusBaseMaterial': '',
                          'templeColorId': null,
                          'templeColor': '',
                          'templeQty': 0,
                          'templeBaseMaterial': ''
                        });
                      });
                    },
                  ),
                ),

                const Divider(thickness: 1),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
