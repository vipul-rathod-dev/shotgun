// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/widgets/session_aware_page.dart';
import 'models/dashboard_item.dart';
import 'models/fab_menu_item_model.dart';
import 'widgets/dashboard_card.dart';
import 'widgets/fab_menu.dart';
import 'widgets/supervisor_drawer.dart';

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
      DashboardItem(icon: Icons.production_quantity_limits, title: 'Manage Products', route: '/supervisor/products'),
      DashboardItem(icon: Icons.people_outline, title: 'Manage Suppliers', route: '/supervisor/suppliers'),
      DashboardItem(icon: Icons.bar_chart, title: 'Manage Orders', route: '/supervisor/orders'),
      DashboardItem(icon: Icons.badge_outlined, title: 'Manage Staff', route: '/supervisor/view-staff'),
    ];

    final fabItems = [
      FabMenuItem(
        icon: Icons.palette,
        label: 'Add Focus Colour',
        onTap: () => Navigator.pushNamed(context, '/supervisor/add-focus-color'),
      ),
      FabMenuItem(
        icon: Icons.brush,
        label: 'Add Temple Colour',
        onTap: () => Navigator.pushNamed(context, '/supervisor/add-temple-color'),
      ),
      FabMenuItem(
        icon: Icons.add_box,
        label: 'Execute Order',
        onTap: () => Navigator.pushNamed(context, '/supervisor/execute-order'),
      ),
    ];

    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Supervisor';

    return SessionAwarePage(
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FB),
        drawer: SupervisorDrawer(userEmail: userEmail),
        appBar: _buildAppBar(context),
        bottomNavigationBar: _buildFooter(),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              _buildDashboardCards(context, dashboardItems),
              const Spacer(),
            ],
          ),
        ),
        floatingActionButton: FabMenu(
          isMenuOpen: _isMenuOpen,
          animationController: _animationController,
          toggleMenu: _toggleMenu,
          items: fabItems,
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
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) async {
            if (value == 'logout') {
              final confirm = await _showLogoutDialog(context);
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/company-login');
              }
            }
          },
          itemBuilder: (context) => const [PopupMenuItem(value: 'logout', child: Text('Logout'))],
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDashboardCards(BuildContext context, List<DashboardItem> items) {
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: DashboardCard(
                      icon: item.icon,
                      title: item.title,
                      onTap: () => Navigator.pushNamed(context, item.route),
                    ),
                  ))
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
        style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
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
