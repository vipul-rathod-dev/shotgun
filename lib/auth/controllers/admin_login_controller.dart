// File: admin_login_controller.dart
// Reusable: Yes

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shotgun/core/constants/user_role.dart';
import '../services/auth_service.dart';
import '../services/remember_me_service.dart';

class AdminLoginController extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;
  bool isLoading = false;

  AdminLoginController() {
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final data = await RememberMeService.load();
    emailController.text = data['email'] ?? '';
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

  Future<void> resetPassword(String email) async {
    await AuthService.resetPassword(email.trim());
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

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        throw Exception('User record not found');
      }

      final roleString = doc.data()?['role'];

      if (roleString != 'admin') {
        throw Exception('Not an admin account');
      }

      // ✅ CONVERT STRING → ENUM
      final role = UserRoleX.fromString(roleString);

      if (rememberMe) {
        await RememberMeService.save(
          email: emailController.text.trim(),
        );
      }

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

  //     final doc = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();

  //     if (!doc.exists || doc.data()?['role'] != 'admin') {
  //       throw Exception('Not an admin account');
  //     }

  //     if (rememberMe) {
  //       await RememberMeService.save(
  //         email: emailController.text.trim(),
  //       );
  //     }
  //   } finally {
  //     isLoading = false;
  //     notifyListeners();
  //   }
  // }

}
