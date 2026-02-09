// File: company_login_controller.dart
// Reusable: Yes

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/remember_me_service.dart';

class CompanyLoginController extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();

  final companyController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;
  bool isLoading = false;

  CompanyLoginController() {
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final data = await RememberMeService.load();
    emailController.text = data['email'] ?? '';
    companyController.text = data['company'] ?? '';
    rememberMe = data.isNotEmpty;
    notifyListeners();
  }

  void toggleRememberMe(bool? v) {
    rememberMe = v ?? false;
    if (!rememberMe) {
      RememberMeService.clear();
    }
    notifyListeners();
  }

  Future<void> login(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    notifyListeners();

    try {
      final user = await AuthService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // 2️⃣ Resolve company AFTER auth
      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('name', isEqualTo: companyController.text.toString().trim())
          .limit(1)
          .get();
      if (companySnapshot.docs.isEmpty) {
        await AuthService.logout();
        throw Exception('Invalid company');
      }

      final companyId = companySnapshot.docs.first.id;

      // 3️⃣ Verify user belongs to this company
      final companyUserDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!companyUserDoc.exists) {
        await AuthService.logout();
        throw Exception('User not authorized for this company');
      }

      if (rememberMe) {
        await RememberMeService.save(
          company: companyController.text,
          email: emailController.text.trim(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      print("Company ID: ${companyId}");
      await prefs.setString('cachedCompanyId', companyId);

      // ✅ ROLE-BASED NAVIGATION (SAME AS ADMIN)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );

    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Future<void> login() async {
  //   if (!formKey.currentState!.validate()) return;

  //   isLoading = true;
  //   notifyListeners();

  //   try {
  //     final user = await AuthService.login(
  //       email: emailController.text.trim(),
  //       password: passwordController.text,
  //     );

  //     final companySnap = await FirebaseFirestore.instance
  //         .collection('companies')
  //         .where('name', isEqualTo: companyController.text.trim())
  //         .limit(1)
  //         .get();

  //     if (companySnap.docs.isEmpty) {
  //       throw Exception('Invalid company');
  //     }

  //     final companyId = companySnap.docs.first.id;

  //     final userDoc = await FirebaseFirestore.instance
  //         .collection('companies')
  //         .doc(companyId)
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();

  //     if (!userDoc.exists) {
  //       throw Exception('Not part of this company');
  //     }

  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setString('cachedCompanyId', companyId);

  //     if (rememberMe) {
  //       await RememberMeService.save(
  //         email: emailController.text.trim(),
  //         company: companyController.text.trim(),
  //       );
  //     } else {
  //       await RememberMeService.clear();
  //     }
  //   } finally {
  //     isLoading = false;
  //     notifyListeners();
  //   }
  // }

}
