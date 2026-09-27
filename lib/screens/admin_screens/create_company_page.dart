import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _supervisorEmail = TextEditingController();
  final TextEditingController _supervisorPassword = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _companyName.dispose();
    _supervisorEmail.dispose();
    _supervisorPassword.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    final companyName = _companyName.text.trim();

    if (companyName.isEmpty) return;

    setState(() => _isLoading = true);

    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No admin user logged in!'),
          ),
        );
      }

      setState(() => _isLoading = false);
      return;
    }

    try {
      // ---------------------------------------------------------
      // STEP 1: Normalize company name
      // ---------------------------------------------------------
      final normalizedCompanyName = companyName.toLowerCase();

      // ---------------------------------------------------------
      // STEP 2: Check if company already exists
      // ---------------------------------------------------------
      final existingCompany = await _firestore
          .collection('companies')
          .where(
            'normalizedName',
            isEqualTo: normalizedCompanyName,
          )
          .limit(1)
          .get();

      print('Existing Company: ${existingCompany.docs}');

      if (existingCompany.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Company "$companyName" already exists. '
                'You cannot create it again.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        setState(() => _isLoading = false);
        return;
      }

      // ---------------------------------------------------------
      // STEP 3: Create Company
      // ---------------------------------------------------------
      final companyRef =
          await _firestore.collection('companies').add({
        'name': companyName,
        'normalizedName': normalizedCompanyName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUser.uid,
      });

      final companyId = companyRef.id;

      // ---------------------------------------------------------
      // STEP 4: Add Admin inside company namespace
      // ---------------------------------------------------------
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(adminUser.uid)
          .set({
        'email': adminUser.email,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ---------------------------------------------------------
      // STEP 5: Store Admin → Company mapping
      // ---------------------------------------------------------
      await _firestore
          .collection('user_companies')
          .doc(adminUser.uid)
          .set({
        'companyId': companyId,
        'role': 'admin',
      });

      // ---------------------------------------------------------
      // STEP 6: Create Firebase Auth user for Supervisor
      // ---------------------------------------------------------
      final supervisorCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _supervisorEmail.text.trim(),
        password: _supervisorPassword.text.trim(),
      );

      final supervisor = supervisorCredential.user!;

      // ---------------------------------------------------------
      // STEP 7: Add Supervisor inside company namespace
      // ---------------------------------------------------------
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(supervisor.uid)
          .set({
        'email': supervisor.email,
        'role': 'supervisor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ---------------------------------------------------------
      // STEP 8: Store Supervisor → Company mapping
      // ---------------------------------------------------------
      await _firestore
          .collection('user_companies')
          .doc(supervisor.uid)
          .set({
        'companyId': companyId,
        'role': 'supervisor',
      });

      // ---------------------------------------------------------
      // STEP 9: Sign out
      // ---------------------------------------------------------
      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Company created with Admin & Supervisor!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create New Company"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _companyName,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Enter company name";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _supervisorEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Supervisor Email",
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Enter supervisor email";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _supervisorPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Supervisor Password",
                ),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return "Password must be at least 6 characters";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _createCompany,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Create Company"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}