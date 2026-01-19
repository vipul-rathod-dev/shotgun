import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginController extends ChangeNotifier {
  // UI Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  LoginController() {
    _init();
  }

  // -------------------- INIT --------------------

  Future<void> _init() async {
    await _loadRememberedEmail();
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        // User logged out or token revoked
        notifyListeners();
      }
    });
  }

  // -------------------- REMEMBER EMAIL ONLY --------------------

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    emailController.text = prefs.getString('email') ?? '';
    rememberMe = prefs.getBool('rememberMe') ?? false;
    notifyListeners();
  }

  Future<void> _persistEmailIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString('email', emailController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.setBool('rememberMe', false);
    }
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  // -------------------- AUTH --------------------

  Future<String> login() async {
    isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final role = await _fetchUserRole(credential.user!.uid);
      await _persistEmailIfNeeded();

      return role;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // -------------------- ROLE --------------------

  Future<String> _fetchUserRole(String uid) async {
    final snapshot =
        await _firestore.collection('users').doc(uid).get();

    if (!snapshot.exists) {
      throw Exception('User role not found');
    }

    return snapshot.data()?['role'] ?? 'staff';
  }

  static Future<String?> getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data()?['role'];
  }

  // -------------------- PASSWORD RESET --------------------

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    }
  }

  // -------------------- ERROR HANDLING --------------------

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // -------------------- CLEANUP --------------------

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }
}
