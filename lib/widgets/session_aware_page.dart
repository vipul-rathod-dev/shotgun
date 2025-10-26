import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/auth_screens/login_controller.dart';

class SessionAwarePage extends StatelessWidget {
  final Widget child;
  const SessionAwarePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(
        onSessionExpired: () => _handleSessionExpired(context),
      ),
      child: child,
    );
  }

  void _handleSessionExpired(BuildContext context) async {
    // Prevent multiple dialogs
    if (ModalRoute.of(context)?.isCurrent == false) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
