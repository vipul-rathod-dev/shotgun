import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_orders_page/controllers/add_order_controller.dart';
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
  List<Map<String, dynamic>> _colorTemplates = [];

  bool _isLoading = true;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchData().then((_) {
      _applyDefaultTemplates();  // ⭐ after data is fetched
    });
  }

  Future<void> _fetchData() async {
    if (_dataLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null) throw Exception('No cached company ID found.');

      // Fetch Focus Colors
      final colorSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('focus_colors')
          .orderBy('name')
          .get();

      // Fetch Temple Colors
      final templeSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('temple_colors')
          .orderBy('name')
          .get();

      // Fetch Templates
      final templateSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('color_templates')
          .orderBy('name')
          .get();

      setState(() {
        if (!mounted) return;

        _availableColors = colorSnapshot.docs.map((d) => {
          'id': d.id,
          'name': d['name'] ?? 'Unnamed',
          'focusBaseMaterial': d['focusBaseMaterial']
        }).toList();

        _availableTemples = templeSnapshot.docs.map((d) => {
          'id': d.id,
          'name': d['name'] ?? 'Unnamed',
          'templeBaseMaterial': d['templeBaseMaterial']
        }).toList();

        _colorTemplates = templateSnapshot.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'name': data['name'] ?? 'Unnamed Template',
            'productCustomizations': data['productCustomizations'] ?? {},
          };
        }).toList();

        _isLoading = false;
        _dataLoaded = true;
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

  void _applyDefaultTemplates() {
    if (!mounted) return;  // REQUIRED

    final ctrl = widget.controller;

    final templateMap = {
      'Gents': ctrl.gentsDefaultTemplate,
      'Ladies': ctrl.ladiesDefaultTemplate,
      'Baby': ctrl.babyDefaultTemplate,
    };

    templateMap.forEach((gender, templateId) {
      if (templateId == null) return;

      final template = _colorTemplates.firstWhere(
        (t) => t['id'] == templateId,
        orElse: () => {},
      );

      if (template.isEmpty) return;

      final genderKey = gender.toLowerCase();
      final customList = template['productCustomizations'][genderKey];

      if (customList == null) return;

      for (final c in customList) {
        widget.controller.addCustomization(gender, {
          'focusColorId': c['focusColorId'],
          'focusColor': c['focusColor'],
          'focusQty': c['focusQty'],
          'focusBaseMaterial': c['focusBaseMaterial'],
          'templeColorId': c['templeColorId'],
          'templeColor': c['templeColor'],
          'templeQty': c['templeQty'],
          'templeBaseMaterial': c['templeBaseMaterial'],
        });
      }
    });

    if (!mounted) return;  
    setState(() {});  // SAFE REFRESH
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

    /// Group products by gender
    final groupedProducts = <String, List<Map<String, dynamic>>>{};
    for (final product in products) {
      final gender = product['modelGender'] ?? 'Unknown';
      groupedProducts.putIfAbsent(gender, () => []).add(product);
    }

    return Form(
      key: widget.controller.formKeys[3],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groupedProducts.entries.map((entry) {
          final gender = entry.key;
          final entries = customizations[gender] ?? [];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Gender Title
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    gender,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),

                /// Customization Cards
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
                                /// Focus Row
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: SearchableDropdown(
                                        labelText: 'Focus Color',
                                        keyName: 'name',
                                        items: _availableColors,
                                        value: _availableColors.firstWhere(
                                          (color) =>
                                              color['id'] ==
                                              (data['focusColorId'] ?? ''),
                                          orElse: () => {},
                                        ),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          if (!mounted) return;

                                          setState(() {
                                            data['focusColorId'] = value['id'];
                                            data['focusColor'] = value['name'];
                                            data['focusBaseMaterial'] = value['focusBaseMaterial'];
                                          });

                                          widget.controller.updateCustomization(gender, index, data);
                                        },

                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    Flexible(
                                      flex: 1,
                                      child: TextFormField(
                                        initialValue:
                                            data['focusQty']?.toString() ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
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
                                          final newQty = int.tryParse(value) ?? 0;

                                          if (!mounted) return;
                                          setState(() => data['focusQty'] = newQty);

                                          widget.controller.updateCustomization(gender, index, data);
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                /// Temple Row
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: SearchableDropdown(
                                        labelText: 'Temple Color',
                                        keyName: 'name',
                                        items: _availableTemples,
                                        value: _availableTemples.firstWhere(
                                          (temple) =>
                                              temple['id'] ==
                                              (data['templeColorId'] ?? ''),
                                          orElse: () => {},
                                        ),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          if (!mounted) return;
                                          setState(() {
                                            data['templeColorId'] = value['id'];
                                            data['templeColor'] =
                                                value['name'];
                                            data['templeBaseMaterial'] =
                                                value['templeBaseMaterial'];
                                          });
                                          widget.controller.updateCustomization(
                                              gender, index, data);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    Flexible(
                                      flex: 1,
                                      child: TextFormField(
                                        initialValue:
                                            data['templeQty']?.toString() ?? '',
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
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
                                          if (!mounted) return;
                                          setState(() =>
                                              data['templeQty'] = newQty);
                                          widget.controller.updateCustomization(
                                              gender, index, data);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// Delete Button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                widget.controller
                                    .removeCustomization(gender, index);
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                /// Add Option Button
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Option'),
                  onPressed: () {
                    setState(() {
                      widget.controller.addCustomization(gender, {
                        'focusColorId': null,
                        'focusColor': '',
                        'focusQty': 0,
                        'focusBaseMaterial': '',
                        'templeColorId': null,
                        'templeColor': '',
                        'templeQty': 0,
                        'templeBaseMaterial': '',
                      });
                    });
                  },
                ),

                /// Inline Template Dropdown
                if (_colorTemplates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 12),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Add From Template',
                        border: OutlineInputBorder(),
                      ),
                      items: _colorTemplates.map((tpl) {
                        return DropdownMenuItem(
                          value: tpl,
                          child: Text(tpl['name']),
                        );
                      }).toList(),
                      onChanged: (selected) {
                        if (selected == null) return;

                        setState(() {
                          print(selected['productCustomizations'][gender.toLowerCase()]);
                          final customizationsForGender = selected['productCustomizations'][gender.toLowerCase()];
                          customizationsForGender.forEach((selected) => {
                            widget.controller.addCustomization(gender, {
                              'focusColorId': selected['focusColorId'],
                              'focusColor': selected['focusColor'],
                              'focusQty': selected['focusQty'],
                              'focusBaseMaterial':
                                  selected['focusBaseMaterial'],

                              'templeColorId': selected['templeColorId'],
                              'templeColor': selected['templeColor'],
                              'templeQty': selected['templeQty'],
                              'templeBaseMaterial':
                                  selected['templeBaseMaterial'],
                            })
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
