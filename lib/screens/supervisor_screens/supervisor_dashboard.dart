// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/core/constants/app_colors.dart';
import 'package:shotgun/utils/firestore_scripts.dart';
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
  bool _isRunningScript = false;

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
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Supervisor';

    final List<DashboardItem> dashboardItems = const [
      DashboardItem(
        icon: Icons.inventory_2_rounded,
        title: 'Manage Tasks',
        route: '/supervisor/tasks',
      ),
      DashboardItem(
        icon: Icons.production_quantity_limits,
        title: 'Manage Products',
        route: '/supervisor/products',
      ),
      DashboardItem(
        icon: Icons.person_outline,
        title: 'Manage Customers',
        route: '/supervisor/customers',
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
        icon: Icons.palette_outlined,
        title: 'Color Templates',
        route: '/supervisor/color-templates',
      ),
      DashboardItem(
        icon: Icons.inventory_2_rounded,
        title: 'Manage Inventory',
        route: '/supervisor/view-inventory',
      ),
      DashboardItem(
        icon: Icons.badge_outlined,
        title: 'Manage Staff',
        route: '/supervisor/view-staff',
      ),
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

    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: SupervisorDrawer(userEmail: userEmail),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: Stack(
            children: [
              _buildDashboardContent(context, dashboardItems),
              if (_isRunningScript)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 12),
                        Text(
                          "Running update script...",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FabMenu(
          isMenuOpen: _isMenuOpen,
          animationController: _animationController,
          toggleMenu: _toggleMenu,
          items: fabItems,
        ),
        bottomNavigationBar: _buildFooter(),
      );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Supervisor Dashboard',
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'logout') {
              final confirm = await _showLogoutDialog(context);
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
              }
            } else if (value == 'run_script') {
              await _showRunScriptDialog(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'run_script',
              child: Text(
                'Run Update Script',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Text(
                'Logout',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<DashboardItem> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200
        ? 4
        : screenWidth > 800
            ? 3
            : 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome back 👋",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "What would you like to manage today?",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            )
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.1,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 120)),
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: DashboardCard(
                      icon: item.icon,
                      title: item.title,
                      onTap: () {
                        if (_isMenuOpen) {
                          _animationController.reverse();
                          setState(() => _isMenuOpen = false);
                        }

                        if (Scaffold.of(context).isDrawerOpen) {
                          Navigator.pop(context);
                        }

                        Navigator.pushNamed(context, item.route);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFE8EDF4),
      child: Text(
        "© 2025 Supervisor Panel • v1.5",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Logout',
              style: Theme.of(context).textTheme.titleMedium,
            )
          ),
        ],
      ),
    );
  }

  Future<void> _showRunScriptDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Run Firestore Update Script',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 14),
            Text(
              'This will add or update the “stock” field in all finished products. Proceed?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Run'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRunningScript = true);
    try {
      await FirestoreScripts.addFieldToFinishedCategory(
        subCollectionName: 'products',
        fieldName: 'stock',
        value: 0,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Text('Script completed successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Text('Error: $e'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => _isRunningScript = false);
    }
  }
}
