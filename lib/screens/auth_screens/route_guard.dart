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
        body: Center(child: Text('Not authenticated')),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveRole(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data != requiredRole) {
          return const Scaffold(
            body: Center(child: Text('Access Denied')),
          );
        }

        return child;
      },
    );
  }

  Future<String?> _resolveRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');
    if (companyId == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    return doc.exists ? doc.data()!['role'] : null;
  }
}
