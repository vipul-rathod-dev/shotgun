import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleGuard extends StatelessWidget {
  final String requiredRole;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Not authenticated'),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveRole(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error checking permissions:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final role = snapshot.data;

        if (role == null) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to determine user role'),
            ),
          );
        }

        if (role != requiredRole) {
          return const Scaffold(
            body: Center(
              child: Text('Access Denied'),
            ),
          );
        }

        return child;
      },
    );
  }

  Future<String?> _resolveRole(String uid) async {
    final firestore = FirebaseFirestore.instance;

    // --------------------------------------------------
    // ADMIN
    // --------------------------------------------------
    if (requiredRole == 'admin') {
      final adminDoc = await firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        return null;
      }

      final role = adminDoc.data()?['role'];

      return role as String?;
    }

    // --------------------------------------------------
    // COMPANY USER
    // --------------------------------------------------
    final prefs = await SharedPreferences.getInstance();

    final companyId = prefs.getString('cachedCompanyId');

    if (companyId == null || companyId.isEmpty) {
      debugPrint('No cachedCompanyId found');
      return null;
    }

    final userDoc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      return null;
    }

    final role = userDoc.data()?['role'];

    return role as String?;
  }
}