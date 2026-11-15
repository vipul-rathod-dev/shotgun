
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shotgun/app/app_navigation.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  State<CreateCompanyPage> createState() =>
      _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _companyName =
      TextEditingController();

  final TextEditingController _companyId =
      TextEditingController();

  final TextEditingController _address =
      TextEditingController();

  final TextEditingController _state =
      TextEditingController();

  final TextEditingController _pinCode =
      TextEditingController();

  final TextEditingController _supervisorEmail =
      TextEditingController();

  final TextEditingController _supervisorPassword =
      TextEditingController();

  final TextEditingController _confirmPassword =
      TextEditingController();

  bool _isLoading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _companyName.dispose();
    _companyId.dispose();
    _address.dispose();
    _state.dispose();
    _pinCode.dispose();
    _supervisorEmail.dispose();
    _supervisorPassword.dispose();
    _confirmPassword.dispose();

    super.dispose();
  }

  // ============================================================
  // CREATE COMPANY
  // ============================================================

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    final companyName = _companyName.text.trim();

    // Normalize Company ID for consistent login.
    final companyId = _companyId.text.trim().toLowerCase();

    final normalizedCompanyName =
        companyName.toLowerCase();

    final email = _supervisorEmail.text.trim();

    final password = _supervisorPassword.text.trim();

    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No admin user logged in!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ========================================================
      // STEP 1: CHECK IF COMPANY ALREADY EXISTS
      // Company ID is also the Firestore document ID.
      // ========================================================

      final companyRef = _firestore
          .collection('companies')
          .doc(companyId);

      final existingCompanyId = await companyRef.get();

      final existingCompanyName = await _firestore
          .collection('companies')
          .where(
            'normalizedName',
            isEqualTo: normalizedCompanyName,
          )
          .limit(1)
          .get();

      if (existingCompanyId.exists ||
          existingCompanyName.docs.isNotEmpty) {
        throw Exception(
          'Company already exists. Please use a different Company Name and Company ID.',
        );
      }

      // ========================================================
      // STEP 3: CREATE COMPANY
      // Use Company ID as Firestore document ID.
      // ========================================================

      await companyRef.set({
        'name': companyName,
        'normalizedName': normalizedCompanyName,
        'companyId': companyId,

        'address': _address.text.trim(),
        'state': _state.text.trim(),
        'pinCode': _pinCode.text.trim(),

        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUser.uid,
      });

      // ========================================================
      // STEP 4: ADD ADMIN INSIDE COMPANY NAMESPACE
      // ========================================================

      await companyRef
          .collection('users')
          .doc(adminUser.uid)
          .set({
        'email': adminUser.email,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // STEP 5: STORE ADMIN -> COMPANY MAPPING
      // ========================================================

      await _firestore
          .collection('user_companies')
          .doc(adminUser.uid)
          .set({
        'companyId': companyId,
        'role': 'admin',
      });

      // ========================================================
      // STEP 6: CREATE SUPERVISOR USING SECONDARY FIREBASE APP
      // ========================================================

      FirebaseApp? secondaryApp;

      String? supervisorUid;
      String? supervisorCreatedEmail;

      try {
        secondaryApp = await Firebase.initializeApp(
          name: 'SupervisorCreation',
          options: Firebase.app().options,
        );

        final secondaryAuth = FirebaseAuth.instanceFor(
          app: secondaryApp,
        );

        final supervisorCredential =
            await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final createdUser = supervisorCredential.user;

        if (createdUser == null) {
          throw Exception('Unable to create supervisor account.');
        }

        // Extract values before deleting the secondary app.
        supervisorUid = createdUser.uid;
        supervisorCreatedEmail = createdUser.email;

        debugPrint('Supervisor created: $supervisorUid');
      } finally {
        if (secondaryApp != null) {
          await secondaryApp.delete();
        }
      }

      // ========================================================
      // STEP 7: ADD SUPERVISOR INSIDE COMPANY
      // ========================================================

      await companyRef
          .collection('users')
          .doc(supervisorUid)
          .set({
        'email': supervisorCreatedEmail,
        'role': 'supervisor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // STEP 8: STORE SUPERVISOR -> COMPANY MAPPING
      // ========================================================

      await _firestore
          .collection('user_companies')
          .doc(supervisorUid)
          .set({
        'companyId': companyId,
        'role': 'supervisor',
      });

      // ========================================================
      // STEP 9: SHOW SUCCESS, RETURN TO AUTHGATE, SIGN OUT
      // ========================================================

      // Now sign out admin.
      // AuthGate will automatically display CompanyLoginPage.
      await _auth.signOut();

      debugPrint('Admin signed out successfully');

      // Remove CreateCompanyPage and all previous routes.
      // Return to the root AuthGate.
      rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );

      debugPrint('Redirected to AuthGate');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // TEXT FIELD DECORATION
  // ============================================================

  InputDecoration _decoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      suffixIcon: suffixIcon,
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Company'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: ListView(
            children: [

              // COMPANY DETAILS
              const Text(
                'Company Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _companyName,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Company Full Name *',
                  hint: 'Enter company full name',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter company name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _companyId,
                textCapitalization: TextCapitalization.none,
                decoration: _decoration(
                  'Company ID *',
                  hint: 'Example: shotgun',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter Company ID';
                  }

                  final id = v.trim();

                  if (!RegExp(
                    r'^[a-zA-Z0-9_-]+$',
                  ).hasMatch(id)) {
                    return 'Only letters, numbers, _ and - allowed';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: _decoration(
                  'Address',
                  hint: 'Enter company address',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _state,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'State',
                  hint: 'Enter state',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _pinCode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: _decoration(
                  'Pin Code',
                  hint: 'Enter 6 digit pin code',
                ),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (!RegExp(r'^\d{6}$')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid 6 digit pin code';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Divider(),

              // SUPERVISOR DETAILS
              const Text(
                'Supervisor Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _supervisorEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  'Supervisor Email *',
                  hint: 'example@email.com',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter supervisor email';
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // SUPERVISOR PASSWORD
              TextFormField(
                controller: _supervisorPassword,
                obscureText: _obscurePassword,
                decoration: _decoration(
                  'Supervisor Password *',
                  hint: 'Minimum 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  if (_confirmPassword.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Enter supervisor password';
                  }

                  if (v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // CONFIRM PASSWORD
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscureConfirmPassword,

                decoration: _decoration(
                  'Confirm Password *',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),

                // Validate instantly while typing.
                autovalidateMode: AutovalidateMode.onUserInteraction,

                onChanged: (value) {
                  _formKey.currentState?.validate();
                },

                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Confirm supervisor password';
                  }

                  if (v != _supervisorPassword.text) {
                    return 'Passwords do not match';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 30),

              // CREATE BUTTON
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _createCompany,

                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Company',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
}
