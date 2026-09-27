import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin_screens/admin_page.dart';
import 'company_login_page.dart';
import 'login_page.dart';
import '../staff_screens/staff_dashboard.dart';
import '../supervisor_screens/supervisor_dashboard.dart';

enum LoginMode {
  admin,
  company,
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  LoginMode _loginMode = LoginMode.company; // default

  void _switchToAdmin() {
    setState(() => _loginMode = LoginMode.admin);
  }

  void _switchToCompany() {
    setState(() => _loginMode = LoginMode.company);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not logged in → show correct login page
        if (!snapshot.hasData) {
          return _loginMode == LoginMode.admin
              ? LoginPage(onSwitchToCompany: _switchToCompany)
              : CompanyLoginPage(onSwitchToAdmin: _switchToAdmin);
        }

        // ✅ Logged in → resolve role
        return const RoleResolver();
      },
    );
  }
}

class RoleResolver extends StatelessWidget {
  const RoleResolver({super.key});

  Future<String> _getRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final firestore = FirebaseFirestore.instance;

    // ============================================================
    // 1. CHECK GLOBAL ADMIN
    // ============================================================

    final globalUserDoc = await firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (globalUserDoc.exists) {
      final globalRole = globalUserDoc
          .data()?['role']
          ?.toString()
          .trim()
          .toLowerCase();

      if (globalRole == 'admin') {
        return 'admin';
      }
    }

    // ============================================================
    // 2. FIND COMPANY USER
    // ============================================================
    //
    // Instead of relying on cachedCompanyId, search companies
    // for this Firebase UID.
    //
    // This prevents the authStateChanges() race condition.
    //

    final companiesSnapshot =
        await firestore.collection('companies').get();

    for (final companyDoc in companiesSnapshot.docs) {
      final companyUserDoc = await firestore
          .collection('companies')
          .doc(companyDoc.id)
          .collection('users')
          .doc(user.uid)
          .get();

      if (!companyUserDoc.exists) {
        continue;
      }

      final companyData = companyUserDoc.data();

      final role = companyData?['role']
          ?.toString()
          .trim()
          .toLowerCase();

      if (role == null || role.isEmpty) {
        throw Exception(
          'Your account does not have a role assigned.',
        );
      }

      if (role != 'staff' && role != 'supervisor') {
        throw Exception(
          'Invalid company role.',
        );
      }

      // ----------------------------------------------------------
      // Save the company ID after we have verified membership.
      // ----------------------------------------------------------

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'cachedCompanyId',
        companyDoc.id,
      );

      return role;
    }

    // ============================================================
    // 3. USER NOT FOUND
    // ============================================================

    throw Exception(
      'You are not associated with any company.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        // ==========================================================
        // LOADING
        // ==========================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ==========================================================
        // ERROR
        // ==========================================================

        if (snapshot.hasError) {
          final message = snapshot.error
              .toString()
              .replaceFirst('Exception: ', '');

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ==========================================================
        // ROLE
        // ==========================================================

        switch (snapshot.data) {
          case 'admin':
            return const AdminDashboard();

          case 'supervisor':
            return const SupervisorDashboard();

          case 'staff':
            return const StaffDashboard();

          default:
            return Scaffold(
              body: Center(
                child: Text(
                  'Unknown user role: ${snapshot.data}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
        }
      },
    );
  }
}