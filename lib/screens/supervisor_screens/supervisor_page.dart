// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/widgets/session_aware_page.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DashboardItem> dashboardItems = const [
      DashboardItem(
        icon: Icons.production_quantity_limits,
        title: 'Manage Products',
        route: '/supervisor/products',
      ),
      DashboardItem(
        icon: Icons.people_outline,
        title: 'Manage Suppliers',
        route: '/supervisor/suppliers',
      ),
      DashboardItem(
        icon: Icons.bar_chart,
        title: 'Manage Orders',
        route: '/supervisor/orders',
      ),
      DashboardItem(
        icon: Icons.badge_outlined,
        title: 'Manage Staff',
        route: '/supervisor/view-staff',
      ),
    ];

    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Supervisor';

    return SessionAwarePage(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,

        // ✅ DRAWER MENU
        drawer: _buildDrawer(context, userEmail),

        // ✅ APP BAR
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.lightBlue,
          title: const Text(
            'Supervisor Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  final confirm = await _showLogoutDialog(context);
                  if (confirm == true) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/company-login');
                  }
                } else if (value == 'settings') {
                  // Navigate to settings page
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            ),
          ],
        ),

        // ✅ MAIN BODY
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),

              // GRID SECTION
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1,
                    ),
                    itemCount: dashboardItems.length,
                    itemBuilder: (context, index) {
                      final item = dashboardItems[index];
                      return _DashboardCard(
                        icon: item.icon,
                        title: item.title,
                        onTap: () => Navigator.pushNamed(context, item.route),
                      );
                    },
                  ),
                ),
              ),

              // FOOTER
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade200,
                child: const Text(
                  "© 2025 Supervisor Panel • v1.0",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Drawer
  Widget _buildDrawer(BuildContext context, String userEmail) {
    bool isActive(String route) =>
        ModalRoute.of(context)?.settings.name == route;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlueAccent, Colors.lightBlue],
              ),
            ),
            accountName: const Text(
              "Supervisor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.lightBlue, size: 36),
            ),
          ),
          _drawerItem(context, Icons.inventory_2_outlined, 'Manage Products',
              '/supervisor/products', isActive),
          _drawerItem(context, Icons.people_outline, 'Manage Suppliers',
              '/supervisor/suppliers', isActive),
          _drawerItem(context, Icons.bar_chart, 'Manage Orders',
              '/supervisor/orders', isActive),
          _drawerItem(context, Icons.badge_outlined, 'Manage Staff',
              '/supervisor/view-staff', isActive),
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
      leading: Icon(icon,
          color: active ? Colors.lightBlue : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: active ? Colors.lightBlue.shade700 : Colors.black87,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      tileColor: active ? Colors.lightBlue.shade50 : null,
      onTap: () {
        Navigator.pop(context);
        if (!active) Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  // 🔹 Header
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.lightBlue.shade100, Colors.lightBlue.shade50],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.shade100,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.dashboard_rounded, color: Colors.lightBlue, size: 30),
          SizedBox(width: 10),
          Text(
            'Welcome, Supervisor!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Logout confirmation dialog
  static Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? Colors.lightBlue.shade100.withOpacity(0.6)
                  : Colors.grey.shade200,
              blurRadius: _hovered ? 12 : 6,
              offset: Offset(0, _hovered ? 4 : 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon,
                    size: 45,
                    color: _hovered ? Colors.lightBlue : Colors.lightBlueAccent),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔹 Dashboard Item Model
class DashboardItem {
  final IconData icon;
  final String title;
  final String route;

  const DashboardItem({
    required this.icon,
    required this.title,
    required this.route,
  });
}
