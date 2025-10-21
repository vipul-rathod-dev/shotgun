import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:shotgun/widgets/custom_textfield.dart';
import 'package:shotgun/widgets/date_picker_field.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class AddOrdersPage extends StatefulWidget {
  const AddOrdersPage({super.key});

  @override
  State<AddOrdersPage> createState() => _AddOrdersPageState();
}

class _AddOrdersPageState extends State<AddOrdersPage> {
  final _formKey = GlobalKey<FormState>();

  // Stepper State
  int _currentStep = 0;

  // Form Data
  final TextEditingController _customerNameController = TextEditingController();
  DateTime? _orderDate;
  DateTime? _shippingDate;
  List<Map<String, dynamic>> _productSelections = [];
  bool _isSubmitting = false;

  // Step 3: Color requirement (keyed by productId)
  Map<String, List<Map<String, dynamic>>> _productCustomizations = {};

  List<Map<String, dynamic>> _availableColors = [];
  List<Map<String, dynamic>> _availableTemples = [];

  @override
  void initState() {
    super.initState();
    _loadColorsAndTemples();
  }

  Future<void> _loadColorsAndTemples() async {
    final colorsSnapshot = await FirebaseFirestore.instance.collection('focus_colors').get();
    final templesSnapshot = await FirebaseFirestore.instance.collection('temple_colors').get();

    setState(() {
      _availableColors = colorsSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
      }).toList();

      _availableTemples = templesSnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
      }).toList();
    });
  }


  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  Future<int> _getNextOrderNumber() async {
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('orders');
    return FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'lastOrderNumber': 1000});
        return 1001;
      }
      final current = snapshot.get('lastOrderNumber') as int;
      final next = current + 1;
      transaction.update(counterRef, {'lastOrderNumber': next});
      return next;
    });
  }

  Future<void> _submitOrder() async {
    if (_productSelections.isEmpty || !_formKey.currentState!.validate()) return;
    if (_orderDate == null || _shippingDate == null) return;
    if (_shippingDate!.isBefore(_orderDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipping date cannot be before order date')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    try {
      final orderNumber = await _getNextOrderNumber();

      // Combine color with products
      final List<Map<String, dynamic>> finalProducts = _productSelections.map((product) {
        final productId = product['productId'];
        final customizations = _productCustomizations[productId] ?? [];

        return {
          ...product,
          'customizations': customizations,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('orders').add({
        'orderNumber': orderNumber,
        'customerName': _customerNameController.text.trim(),
        'orderDate': Timestamp.fromDate(_orderDate!),
        'shippingDate': Timestamp.fromDate(_shippingDate!),
        'products': finalProducts,
        'timestamp': FieldValue.serverTimestamp(),
        'orderStatus': 'Yet to Start',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order submitted successfully')),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit order')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _addProduct() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProductSelectorSheet(),
    );

    if (result != null) {
      if (_productSelections.any((p) => p['productId'] == result['productId'])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product already added')),
        );
      } else {
        setState(() {
          _productSelections.add(result);
        });
      }
    }
  }

  // void _shareOrderDetails() {
  //   final buffer = StringBuffer();
  //   buffer.writeln('🧾 New Order Summary');
  //   buffer.writeln('Customer: ${_customerNameController.text.trim()}');
  //   buffer.writeln('Order Date: ${_orderDate?.toIso8601String().split('T').first}');
  //   buffer.writeln('Shipping Date: ${_shippingDate?.toIso8601String().split('T').first}');
  //   buffer.writeln('\n📦 Products:');
  //   for (var product in _productSelections) {
  //     final name = product['productName'];
  //     final qty = product['quantity'];
  //     buffer.writeln('\n- $name (Qty: $qty)');
  //     final customizations = _productCustomizations[product['productId']] ?? [];
  //     for (var c in customizations) {
  //       buffer.writeln(
  //         '   • Focus Color: ${c['colorName']} (${c['colorQty']}), '
  //         'Temple Color: ${c['templeName']} (${c['templeQty']})',
  //       );
  //     }
  //   }
  //   Share.share(buffer.toString());
  // }

  Future<void> _generateOrderPdf() async {
    final pdf = pw.Document();

    final dateFormatter = (DateTime? d) =>
        d?.toIso8601String().split('T').first ?? '';

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Order Summary', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 16),

          pw.Text('Customer: ${_customerNameController.text.trim()}'),
          pw.Text('Order Date: ${dateFormatter(_orderDate)}'),
          pw.Text('Shipping Date: ${dateFormatter(_shippingDate)}'),

          pw.SizedBox(height: 16),
          pw.Text('Products:', style: pw.TextStyle(fontSize: 18)),

          ..._productSelections.map((product) {
            final customizations = _productCustomizations[product['productId']] ?? [];

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 12),
                pw.Text(
                  '${product['productName']} (Qty: ${product['quantity']})',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (customizations.isEmpty)
                  pw.Text('No customizations added.'),
                if (customizations.isNotEmpty)
                  pw.TableHelper.fromTextArray(
                    headers: ['Color', 'Color Qty', 'Temple', 'Temple Qty'],
                    data: customizations.map((c) => [
                          c['colorName'] ?? '',
                          c['colorQty']?.toString() ?? '0',
                          c['templeName'] ?? '',
                          c['templeQty']?.toString() ?? '0',
                        ]).toList(),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
              ],
            );
          }),
        ],
      ),
    );

    // Display share/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && !_formKey.currentState!.validate()) return;

          if (_currentStep == 1 && _productSelections.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one product')));
            return;
          }

          if (_currentStep < 3) {
            setState(() => _currentStep++);
          } else {
            _submitOrder();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),  // <-- Add spacing here
              Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 3 ? 'Submit' : 'Next'),
                  ),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            ],
          );
        },
        steps: [
          /// Step 1: Customer Info
          Step(
            title: const Text('Customer Details'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _customerNameController,
                    label: 'Customer Name',
                    icon: Icons.person,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter customer name' : null,
                  ),
                  const SizedBox(height: 12),
                  DatePickerField(
                    label: 'Order Date',
                    selectedDate: _orderDate,
                    onDateSelected: (date) => setState(() => _orderDate = date),
                  ),
                  const SizedBox(height: 12),
                  DatePickerField(
                    label: 'Shipping Date',
                    selectedDate: _shippingDate,
                    onDateSelected: (date) => setState(() => _shippingDate = date),
                  ),
                ],
              ),
            ),
          ),

          /// Step 2: Products
          Step(
            title: const Text('Products'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                ..._productSelections.map((item) => ListTile(
                      title: Text(item['productName']),
                      subtitle: Text('Qty: ${item['quantity']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _productSelections.remove(item);
                            _productCustomizations.remove(item['productId']);
                          });
                        },
                      ),
                    )),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            ),
          ),

          /// Step 3: Product Color Requirements
          Step(
            title: const Text('Color & Temple Requirements'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              children: _productSelections.map((product) {
                final productId = product['productId'];
                final entries = _productCustomizations[productId] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    ...entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      /// Color Dropdown
                                      Flexible(
                                        flex: 3,
                                        child: DropdownButtonFormField<String>(
                                          value: data['colorId'],
                                          decoration: const InputDecoration(labelText: 'Color'),
                                          items: _availableColors.map((color) {
                                            return DropdownMenuItem<String>(
                                              value: color['id'],
                                              child: Text(color['name']),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              data['colorId'] = value;
                                              data['colorName'] = _availableColors
                                                  .firstWhere((c) => c['id'] == value)['name'];
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      /// Color Quantity
                                      Flexible(
                                        flex: 1,
                                        // width: 60,
                                        child: TextFormField(
                                          initialValue: data['colorQty']?.toString(),
                                          decoration: const InputDecoration(labelText: 'Qty'),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              data['colorQty'] = int.tryParse(value) ?? 0;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      /// Temple Dropdown
                                      Flexible(
                                        flex: 3,
                                        child: DropdownButtonFormField<String>(
                                          value: data['templeId'],
                                          decoration: const InputDecoration(labelText: 'Temple'),
                                          items: _availableTemples.map((temple) {
                                            return DropdownMenuItem<String>(
                                              value: temple['id'],
                                              child: Text(temple['name']),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              data['templeId'] = value;
                                              data['templeName'] = _availableTemples
                                                  .firstWhere((t) => t['id'] == value)['name'];
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      /// Temple Quantity
                                      Flexible(
                                        // width: 60,
                                        flex: 1,
                                        child: TextFormField(
                                          initialValue: data['templeQty']?.toString(),
                                          decoration: const InputDecoration(labelText: 'Qty'),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              data['templeQty'] = int.tryParse(value) ?? 0;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            /// Positioned Remove Button (Top Right)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () async {
                                  final shouldRemove = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Removal'),
                                      content: const Text('Are you sure you want to remove this item?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldRemove == true) {
                                    setState(() {
                                      entries.removeAt(index);
                                    });
                                  }
                                },
                              ),
                            ),

                          ],
                        ),
                      );

                    }),

                    // + Add Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Option'),
                        onPressed: () {
                          setState(() {
                            _productCustomizations.putIfAbsent(productId, () => []).add({
                              'colorId': null,
                              'colorName': '',
                              'colorQty': 0,
                              'templeId': null,
                              'templeName': '',
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
          ),

          /// Step 4: Submit
          Step(
            title: const Text('Review & Submit'),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
            content: _isSubmitting
                ? const CircularProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer: ${_customerNameController.text.trim()}'),
                      Text('Order Date: ${_orderDate?.toIso8601String().split('T').first}'),
                      Text('Shipping Date: ${_shippingDate?.toIso8601String().split('T').first}'),
                      const SizedBox(height: 12),

                      // Share Button
                      // Align(
                      //   alignment: Alignment.centerLeft,
                      //   child: ElevatedButton.icon(
                      //     icon: const Icon(Icons.share),
                      //     label: const Text('Share Order Details'),
                      //     onPressed: _shareOrderDetails,
                      //   ),
                      // ),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                        onPressed: _generateOrderPdf,
                      ),

                      const Divider(),
                      const Text('Products:'),
                      const SizedBox(height: 8),
                      ..._productSelections.map((p) {
                        final customizations = _productCustomizations[p['productId']] ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ${p['productName']} - Qty: ${p['quantity']}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (customizations.isEmpty)
                              const Text('No customizations added.')
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Color')),
                                    DataColumn(label: Text('Color Qty')),
                                    DataColumn(label: Text('Temple')),
                                    DataColumn(label: Text('Temple Qty')),
                                  ],
                                  rows: customizations.map<DataRow>((c) {
                                    return DataRow(cells: [
                                      DataCell(Text(c['colorName'] ?? '')),
                                      DataCell(Text(c['colorQty']?.toString() ?? '0')),
                                      DataCell(Text(c['templeName'] ?? '')),
                                      DataCell(Text(c['templeQty']?.toString() ?? '0')),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            const Divider(),
                          ],
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductSelectorSheet extends StatefulWidget {
  const _ProductSelectorSheet();

  @override
  State<_ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<_ProductSelectorSheet> {
  String? _selectedProductId;
  String? _selectedProductName;
  int _quantity = 1;

  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').orderBy('name').get();
      setState(() {
        _products = snapshot.docs;
        _filteredProducts = _products;
      });
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading products')),
        );
      }
    }
  }

  void _updateSearch(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final data = product.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Search Field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search Products',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _updateSearch,
              ),

              const SizedBox(height: 12),

              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final data = product.data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Unnamed';

                          return RadioListTile<String>(
                            title: Text(name),
                            value: product.id,
                            groupValue: _selectedProductId,
                            onChanged: (value) {
                              setState(() {
                                _selectedProductId = value;
                                _selectedProductName = name;
                              });
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                initialValue: '1',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _quantity = int.tryParse(value) ?? 1;
                  });
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Add Product'),
                onPressed: () {
                  if (_selectedProductId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a product')),
                    );
                    return;
                  }
                  if (_quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quantity must be greater than zero')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'productId': _selectedProductId,
                    'productName': _selectedProductName,
                    'quantity': _quantity,
                  });
                },
              )
            ],
          ),
        );
      },
    );
  }
}
