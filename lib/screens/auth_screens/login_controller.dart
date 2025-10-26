import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginController extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool rememberMe = false;
  bool isLoaded = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final int sessionDuration = 24; // hours
  Timer? _sessionTimer; // 🟢 session timer
  VoidCallback? onSessionExpired; // 🟢 optional callback for auto-logout

  LoginController({this.onSessionExpired}) {
    _loadSavedCredentials();
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    emailController.text = prefs.getString('email') ?? '';
    passwordController.text = prefs.getString('password') ?? '';
    rememberMe = prefs.getBool('rememberMe') ?? false;

    final sessionTimestamp = prefs.getInt('sessionTimestamp');
    if (sessionTimestamp != null) {
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);

      // 🟢 Start session timer if still valid
      if (DateTime.now().isBefore(expiry)) {
        _startSessionTimer(expiry);
      } else {
        await logout(clearCredentials: true);
      }
    }

    isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveSession(String role) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString('email', emailController.text);
      await prefs.setString('password', passwordController.text);
      await prefs.setBool('rememberMe', true);
    }

    final expiry = DateTime.now().add(Duration(hours: sessionDuration));
    await prefs.setInt('sessionTimestamp', expiry.millisecondsSinceEpoch);
    await prefs.setString('role', role);

    // 🟢 Start or restart session timer
    _startSessionTimer(expiry);
  }

  // 🟢 Start session timer to auto-logout when time is up
  void _startSessionTimer(DateTime expiry) {
    _sessionTimer?.cancel();
    final duration = expiry.difference(DateTime.now());
    _sessionTimer = Timer(duration, () async {
      await logout();
      onSessionExpired?.call(); // notify listener (e.g., show dialog)
    });
  }

  Future<String> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc =
          await _firestore.collection('users').doc(credential.user!.uid).get();

      if (!userDoc.exists) throw Exception('User role not found');

      final role = userDoc.data()?['role'] ?? 'staff';
      await _saveSession(role);
      return role;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseError(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logout({bool clearCredentials = false}) async {
    await _auth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionTimestamp');
    await prefs.remove('role');

    if (clearCredentials || !rememberMe) {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }

    _sessionTimer?.cancel();
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found for that email.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        default:
          throw Exception('Failed to send reset email. Please try again.');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  String _getFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('sessionTimestamp');
    if (timestamp == null) return null;

    final expiry = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().isAfter(expiry)) return null;

    return prefs.getString('role');
  }
}
