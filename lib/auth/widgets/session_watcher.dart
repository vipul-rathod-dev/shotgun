// File: session_watcher.dart
// Purpose: Global idle + session timeout watcher
// Features:
//  - Idle timeout detection
//  - Absolute session timeout
//  - "Session Expired" dialog
//  - "Extend Session" support
//  - Safe logout integration
// Reusable: Yes (Admin / Company / Staff)
// Platforms: Mobile / Web / Desktop

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shotgun/utils/logout_helper.dart';

class SessionWatcher extends StatefulWidget {
  final Widget child;
  final Duration idleTimeout;
  final Duration sessionTimeout;

  const SessionWatcher({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 15),
    this.sessionTimeout = const Duration(hours: 8),
  });

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  Timer? _idleTimer;
  Timer? _sessionTimer;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
    _startSessionTimer();
  }

  /* ---------------- TIMERS ---------------- */

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.idleTimeout, _showSessionDialog);
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(widget.sessionTimeout, _showSessionDialog);
  }

  /* ---------------- USER ACTIVITY ---------------- */

  void _onUserActivity() {
    if (_dialogVisible) return;
    _resetIdleTimer();
  }

  /* ---------------- DIALOG ---------------- */

  Future<void> _showSessionDialog() async {
    if (!mounted || _dialogVisible) return;
    _dialogVisible = true;

    final extend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Expiring'),
        content: const Text(
          'Your session is about to expire due to inactivity.\n\n'
          'Would you like to extend your session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Logout'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Extend Session'),
          ),
        ],
      ),
    );

    _dialogVisible = false;

    if (extend == true) {
      _extendSession();
    } else {
      await logout(); // 🔐 SAFE LOGOUT
    }
  }

  /* ---------------- EXTEND SESSION ---------------- */

  void _extendSession() {
    _resetIdleTimer();
    _startSessionTimer();
  }

  /* ---------------- CLEANUP ---------------- */

  @override
  void dispose() {
    _idleTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent, 
      onPointerDown: (_) => _onUserActivity(),
      onPointerMove: (_) => _onUserActivity(),
      onPointerSignal: (_) => _onUserActivity(),
      child: widget.child,
    );
  }
}
