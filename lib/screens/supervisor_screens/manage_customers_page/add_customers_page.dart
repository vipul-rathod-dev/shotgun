import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class AddCustomersPage extends StatefulWidget {
  const AddCustomersPage({super.key});

  @override
  State<AddCustomersPage> createState() => _AddCustomersPageState();
}

class _AddCustomersPageState extends State<AddCustomersPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isSaving = false;
  String? _companyId;

  String? _selectedGentsTemplate;
  String? _selectedLadiesTemplate;
  String? _selectedBabyTemplate;
  late List<Map<String, dynamic>> _templateDropdownItems = [];
  late List<Map<String, dynamic>> _gentsTemplates = [];
  late List<Map<String, dynamic>> _ladiesTemplates = [];
  late List<Map<String, dynamic>> _babyTemplates = [];


  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    _companyId = prefs.getString('cachedCompanyId');
    _loadColorTemplates();
  }

  void _loadColorTemplates() async {
    if (_companyId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('color_templates')
        .get();

    List<Map<String, dynamic>> all = snapshot.docs.map((doc) {
      // ignore: unnecessary_cast
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();

    setState(() {
      _templateDropdownItems = all;

      _gentsTemplates = all.where((t) {
        final pc = t['productCustomizations'];
        return pc != null && pc['gents'] != null;
      }).toList();

      _ladiesTemplates = all.where((t) {
        final pc = t['productCustomizations'];
        return pc != null && pc['ladies'] != null;
      }).toList();

      _babyTemplates = all.where((t) {
        final pc = t['productCustomizations'];
        return pc != null && pc['baby'] != null;
      }).toList();
    });
  }


  Future<void> _addCustomer() async {
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Company ID not found in local storage!")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('customers')
          .add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'defaultTemplates': {
          'gents': _selectedGentsTemplate,
          'ladies': _selectedLadiesTemplate,
          'baby': _selectedBabyTemplate,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added successfully')),
      );

      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _selectedGentsTemplate = null;
      _selectedLadiesTemplate = null;
      _selectedBabyTemplate = null;

      Navigator.pop(context); // Return to Customers List Page

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding customer: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic>? _findTemplateById(String? id) {
    if (id == null) return null;
    for (var item in _templateDropdownItems) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text("Add New Customer"),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 3,
      ),

      body: _companyId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 5),

                        // ────────────────────────────────────────
                        // ⭐ ACCORDION 1 — CUSTOMER DETAILS
                        // ────────────────────────────────────────
                        ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 10),
                          title: const Text(
                            "Customer Details",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            CustomTextField(
                              label: "Customer Name",
                              controller: _nameController,
                              validator: (v) => v == null || v.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 12),

                            CustomTextField(
                              label: "Phone Number",
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 12),

                            CustomTextField(
                              label: "Address",
                              controller: _addressController,
                              maxLines: 2,
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ────────────────────────────────────────
                        // ⭐ ACCORDION 2 — DEFAULT TEMPLATES
                        // ────────────────────────────────────────
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 10),
                          title: const Text(
                            "Default Color Templates",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            SearchableDropdown(
                              items: _gentsTemplates,
                              keyName: 'name',
                              labelText: "Gents Template",
                              value: _findTemplateById(_selectedGentsTemplate),
                              onChanged: (selected) {
                                setState(() {
                                  _selectedGentsTemplate = selected?['id'];
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            SearchableDropdown(
                              items: _ladiesTemplates,
                              keyName: 'name',
                              labelText: "Ladies Template",
                              value: _findTemplateById(_selectedLadiesTemplate),
                              onChanged: (selected) {
                                setState(() {
                                  _selectedLadiesTemplate = selected?['id'];
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            SearchableDropdown(
                              items: _babyTemplates,
                              keyName: 'name',
                              labelText: "Baby Template",
                              value: _findTemplateById(_selectedBabyTemplate),
                              onChanged: (selected) {
                                setState(() {
                                  _selectedBabyTemplate = selected?['id'];
                                });
                              },
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // SAVE BUTTON
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _addCustomer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, color: Colors.white,),
                          label: const Text(
                            "Save Customer",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
