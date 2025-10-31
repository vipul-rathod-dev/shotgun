// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/widgets/session_aware_page.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard>
    with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

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
        backgroundColor: const Color(0xFFF3F6FB),
        drawer: _buildDrawer(context, userEmail),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              _buildDashboardCards(context, dashboardItems),
              const Spacer(),
              _buildFooter(),
            ],
          ),
        ),

        // 🔹 Floating Action Button Menu
        floatingActionButton: Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (_isMenuOpen)
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black54.withOpacity(0.4),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _isMenuOpen ? 140 : 80,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isMenuOpen ? 1 : 0,
                child: _buildFabMenuButton(
                  icon: Icons.add_box_outlined,
                  label: "Add Focus Colour",
                  onTap: () {
                    _toggleMenu();
                    Navigator.pushNamed(context, '/supervisor/add-focus-color');
                  },
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _isMenuOpen ? 80 : 80,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isMenuOpen ? 1 : 0,
                child: _buildFabMenuButton(
                  icon: Icons.add_box_outlined,
                  label: "Add Temple Colour",
                  onTap: () {
                    _toggleMenu();
                    Navigator.pushNamed(context, '/supervisor/add-temple-color');
                  },
                ),
              ),
            ),
            FloatingActionButton(
              backgroundColor: const Color(0xFF1565C0),
              onPressed: _toggleMenu,
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _animationController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Floating Submenu Button
  Widget _buildFabMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 3,
      backgroundColor: const Color(0xFF1565C0),
      title: const Text(
        'Supervisor Dashboard',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      shadowColor: Colors.blueAccent.withOpacity(0.4),
      actions: [
        PopupMenuButton<String>(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) async {
            if (value == 'logout') {
              final confirm = await _showLogoutDialog(context);
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/company-login');
              }
            }
          },
          itemBuilder: (BuildContext context) =>
              const [PopupMenuItem(value: 'logout', child: Text('Logout'))],
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDashboardCards(
      BuildContext context, List<DashboardItem> items) {
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _DashboardCard(
                    icon: item.icon,
                    title: item.title,
                    onTap: () => Navigator.pushNamed(context, item.route),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFE8EDF4),
      child: const Text(
        "© 2025 Supervisor Panel • v1.2",
        style: TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Drawer & other methods are same as before
  Drawer _buildDrawer(BuildContext context, String userEmail) {
    bool isActive(String route) =>
        ModalRoute.of(context)?.settings.name == route;

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
            accountName: const Text(
              "Supervisor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF1565C0), size: 36),
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
      leading: Icon(
        icon,
        color: active ? const Color(0xFF1565C0) : Colors.grey.shade700,
      ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
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

// 🔹 Dashboard Card (same as before)
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

class _DashboardCardState extends State<_DashboardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hovered
                  ? [const Color(0xFF42A5F5), const Color(0xFF1565C0)]
                  : [Colors.white, Colors.grey.shade100],
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? Colors.blueAccent.withOpacity(0.35)
                    : Colors.grey.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 46,
                  color: _hovered ? Colors.white : const Color(0xFF1565C0),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.white : Colors.black87,
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

// Model
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
