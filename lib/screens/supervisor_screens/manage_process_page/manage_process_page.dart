// main.dart
// Single-file demo: Multi-Process Manager with Incoming/Outgoing for Flutter + Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------
// Model: ProcessTransaction
// -----------------------------
class ProcessTransaction {
  final String id;
  final String processType;
  final String transactionType;
  final String materialName;
  final double quantity;
  final String unit;
  final DateTime date;
  final String createdBy;
  final String? remarks;
  final String? linkedProcessId;

  ProcessTransaction({
    required this.id,
    required this.processType,
    required this.transactionType,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.createdBy,
    this.remarks,
    this.linkedProcessId,
  });

  Map<String, dynamic> toJson() => {
        'processType': processType,
        'transactionType': transactionType,
        'materialName': materialName,
        'quantity': quantity,
        'unit': unit,
        'date': date.toUtc(),
        'createdBy': createdBy,
        'remarks': remarks,
        'linkedProcessId': linkedProcessId,
      };

  factory ProcessTransaction.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProcessTransaction(
      id: doc.id,
      processType: d['processType'] ?? 'raw_material',
      transactionType: d['transactionType'] ?? 'incoming',
      materialName: d['materialName'] ?? '',
      quantity: (d['quantity'] ?? 0).toDouble(),
      unit: d['unit'] ?? 'pcs',
      date: (d['date'] as Timestamp).toDate(),
      createdBy: d['createdBy'] ?? 'unknown',
      remarks: d['remarks'],
      linkedProcessId: d['linkedProcessId'],
    );
  }
}

// -----------------------------
// Firestore Service
// -----------------------------
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String companyId;

  FirestoreService({required this.companyId});

  CollectionReference<Map<String, dynamic>> get _transactionsCol =>
      _db.collection('companies').doc(companyId).collection('processTransactions');

  CollectionReference<Map<String, dynamic>> get _productsCol =>
      _db.collection('companies').doc(companyId).collection('products');

  // Stream products
  Stream<List<Product>> streamProducts() {
    return _productsCol.snapshots().map((snap) =>
        snap.docs.map((d) => Product.fromDoc(d)).toList());
  }

  Future<void> addTransaction(ProcessTransaction tx) async {
    await _transactionsCol.add(tx.toJson());
  }

  Stream<List<ProcessTransaction>> streamTransactions({
    required String processType,
    required String transactionType,
  }) {
    return _transactionsCol
        .where('processType', isEqualTo: processType)
        .where('transactionType', isEqualTo: transactionType)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ProcessTransaction.fromDoc(d)).toList());
  }

  Stream<List<ProcessTransaction>> streamOutgoingForLinking({required String processType}) {
    return streamTransactions(processType: processType, transactionType: 'outgoing');
  }
}

// Product model
class Product {
  final String id;
  final String name;
  final String displayName;
  final String unit;
  final num stock;

  Product({required this.id, required this.name, required this.unit, required this.displayName, required this.stock});

  factory Product.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: d['name'] ?? '',
      unit: d['unit'] ?? 'pcs',
      displayName: d['displayName'],
      stock: d['stock']
    );
  }
}

// -----------------------------
// Dashboard / ManageProcessPage
// -----------------------------
class ManageProcessPage extends StatefulWidget {
  const ManageProcessPage({super.key});

  @override
  State<ManageProcessPage> createState() => _ManageProcessPageState();
}

class _ManageProcessPageState extends State<ManageProcessPage> {
  FirestoreService? service;
  String? companyId;
  bool _loading = true;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1️⃣ Get current Firebase Auth user
    currentUser = FirebaseAuth.instance.currentUser;

    // 2️⃣ Load companyId from SharedPreferences (or fallback)
    final prefs = await SharedPreferences.getInstance();
    companyId = prefs.getString('cachedCompanyId') ?? 'demo-company';

    // 3️⃣ Initialize FirestoreService
    service = FirestoreService(companyId: companyId!);

    // 4️⃣ Stop loading
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || service == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final processes = [
      {'title': 'Raw Material', 'type': 'raw_material'},
      {'title': 'Color Process', 'type': 'color'},
      {'title': 'Fitting Process', 'type': 'fitting'},
      {'title': 'Demo Process', 'type': 'demo'},
      {'title': 'Packing Process', 'type': 'packing'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Process Dashboard - ${currentUser?.displayName ?? currentUser?.email ?? "Unknown"}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: processes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) {
            final p = processes[i];
            return ProcessCard(
              title: p['title']!,
              subtitle: 'Incoming / Outgoing',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcessListPage(service: service!, processType: p['type']!, currentUser: currentUser!),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProcessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ProcessCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(subtitle),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(onPressed: onTap, child: const Text('Open')),
                ),
              ]),
        ),
      ),
    );
  }
}

// -----------------------------
// Generic ProcessListPage (Incoming/Outgoing Tabs)
// -----------------------------
class ProcessListPage extends StatefulWidget {
  final FirestoreService service;
  final String processType;
  final int? forceTab;
  final User currentUser; 

