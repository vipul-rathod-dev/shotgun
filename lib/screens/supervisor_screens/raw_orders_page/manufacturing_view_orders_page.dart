import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManufacturingViewOrdersPage extends StatefulWidget {
  const ManufacturingViewOrdersPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManufacturingViewOrdersPage> createState() =>
      _ManufacturingViewOrdersPageState();
}

class _ManufacturingViewOrdersPageState
    extends State<ManufacturingViewOrdersPage>
    with SingleTickerProviderStateMixin {
  String? _companyId;
  bool _loading = true;

  late final TabController _tabController;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _moldingSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _drummingSubscription;

  List<Map<String, dynamic>> _moldingOrders = [];
  List<Map<String, dynamic>> _drummingOrders = [];

  String _moldingSearch = '';
  String _drummingSearch = '';

  final _moldingSearchController = TextEditingController();
  final _drummingSearchController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _moldingRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('molding_wip');

  CollectionReference<Map<String, dynamic>> get _drummingRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('drumming_orders');

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _moldingSubscription?.cancel();
    _drummingSubscription?.cancel();
    _tabController.dispose();
    _moldingSearchController.dispose();
    _drummingSearchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.isEmpty) {
        throw Exception('Company ID not found. Please log in again.');
      }

      _companyId = companyId;

      _startMoldingListener();
      _startDrummingListener();
    } catch (e) {
      _showMessage('Failed to load manufacturing orders: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startMoldingListener() {
    _moldingSubscription?.cancel();

    _moldingSubscription = _moldingRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();

        data.sort(
          (a, b) => _dateFor(b).compareTo(_dateFor(a)),
        );

        if (!mounted) return;
        setState(() => _moldingOrders = data);
      },
      onError: (error) {
        _showMessage(
          'Failed to listen for molding orders: $error',
          error: true,
        );
      },
    );
  }

  void _startDrummingListener() {
    _drummingSubscription?.cancel();

    _drummingSubscription = _drummingRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();

        data.sort(
          (a, b) => _dateFor(b).compareTo(_dateFor(a)),
        );

        if (!mounted) return;
        setState(() => _drummingOrders = data);
      },
      onError: (error) {
        _showMessage(
          'Failed to listen for drumming orders: $error',
          error: true,
        );
      },
    );
  }

  DateTime _dateFor(Map<String, dynamic> data) {
    for (final key in const [
      'updatedAt',
      'createdAt',
      'receivedAt',
      'sentAt',
      'completedAt',
    ]) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> get _filteredMolding {
    final query = _moldingSearch.trim().toLowerCase();

    if (query.isEmpty) return _moldingOrders;

    return _moldingOrders.where((item) {
      return _matches(item, [
        'rawOrderNumber',
        'rawOrderId',
        'moldName',
        'modelName',
        'productName',
        'productCode',
        'variantType',
        'moldingSupplierName',
        'supplierName',
        'status',
      ], query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredDrumming {
    final query = _drummingSearch.trim().toLowerCase();

    if (query.isEmpty) return _drummingOrders;

    return _drummingOrders.where((item) {
      return _matches(item, [
        'drummingNumber',
        'rawOrderNumber',
        'rawOrderId',
        'moldName',
        'modelName',
        'productName',
        'productCode',
        'variantType',
        'moldingSupplierName',
        'drummingSupplierName',
        'status',
      ], query);
    }).toList();
  }

  bool _matches(
    Map<String, dynamic> item,
    List<String> keys,
    String query,
  ) {
    for (final key in keys) {
      if ((item[key]?.toString().toLowerCase() ?? '').contains(query)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manufacturing Orders'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.precision_manufacturing_outlined),
              text: 'Molding Orders (${_moldingOrders.length})',
            ),
            Tab(
              icon: const Icon(Icons.rotate_right_outlined),
              text: 'Drumming Orders (${_drummingOrders.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMoldingOrders(),
                _buildDrummingOrders(),
              ],
            ),
    );
  }

  Widget _buildMoldingOrders() {
    final orders = _filteredMolding;

    return Column(
      children: [
        _buildSearchField(
          controller: _moldingSearchController,
          hint: 'Search molding order, mold, model, supplier...',
          onChanged: (value) {
            setState(() => _moldingSearch = value);
          },
        ),
        Expanded(
          child: orders.isEmpty
              ? _emptyState(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'No molding orders found',
                  subtitle: 'Molding receipts will appear here automatically.',
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, index) =>
                        _buildMoldingCard(orders[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDrummingOrders() {
    final orders = _filteredDrumming;

    return Column(
      children: [
        _buildSearchField(
          controller: _drummingSearchController,
          hint: 'Search drumming order, product, supplier...',
          onChanged: (value) {
            setState(() => _drummingSearch = value);
          },
        ),
        Expanded(
          child: orders.isEmpty
              ? _emptyState(
                  icon: Icons.rotate_right_outlined,
                  title: 'No drumming orders found',
                  subtitle: 'Batches sent to drumming will appear here automatically.',
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, index) =>
                        _buildDrummingCard(orders[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }

  Widget _buildMoldingCard(Map<String, dynamic> item) {
    final available = _number(item['availableQuantity']);
    final received = _number(item['totalReceivedQuantity']);
    final weight = _number(
      item['totalReceivedWeightKg'] ??
          item['receivedWeightKg'] ??
          item['weightKg'],
    );

    final labor = _labor(item['moldingLabor']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(
          title: 'Molding Order',
          data: item,
          laborLabel: 'Molding Labour',
          labor: labor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _text(
                        item['rawOrderNumber'],
                        fallback: item['rawOrderId']?.toString() ?? 'Molding Batch',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _statusChip(
                    item['status']?.toString() ?? 'Available for Drumming',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _productTitle(item),
              const SizedBox(height: 8),
              _traceLine(item),
              const Divider(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _metric('Received', '$received pcs'),
                  _metric('Available', '$available pcs'),
                  _metric('Weight', '${_formatNumber(weight)} kg'),
                  _metric(
                    'Molding Labour',
                    '₹${_formatNumber(labor['cost'])}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _supplierLine(
                label: 'Molding Supplier',
                value: _text(
                  item['moldingSupplierName'],
                  fallback: item['supplierName']?.toString() ?? '-',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrummingCard(Map<String, dynamic> item) {
    final sent = _number(item['quantitySent']);
    final completed = _number(item['quantityCompleted']);
    final rejected = _number(item['quantityRejected']);

    final weight = _number(
      item['weightSentKg'] ??
          item['sentWeightKg'] ??
          item['quantitySentWeightKg'],
    );

    final goodWeight = _number(
      item['goodWeightKg'] ??
          item['completedWeightKg'],
    );

    final rejectedWeight = _number(item['rejectedWeightKg']);

    final labor = _labor(item['drummingLabor']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(
          title: 'Drumming Order',
          data: item,
          laborLabel: 'Drumming Labour',
          labor: labor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rotate_right_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _text(
                        item['drummingNumber'],
                        fallback: item['id']?.toString() ?? 'Drumming Batch',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _statusChip(
                    item['status']?.toString() ?? 'In Drumming',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _productTitle(item),
              const SizedBox(height: 8),
              _traceLine(item),
              const Divider(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _metric('Sent', '$sent pcs'),
                  _metric('Good', '$completed pcs'),
                  _metric('Rejected', '$rejected pcs'),
                  _metric('Sent Weight', '${_formatNumber(weight)} kg'),
                  _metric('Good Weight', '${_formatNumber(goodWeight)} kg'),
                  _metric(
                    'Rejected Weight',
                    '${_formatNumber(rejectedWeight)} kg',
                  ),
                  _metric(
                    'Drumming Labour',
                    '₹${_formatNumber(labor['cost'])}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _supplierLine(
                label: 'Molding Supplier',
                value: _text(
                  item['moldingSupplierName'],
                  fallback: '-',
                ),
              ),
              _supplierLine(
                label: 'Drumming Supplier',
                value: _text(
                  item['drummingSupplierName'],
                  fallback: '-',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productTitle(Map<String, dynamic> item) {
    return Text(
      '${_text(item['variantType'], fallback: '')} • '
      '${_text(item['productName'], fallback: 'Unknown Product')}',
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  Widget _traceLine(Map<String, dynamic> item) {
    final mold = _text(item['moldName'], fallback: '-');
    final cavity = _text(item['cavityNumber'], fallback: '-');
    final model = _text(item['modelName'], fallback: '-');

    return Text(
      'Mold: $mold  •  Cavity: $cavity  •  Model: $model',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _supplierLine({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();

    final Color color;
    if (normalized.contains('complete')) {
      color = Colors.green;
    } else if (normalized.contains('reject')) {
      color = Colors.red;
    } else if (normalized.contains('partial')) {
      color = Colors.orange;
    } else if (normalized.contains('sent') ||
        normalized.contains('drumming')) {
      color = Colors.deepPurple;
    } else {
      color = Colors.blue;
    }

    return Chip(
      label: Text(status),
      side: BorderSide(color: color.withOpacity(.25)),
      backgroundColor: color.withOpacity(.08),
    );
  }

  Map<String, dynamic> _labor(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return {
        'vendorId': map['vendorId'],
        'vendorName': map['vendorName'],
        'rate': _number(map['rate']),
        'rateUnit': map['rateUnit']?.toString() ?? '',
        'cost': _number(
          map['laborCost'] ??
              map['cost'] ??
              map['amount'],
        ),
      };
    }

    return {
      'vendorId': null,
      'vendorName': null,
      'rate': 0.0,
      'rateUnit': '',
      'cost': 0.0,
    };
  }

  void _showDetails({
    required String title,
    required Map<String, dynamic> data,
    required String laborLabel,
    required Map<String, dynamic> labor,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailSection(
                    'Batch',
                    [
                      _detailRow('Document ID', data['id']),
                      _detailRow('Raw Order', data['rawOrderNumber']),
                      _detailRow('Mold', data['moldName']),
                      _detailRow('Cavity', data['cavityNumber']),
                      _detailRow('Model', data['modelName']),
                      _detailRow('Variant', data['variantType']),
                      _detailRow('Product', data['productName']),
                      _detailRow('Product Code', data['productCode']),
                      _detailRow('Status', data['status']),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailSection(
                    'Quantities & Weight',
                    [
                      _detailRow(
                        'Quantity',
                        '${_number(data['quantity'] ?? data['quantitySent'])} pcs',
                      ),
                      _detailRow(
                        'Available',
                        '${_number(data['availableQuantity'])} pcs',
                      ),
                      _detailRow(
                        'Completed',
                        '${_number(data['quantityCompleted'])} pcs',
                      ),
                      _detailRow(
                        'Rejected',
                        '${_number(data['quantityRejected'])} pcs',
                      ),
                      _detailRow(
                        'Weight',
                        '${_formatNumber(_number(data['weightKg'] ?? data['weightSentKg']))} kg',
                      ),
                      _detailRow(
                        'Good Weight',
                        '${_formatNumber(_number(data['goodWeightKg']))} kg',
                      ),
                      _detailRow(
                        'Rejected Weight',
                        '${_formatNumber(_number(data['rejectedWeightKg']))} kg',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailSection(
                    laborLabel,
                    [
                      _detailRow(
                        'Supplier',
                        labor['vendorName'],
                      ),
                      _detailRow(
                        'Rate',
                        '₹${_formatNumber(labor['rate'])} ${labor['rateUnit']}',
                      ),
                      _detailRow(
                        'Labour Cost',
                        '₹${_formatNumber(labor['cost'])}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailSection(
                    'Suppliers',
                    [
                      _detailRow(
                        'Molding Supplier',
                        data['moldingSupplierName'] ??
                            data['supplierName'],
                      ),
                      _detailRow(
                        'Drumming Supplier',
                        data['drummingSupplierName'],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value?.toString().trim().isNotEmpty == true
                ? value.toString()
                : '-'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _refresh() async {
    if (_companyId == null) return;

    // Snapshots are already realtime. Restarting the listeners is enough
    // to force a fresh read without requiring orderBy indexes.
    _startMoldingListener();
    _startDrummingListener();

    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }
}
