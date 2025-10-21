import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/widgets/date_picker_field.dart';

class NewMultiProductOrderPage extends StatefulWidget {
  const NewMultiProductOrderPage({super.key});

  @override
  State<NewMultiProductOrderPage> createState() => _NewMultiProductOrderPageState();
}

class _NewMultiProductOrderPageState extends State<NewMultiProductOrderPage> {
  final _formKey = GlobalKey<FormState>();
  String? _customerName;
  DateTime? _orderDate;
  DateTime? _shippingDate;

  List<Map<String, dynamic>> _productSelections = [];

  bool _isSubmitting = false;

  Future<int> _getNextOrderNumber() async {
    final counterRef = FirebaseFirestore.instance.collection('counters').doc('orders');

    return FirebaseFirestore.instance.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        // If the document doesn't exist, initialize it
        transaction.set(counterRef, {'lastOrderNumber': 1000});
        return 1001;
      }

      final current = snapshot.get('lastOrderNumber') as int;
      final next = current + 1;

      transaction.update(counterRef, {'lastOrderNumber': next});
      return next;
    });
  }

  // Future<void> _loadNextOrderNumber() async {
  //   try {
  //     final nextOrderNumber = await _getNextOrderNumber();
  //     setState(() {
  //       _orderNumber = nextOrderNumber;
  //       _orderNumberController.text = _orderNumber.toString();
  //     });
  //   } catch (e) {
  //     debugPrint("Failed to get next order number: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Error getting order number')),
  //     );
  //   }
  // }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate() || _productSelections.isEmpty) return;

    _formKey.currentState!.save();

    try {
      setState(() => _isSubmitting = true);

      final orderNumber = await _getNextOrderNumber(); // Fetch when submitting

      await FirebaseFirestore.instance.collection('orders').add({
        'orderNumber': orderNumber,
        'customerName': _customerName,
        'orderDate': Timestamp.fromDate(_orderDate!),
        'shippingDate': Timestamp.fromDate(_shippingDate!),
        'products': _productSelections,
        'timestamp': FieldValue.serverTimestamp(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Customer Name
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _customerName = value?.trim(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter customer name' : null,
              ),
              const SizedBox(height: 16),

              // Order Date Picker
              DatePickerField(
                label: 'Order Date',
                selectedDate: _orderDate,
                onDateSelected: (date) => setState(() => _orderDate = date),
              ),
              const SizedBox(height: 16),

              // Shipping Date Picker
              DatePickerField(
                label: 'Estimated Shipping Date',
                selectedDate: _shippingDate,
                onDateSelected: (date) => setState(() => _shippingDate = date),
              ),
              const SizedBox(height: 24),

              // Product List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
              ..._productSelections.map((item) {
                return ListTile(
                  title: Text(item['productName']),
                  subtitle: Text('Qty: ${item['quantity']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() => _productSelections.remove(item));
                    },
                  ),
                );
              }),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_isSubmitting ? 'Saving...' : 'Submit Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSubmitting ? null : _submitOrder,
              ),
            ],
          ),
        ),
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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').orderBy('name').get();
      setState(() => _products = snapshot.docs);
    } catch (e) {
      debugPrint('Failed to load products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading products')),
        );
      }
    }
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
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
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
                  if (_selectedProductId != null && _quantity > 0) {
                    Navigator.pop(context, {
                      'productId': _selectedProductId,
                      'productName': _selectedProductName,
                      'quantity': _quantity,
                    });
                  }
                },
              )
            ],
          ),
        );
      },
    );
  }
}