  const ProcessListPage({super.key, required this.service, required this.processType, this.forceTab, required this.currentUser,});

  @override
  State<ProcessListPage> createState() => _ProcessListPageState();
}

class _ProcessListPageState extends State<ProcessListPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.forceTab ?? 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.processType.replaceAll('_', ' ').toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: Text('$title Transactions'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Incoming'),
          Tab(text: 'Outgoing'),
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        TransactionsListView(service: widget.service, processType: widget.processType, transactionType: 'incoming'),
        TransactionsListView(service: widget.service, processType: widget.processType, transactionType: 'outgoing'),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Add'),
        icon: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionPage(
              service: widget.service,
              processType: widget.processType,
              transactionType: _tabController.index == 0 ? 'incoming' : 'outgoing',
              currentUser: widget.currentUser,
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------
// Transactions ListView
// -----------------------------
class TransactionsListView extends StatelessWidget {
  final FirestoreService service;
  final String processType;
  final String transactionType;

  const TransactionsListView({super.key, required this.service, required this.processType, required this.transactionType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProcessTransaction>>(
      stream: service.streamTransactions(processType: processType, transactionType: transactionType),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text('No $transactionType found'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => TransactionTile(tx: list[i]),
        );
      },
    );
  }
}

class TransactionTile extends StatelessWidget {
  final ProcessTransaction tx;

  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(tx.unit)),
        title: Text('${tx.materialName} — ${tx.quantity} ${tx.unit}'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tx.transactionType.toUpperCase()} • ${tx.processType}'),
          if (tx.remarks != null) Text(tx.remarks!),
          Text('By ${tx.createdBy} • ${dateFmt.format(tx.date)}'),
        ]),
        isThreeLine: true,
      ),
    );
  }
}

// -----------------------------
// Add Transaction Page
// -----------------------------

class AddTransactionPage extends StatefulWidget {
  final FirestoreService service;
  final String processType;
  final String transactionType;
  final User currentUser;

  const AddTransactionPage({
    super.key,
    required this.service,
    required this.processType,
    required this.transactionType,
    required this.currentUser,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _materialCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  String _unit = 'pcs';
  DateTime _date = DateTime.now();
  final _remarksCtrl = TextEditingController();
  String? _linkedId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _materialCtrl.dispose();
    _quantityCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final tx = ProcessTransaction(
      id: '',
      processType: widget.processType,
      transactionType: widget.transactionType,
      materialName: _materialCtrl.text.trim(),
      quantity: double.tryParse(_quantityCtrl.text.trim()) ?? 0.0,
      unit: _unit,
      date: _date,
      createdBy: widget.currentUser.email ?? widget.currentUser.uid,
      remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      linkedProcessId: _linkedId,
    );

    try {
      await widget.service.addTransaction(tx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving transaction: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );

    setState(() {
      _date = t != null
          ? DateTime(d.year, d.month, d.day, t.hour, t.minute)
          : DateTime(d.year, d.month, d.day, _date.hour, _date.minute);
    });
  }

  Widget _linkedSelector() {
    if (widget.transactionType == 'incoming') return const SizedBox.shrink();

    return StreamBuilder<List<ProcessTransaction>>(
      stream: widget.service.streamOutgoingForLinking(processType: widget.processType),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return DropdownButtonFormField<String>(
          value: _linkedId,
          onChanged: (v) => setState(() => _linkedId = v),
          items: [
            const DropdownMenuItem(value: null, child: Text('No link'))
          ]..addAll(items.map((e) => DropdownMenuItem(
              value: e.id,
              child: Text('${e.materialName} • ${e.quantity} ${e.unit}'),
            ))),
          decoration: const InputDecoration(labelText: 'Link to outgoing entry (optional)'),
        );
      },
    );
  }

  Widget _materialSelector() {
    if (widget.processType != 'raw_material') {
      return TextFormField(
        controller: _materialCtrl,
        decoration: const InputDecoration(labelText: 'Material name'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter material name' : null,
      );
    }

    return StreamBuilder<List<Product>>(
      stream: widget.service.streamProducts(),
      builder: (context, snap) {
        final products = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        return DropdownButtonFormField<String>(
          value: _materialCtrl.text.isEmpty ? null : _materialCtrl.text,
          onChanged: (val) {
            setState(() {
              _materialCtrl.text = val!;
              final selected = products.firstWhere((p) => p.name == val);
              _unit = selected.unit;
            });
          },
          items: products.map((p) => DropdownMenuItem(
            value: p.name,
            child: Text('${p.name} - ${p.stock} ${p.unit}'),
          )).toList(),
          decoration: const InputDecoration(labelText: 'Select Material'),
          validator: (v) => (v == null || v.isEmpty) ? 'Select material' : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.transactionType}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _materialSelector(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid quantity' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('kg')),
                  DropdownMenuItem(value: 'mtr', child: Text('mtr')),
                  DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                ],
                decoration: const InputDecoration(labelText: 'Unit'),
                onChanged: (v) => setState(() => _unit = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & Time'),
                subtitle: Text(dateFmt.format(_date)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(height: 8),
              _linkedSelector(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
