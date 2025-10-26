import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanyLoginPage extends StatefulWidget {
  const CompanyLoginPage({super.key});

  @override
  State<CompanyLoginPage> createState() => _CompanyLoginPageState();
}

class _CompanyLoginPageState extends State<CompanyLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Step 1️⃣ Authenticate with Firebase Auth
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user!;
      final userId = user.uid;

      // Step 2️⃣ Find company mapping from global user_companies
      final mapping = await _firestore.collection('user_companies').doc(userId).get();
      if (!mapping.exists) {
        throw Exception('No company found for this user.');
      }

      final companyId = mapping.data()?['companyId'];
      final role = mapping.data()?['role'];

      // Step 3️⃣ Load user data from company namespace
      final userDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data missing under company namespace.');
      }

      final userData = userDoc.data();
      debugPrint('✅ Logged in user role: $role, company: $companyId');

      // Step 4️⃣ Navigate by role
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin', arguments: {
          'companyId': companyId,
          'userId': userId,
          'role': role,
          'userData': userData,
        });
      } else if (role == 'supervisor') {
        Navigator.pushReplacementNamed(context, '/supervisor', arguments: {
          'companyId': companyId,
          'userId': userId,
          'role': role,
          'userData': userData,
        });
      } else if (role == 'staff') {
        Navigator.pushReplacementNamed(context, '/staff', arguments: {
          'companyId': companyId,
          'userId': userId,
          'role': role,
          'userData': userData,
        });
      } else {
        throw Exception('Unknown role: $role');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Company Login"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  "Welcome Back 👋",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Enter email" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => v!.length < 6
                      ? "Password must be at least 6 characters"
                      : null,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Login",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
