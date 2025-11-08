// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class ManageSuppliersPage extends StatefulWidget {
  const ManageSuppliersPage({super.key});

  @override
  State<ManageSuppliersPage> createState() => _ManageSuppliersPageState();
}

class _ManageSuppliersPageState extends State<ManageSuppliersPage> {
  String? companyId;
  CollectionReference? _suppliersCollection;
  late Stream<QuerySnapshot> _supplierStream;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedRole;

  bool isLoading = true;
  List<Map<String, dynamic>> _cachedSuppliers = [];

  @override
  void initState() {
    super.initState();
    _loadCompanyNamespace();
  }

  Future<void> _loadCompanyNamespace() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCompanyId = prefs.getString('cachedCompanyId');

    // Load cached suppliers instantly
    final cachedData = prefs.getString('cachedSuppliers');
    if (cachedData != null) {
      setState(() {
        _cachedSuppliers =
            List<Map<String, dynamic>>.from(jsonDecode(cachedData));
      });
    }

    if (storedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No company found in session')),
      );
      setState(() => isLoading = false);
      return;
    }

    setState(() {
      companyId = storedCompanyId;
      _suppliersCollection = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('suppliers');
      _supplierStream = _suppliersCollection!
          .orderBy('name', descending: false)
          .snapshots();
      isLoading = false;
    });
  }

  Future<void> _saveSuppliersToCache(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final suppliers = docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      data['id'] = d.id;
      return data;
    }).toList();

    await prefs.setString('cachedSuppliers', jsonEncode(suppliers));
    setState(() => _cachedSuppliers = suppliers);
  }

  Future<void> _addSupplier() async {
    if (_suppliersCollection == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final role = _selectedRole ?? 'Other';

    if (name.isEmpty || role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both name and role')),
      );
      return;
    }

    try {
      await _suppliersCollection!.add({
        'name': name,
        'phone': phone,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _phoneController.clear();
      setState(() => _selectedRole = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add supplier: $e')),
      );
    }
  }

  Future<void> _deleteSupplier(String docId) async {
    if (_suppliersCollection == null) return;

    try {
      await _suppliersCollection!.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete supplier: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_suppliersCollection == null) {
      return const Scaffold(
        body:
            Center(child: Text('No company context found. Please log in again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Manage Suppliers', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.lightBlue,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildSupplierForm(),
            const Divider(),
            Expanded(child: _buildSupplierList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierForm() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          CustomTextField(
            controller: _nameController,
            label: 'Supplier Name',
            icon: Icons.person,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 10),
          CustomTextField(
            controller: _phoneController,
            label: 'Supplier Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: 'Select Role',
              labelStyle: GoogleFonts.poppins(),
              prefixIcon: const Icon(Icons.assignment_ind),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Molding', child: Text('Molding')),
              DropdownMenuItem(value: 'Drumming', child: Text('Drumming')),
              DropdownMenuItem(value: 'Color', child: Text('Color')),
              DropdownMenuItem(value: 'Fitting', child: Text('Fitting')),
              DropdownMenuItem(value: 'Demo', child: Text('Demo')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _addSupplier,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text(
              'Add Supplier',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _supplierStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSupplierListView(_cachedSuppliers);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _cachedSuppliers.isNotEmpty
              ? _buildSupplierListView(_cachedSuppliers)
              : const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isNotEmpty) _saveSuppliersToCache(docs);

        final suppliers = docs.isNotEmpty
            ? docs
                .map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  data['id'] = d.id;
                  return data;
                })
                .toList()
            : _cachedSuppliers;

        if (suppliers.isEmpty) {
          return const Center(child: Text('No suppliers found.'));
        }

        return _buildSupplierListView(suppliers);
      },
    );
  }

  Widget _buildSupplierListView(List<Map<String, dynamic>> suppliers) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: suppliers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        final name = supplier['name'] ?? 'Unnamed';
        final phone = supplier['phone'] ?? 'N/A';
        final role = supplier['role'] ?? 'Unknown';

        return ListTile(
          leading: const Icon(Icons.business, color: Colors.lightBlue),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Phone: $phone\nRole: $role'),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              if (supplier['id'] != null) {
                _deleteSupplier(supplier['id']);
              }
            },
          ),
        );
      },
    );
  }
}
