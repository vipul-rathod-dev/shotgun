// File: auth_service.dart
// Purpose: Firebase authentication wrapper

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shotgun/core/constants/user_role.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Future<User> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  Future<UserRole> getUserRole(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final roleString = doc['role'] as String;
    return UserRoleX.fromString(roleString);
  }


  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  static User? get currentUser => _auth.currentUser;
}
