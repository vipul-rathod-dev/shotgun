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

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final adminUser = _auth.currentUser;
    if (adminUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No admin user logged in!')),
      );
      return;
    }

    try {
      // Step 1️⃣: Create Company
      final companyRef = await _firestore.collection('companies').add({
        'name': _companyName.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUser.uid,
      });

      final companyId = companyRef.id;

      // Step 2️⃣: Add Admin inside the company namespace
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

      // Optional: store admin mapping globally
      await _firestore.collection('user_companies').doc(adminUser.uid).set({
        'companyId': companyId,
        'role': 'admin',
      });

      // Step 3️⃣: Create Firebase Auth User for Supervisor
      UserCredential supervisorCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _supervisorEmail.text.trim(),
        password: _supervisorPassword.text.trim(),
      );

      final supervisor = supervisorCredential.user!;
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

      await _firestore.collection('user_companies').doc(supervisor.uid).set({
        'companyId': companyId,
        'role': 'supervisor',
      });

      // Step 4️⃣: Sign out admin & redirect to login
      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Company created with Admin & Supervisor!')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Company")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _companyName,
                decoration: const InputDecoration(labelText: "Company Name"),
                validator: (v) => v!.isEmpty ? "Enter company name" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _supervisorEmail,
                decoration: const InputDecoration(labelText: "Supervisor Email"),
                validator: (v) => v!.isEmpty ? "Enter supervisor email" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _supervisorPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Supervisor Password"),
                validator: (v) => v!.length < 6
                    ? "Password must be at least 6 characters"
                    : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _createCompany,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Company"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
