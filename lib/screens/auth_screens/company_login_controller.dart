import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyLoginController extends ChangeNotifier {
  final companyController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool rememberMe = false;

  CompanyLoginController() {
    _loadSavedCredentials();
  }

  // 🔹 Load cached credentials and companyId
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      companyController.text = prefs.getString('company') ?? '';
      emailController.text = prefs.getString('email') ?? '';
      passwordController.text = prefs.getString('password') ?? '';
    }

    final cachedCompanyId = prefs.getString('cachedCompanyId');
    if (cachedCompanyId != null && cachedCompanyId.isNotEmpty) {
      debugPrint('✅ Cached companyId loaded: $cachedCompanyId');
    }

    notifyListeners();
  }

  // 🔹 Save credentials + companyId if Remember Me enabled
  Future<void> _saveCredentials({String? companyId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('company', companyController.text.trim());
      await prefs.setString('email', emailController.text.trim());
      await prefs.setString('password', passwordController.text.trim());
      await prefs.setBool('rememberMe', true);
      if (companyId != null) {
        await prefs.setString('cachedCompanyId', companyId);
      }
    } else {
      await prefs.remove('company');
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  // 🔹 Optimized login with cached companyId
  Future<String> login(String company, String email, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try cached companyId first
      String? companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.isEmpty) {
        // Fetch from Firestore if not cached
        final companySnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .where('name', isEqualTo: company)
            .limit(1)
            .get();

        if (companySnapshot.docs.isEmpty) {
          throw Exception("Company not found");
        }

        companyId = companySnapshot.docs.first.id;

        // Cache it
        await prefs.setString('cachedCompanyId', companyId);
      }

      // Sign in
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user!;
      await _saveCredentials(companyId: companyId);

      // 🔹 Fetch from company namespace
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(user.uid)
          .get();

      // 🔹 Fallback to global users if not found
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      }

      final role = userDoc.data()?['role'] ?? 'staff';
      return role;
    } catch (e) {
      throw Exception("Login failed: ${e.toString()}");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
