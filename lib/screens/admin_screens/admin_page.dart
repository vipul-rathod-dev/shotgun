// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardItems = [
      {
        'icon': Icons.production_quantity_limits,
        'title': 'Manage Products',
        'route': '/admin/products',
      },
      {
        'icon': Icons.people_outline,
        'title': 'Manage Suppliers',
        'route': '/admin/suppliers',
      },
      {
        'icon': Icons.bar_chart,
        'title': 'Manage Orders',
        'route': '/admin/orders',
      },
    ];
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ✅ DRAWER MENU
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.lightBlue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Menu', style: TextStyle(color: Colors.white, fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Manage Products'),
              selected: ModalRoute.of(context)?.settings.name == '/admin/products',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/products');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Manage Suppliers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/suppliers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Manage Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/orders');
              },
            ),
          ],
        ),
      ),

      // ✅ APP BAR
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              } else if (value == 'settings') {
                // Navigate to settings
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
      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.lightBlue.shade50,
            child: const Text(
              'Welcome Admin!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 10),

          // DASHBOARD GRID CARDS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                children: dashboardItems.map((item) {
                  return _DashboardCard(
                    icon: item['icon'] as IconData,
                    title: item['title'] as String,
                    onTap: () => Navigator.pushNamed(context, item['route'] as String),
                  );
                }).toList(),
              ),
            ),
          ),

          // FOOTER
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade300,
            child: const Text(
              "© 2025 A1Specto Admin Panel • v1.0",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.lightBlue),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}