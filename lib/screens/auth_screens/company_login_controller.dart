import 'dart:async';
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

  int _failedAttempts = 0;
  DateTime? _lockUntil;

  CompanyLoginController() {
    _loadSafeCache();
  }

  /* ---------------- SAFE CACHE ---------------- */

  Future<void> _loadSafeCache() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      companyController.text = prefs.getString('company') ?? '';
      emailController.text = prefs.getString('email') ?? '';
    }

    notifyListeners();
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  /* ---------------- SECURITY CORE ---------------- */

  Future<void> login() async {
    // 🔐 Brute-force protection
    if (_lockUntil != null &&
        DateTime.now().isBefore(_lockUntil!)) {
      throw Exception(
        'Too many attempts. Try again later.',
      );
    }

    isLoading = true;
    notifyListeners();

    try {
      // 1️⃣ Authenticate FIRST (never trust company before auth)
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      debugPrint('USER UID: ${FirebaseAuth.instance.currentUser?.uid}');

      final user = credential.user!;
      final prefs = await SharedPreferences.getInstance();

      // 2️⃣ Resolve company AFTER auth
      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('name', isEqualTo: companyController.text.trim())
          .limit(1)
          .get();

      if (companySnapshot.docs.isEmpty) {
        await FirebaseAuth.instance.signOut();
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
        await FirebaseAuth.instance.signOut();
        throw Exception('User not authorized for this company');
      }

      // 4️⃣ Save NON-SENSITIVE cache only
      if (rememberMe) {
        await prefs.setString('company', companyController.text.trim());
        await prefs.setString('email', emailController.text.trim());
        await prefs.setBool('rememberMe', true);
        await prefs.setString('cachedCompanyId', companyId);
      } else {
        await prefs.clear();
      }

      // Reset brute-force counter
      _failedAttempts = 0;
      _lockUntil = null;
    } on FirebaseAuthException catch (e) {
      _registerFailure();
      throw Exception(_mapAuthError(e));
    } catch (e) {
      _registerFailure();
      throw Exception(e.toString());
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _registerFailure() {
    _failedAttempts++;

    if (_failedAttempts >= 5) {
      _lockUntil = DateTime.now().add(const Duration(minutes: 5));
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Try later.';
      default:
        return 'Login failed';
    }
  }

  @override
  void dispose() {
    companyController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
