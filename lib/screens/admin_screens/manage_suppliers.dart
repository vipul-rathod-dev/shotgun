import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class ManageSuppliersPage extends StatefulWidget {
  const ManageSuppliersPage({super.key});

  @override
  State<ManageSuppliersPage> createState() => _ManageSuppliersPageState();
}

class _ManageSuppliersPageState extends State<ManageSuppliersPage> {
  final CollectionReference _suppliersCollection =
      FirebaseFirestore.instance.collection('suppliers');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedRole;


  Future<void> _addSupplier() async {
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
      await _suppliersCollection.add({
        'name': name,
        'phone': phone,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _phoneController.clear();

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
    try {
      await _suppliersCollection.doc(docId).delete();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Suppliers', style: TextStyle(color: Colors.black),),
        backgroundColor: Colors.lightBlue,
      ),
      body: Column(
        children: [
          // Input Fields
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                CustomTextField(
                  controller: _nameController,
                  label: 'Supplier Name',
                  icon: Icons.face_6_rounded,
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
                  prefixIcon: Icon(Icons.assignment_ind),
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
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addSupplier,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                  child: const Text('Add Supplier', style: TextStyle(color: Colors.black),),
                ),
              ],
            ),
          ),

          const Divider(),

          // Supplier List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _suppliersCollection
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading suppliers'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final suppliers = snapshot.data!.docs;

                if (suppliers.isEmpty) {
                  return const Center(child: Text('No suppliers found.'));
                }

                return ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final doc = suppliers[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name'] ?? 'Unnamed';
                    final phone = data['phone'] ?? 'N/A';
                    final role = data['role'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.business),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: $phone'),
                            Text('Role: $role')
                          ]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSupplier(doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
