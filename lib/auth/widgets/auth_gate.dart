import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/auth/widgets/session_watcher.dart';
import 'package:shotgun/screens/admin_screens/admin_page.dart';
import 'package:shotgun/screens/auth_screens/company_login_page.dart';
import 'package:shotgun/screens/auth_screens/admin_login_page.dart';
import 'package:shotgun/screens/staff_screens/staff_dashboard.dart';
import 'package:shotgun/screens/supervisor_screens/supervisor_dashboard.dart';
import 'package:shotgun/utils/logout_helper.dart';


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
    final user = FirebaseAuth.instance.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('cachedCompanyId');

    // 🔹 First: check global users (admin)
    final globalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (globalDoc.exists) {
      final role = (globalDoc.data()?['role'] as String?)?.toLowerCase();
      if (role != null) return role;
    }

    // 🔹 If companyId not ready yet, retry once
    if (companyId == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      final retryPrefs = await SharedPreferences.getInstance();
      companyId = retryPrefs.getString('cachedCompanyId');
    }

    if (companyId == null) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Company session expired. Please login again.');
    }

    return _resolveCompanyRole(user.uid, companyId);
  }


  Future<String> _resolveCompanyRole(String uid, String companyId) async {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(uid)
          .get();

      if (!companyDoc.exists) {
        throw Exception('User not found in company');
      }

      final role = companyDoc.data()?['role'];
      if (role == null) {
        throw Exception('Role not assigned');
      }

      return role;
    }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Access error. Please login again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await logout();
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );

        }

        switch (snapshot.data) {
          case 'admin':
            return const SessionWatcher(
              child: AdminDashboard(),
            );

          case 'supervisor':
            return const SessionWatcher(
              child: SupervisorDashboard(),
            );

          case 'staff':
          default:
            return const SessionWatcher(
              child: StaffDashboard(),
            );
        }
      },
    );
  }
}
