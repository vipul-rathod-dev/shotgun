import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SupervisorDrawer extends StatelessWidget {
  final String userEmail;
  const SupervisorDrawer({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    bool isActive(String route) => ModalRoute.of(context)?.settings.name == route;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text("Supervisor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(userEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF1565C0), size: 36),
            ),
          ),
          _drawerItem(context, Icons.inventory_2_outlined, 'Manage Products', '/supervisor/products', isActive),
          _drawerItem(context, Icons.people_outline, 'Manage Suppliers', '/supervisor/suppliers', isActive),
          _drawerItem(context, Icons.bar_chart, 'Manage Orders', '/supervisor/orders', isActive),
          _drawerItem(context, Icons.badge_outlined, 'Manage Staff', '/supervisor/view-staff', isActive),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout'),
            onTap: () async {
              final confirm = await _showLogoutDialog(context);
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/company-login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
    bool Function(String) isActive,
  ) {
    final active = isActive(route);
    return ListTile(
      leading: Icon(icon, color: active ? const Color(0xFF1565C0) : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: active ? const Color(0xFF1565C0) : Colors.black87,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      tileColor: active ? const Color(0xFFE3F2FD) : null,
      onTap: () {
        Navigator.pop(context);
        if (!active) Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  static Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
