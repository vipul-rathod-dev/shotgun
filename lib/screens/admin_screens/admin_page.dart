import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ✅ DRAWER MENU
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.lightBlue),
              child: Text(
                'Admin Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Manage Products'),
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
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushReplacementNamed(context, '/login');
              } else if (value == 'products') {
                Navigator.pushNamed(context, '/admin/products');
              } else if (value == 'suppliers') {
                Navigator.pushNamed(context, '/admin/suppliers');
              } else if (value == 'settings') {
                // Navigate to settings
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'products',
                child: Text('Manage Products'),
              ),
              const PopupMenuItem(
                value: 'suppliers',
                child: Text('Manage Suppliers'),
              ),
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
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _DashboardCard(
                    icon: Icons.person,
                    title: "Manage Users",
                    onTap: () {
                      // TODO: Navigate to user management page
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.analytics,
                    title: "View Reports",
                    onTap: () {
                      // TODO: Navigate to reports page
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.people_outline,
                    title: "Manage Suppliers",
                    onTap: () {
                      Navigator.pushNamed(context, '/admin/suppliers');
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.settings,
                    title: "Settings",
                    onTap: () {
                      // TODO: Navigate to settings
                    },
                  ),
                ],
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