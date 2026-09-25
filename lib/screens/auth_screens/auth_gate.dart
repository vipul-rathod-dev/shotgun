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
    final user = FirebaseAuth.instance.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');

    if (companyId == null) {
      throw Exception('Company not selected');
    }

    final doc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      throw Exception('User not found in company');
    }

    final role = doc.data()?['role'];
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
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        switch (snapshot.data) {
          case 'admin':
            return const AdminDashboard();
          case 'supervisor':
            return const SupervisorDashboard();
          default:
            return const StaffDashboard();
        }
      },
    );
  }
}
