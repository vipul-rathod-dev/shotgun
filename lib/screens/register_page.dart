// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final contactController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'staff';

  Future<void> registerUser(String email, String password, String role) async {
    try {
      // Create Firebase user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save user role to Firestore
      await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
          'first_name': firstNameController.text.trim(),
          'last_name': lastNameController.text.trim(),
          'contact': contactController.text.trim(),
          'email': email,
          'role': role,
      });

      // Navigate based on role
      // if (role == 'admin') {
      //   Navigator.pushReplacementNamed(context, '/admin');
      // } else {
      //   Navigator.pushReplacementNamed(context, '/staff');
      // }
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      String message = "Registration failed";

      if (e.code == 'email-already-in-use') {
        message = "Email already in use";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong")));
    }
  }

  void register() async {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      await registerUser(email, password, selectedRole);
    }
  }

  String? emailValidator(String? val) {
    if (val == null || val.isEmpty) return "Email is required";
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(val)) return "Enter a valid email";
    return null;
  }

  String? passwordValidator(String? val) {
    if (val == null || val.isEmpty) return "Password is required";
    if (val.length < 6) return "Minimum 6 characters required";
    return null;
  }

  String? confirmPasswordValidator(String? val) {
    if (val == null || val.isEmpty) return "Confirm your password";
    if (val != passwordController.text) return "Passwords do not match";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Image.asset(
                'assets/images/a1specto_logo.jpg',
                height: 100,
              ),
              const SizedBox(height: 32),

              // 🔽 The Card containing the form 🔽
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          "Create Account",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        CustomTextField(
                          label: "First Name",
                          icon: Icons.person_outline,
                          controller: firstNameController,
                          validator: (value) =>
                              value == null || value.isEmpty ? "First name is required" : null,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Last Name",
                          icon: Icons.person_outline,
                          controller: lastNameController,
                          validator: (value) =>
                              value == null || value.isEmpty ? "Last name is required" : null,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Contact Number",
                          icon: Icons.phone,
                          controller: contactController,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value == null || value.isEmpty ? "Contact number is required" : null,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Email",
                          icon: Icons.email_outlined,
                          controller: emailController,
                          validator: emailValidator,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Password",
                          icon: Icons.lock_outline,
                          controller: passwordController,
                          isPassword: true,
                          validator: passwordValidator,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Confirm Password",
                          icon: Icons.lock_person_outlined,
                          controller: confirmPasswordController,
                          isPassword: true,
                          validator: confirmPasswordValidator,
                        ),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: "Select Role",
                            border: OutlineInputBorder(),
                          ),
                          items: ['admin', 'staff'].map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role[0].toUpperCase() + role.substring(1)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: register,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("Register"),
                          ),
                        ),

                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text("Already have an account? Login"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    contactController.dispose();
    super.dispose();
  }

}
