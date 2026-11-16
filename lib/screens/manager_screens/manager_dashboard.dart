
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shotgun/screens/supervisor_screens/supervisor-dashboard-details.dart';
import 'package:shotgun/screens/supervisor_screens/models/dashboard_item.dart';
import 'package:shotgun/screens/supervisor_screens/models/fab_menu_item_model.dart';
import 'package:shotgun/screens/supervisor_screens/widgets/dashboard_card.dart';
import 'package:shotgun/screens/supervisor_screens/widgets/fab_menu.dart';

import 'widgets/manager_drawer.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
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
    final userEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Manager';

    final List<DashboardItem> dashboardItems = const [
      DashboardItem(
        icon: Icons.inventory_2_outlined,
        title: 'Raw Product Orders',
        route: '/manager/raw-product-orders',
      ),
      DashboardItem(
        icon: Icons.bar_chart,
        title: 'Manage Orders',
        route: '/manager/orders',
      ),
      DashboardItem(
        icon: Icons.production_quantity_limits,
        title: 'Manage Products',
        route: '/manager/products',
      ),
      DashboardItem(
        icon: Icons.inventory_2_rounded,
        title: 'Manage Tasks',
        route: '/manager/tasks',
      ),
      DashboardItem(
        icon: Icons.person_outline,
        title: 'Manage Customers',
        route: '/manager/customers',
      ),
      DashboardItem(
        icon: Icons.people_outline,
        title: 'Manage Suppliers',
        route: '/manager/suppliers',
      ),
      DashboardItem(
        icon: Icons.palette_outlined,
        title: 'Color Templates',
        route: '/manager/color-templates',
      ),
      DashboardItem(
        icon: Icons.inventory_2_rounded,
        title: 'Manage Inventory',
        route: '/manager/manage-inventory',
      ),
    ];

    final fabItems = [
      FabMenuItem(
        icon: Icons.palette,
        label: 'Add Focus Colour',
        onTap: () {
          Navigator.pushNamed(
            context,
            '/manager/add-focus-color',
          );
        },
      ),
      FabMenuItem(
        icon: Icons.brush,
        label: 'Add Temple Colour',
        onTap: () {
          Navigator.pushNamed(
            context,
            '/manager/add-temple-color',
          );
        },
      ),
      FabMenuItem(
        icon: Icons.add_box,
        label: 'Execute Order',
        onTap: () {
          Navigator.pushNamed(
            context,
            '/manager/execute-order',
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      drawer: ManagerDrawer(userEmail: userEmail),

      appBar: _buildAppBar(context),

      body: SafeArea(
        child: _buildDashboardContent(
          context,
          dashboardItems,
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

  // ------------------------------------------------------------
  // APP BAR
  // ------------------------------------------------------------

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: true,
      elevation: 4,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1976D2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      title: const Text(
        'Manager Dashboard',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
      centerTitle: true,
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

                if (!context.mounted) return;

                final prefs =
                    await SharedPreferences.getInstance();

                await prefs.remove('cachedCompanyId');
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD CONTENT
  // ------------------------------------------------------------

  Widget _buildDashboardContent(
    BuildContext context,
    List<DashboardItem> items,
  ) {
    final width = MediaQuery.sizeOf(context).width;

    final bool isSmallMobile = width < 400;
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1100;
    final bool isDesktop = width >= 1100;

    final int crossAxisCount;

    if (width < 600) {
      crossAxisCount = 2;
    } else if (width < 1100) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    final double horizontalPadding;

    if (isSmallMobile) {
      horizontalPadding = 10;
    } else if (isMobile) {
      horizontalPadding = 14;
    } else if (isTablet) {
      horizontalPadding = 24;
    } else {
      horizontalPadding = 32;
    }

    final double verticalPadding = isMobile ? 16 : 24;

    final double gridSpacing = isSmallMobile
        ? 10
        : isMobile
            ? 12
            : isTablet
                ? 16
                : 20;

    final double cardAspectRatio = isSmallMobile
        ? 1.05
        : isMobile
            ? 1.10
            : isTablet
                ? 1.15
                : 1.20;

    final double headingSize = isSmallMobile
        ? 20
        : isMobile
            ? 22
            : 25;

    final double maxContentWidth =
        isDesktop ? 1400 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontSize: headingSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A237E),
                    ),
              ),

              SizedBox(
                height: isSmallMobile ? 5 : 8,
              ),

              Text(
                'What would you like to manage today?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      fontSize: isSmallMobile ? 12 : 14,
                      color: Colors.grey[700],
                    ),
              ),

              SizedBox(
                height: isSmallMobile ? 18 : 26,
              ),

              const SupervisorDashboardDetails(),

              const SizedBox(height: 20),

              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: isMobile ? 90 : 100,
                  ),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpacing,
                    mainAxisSpacing: gridSpacing,
                    childAspectRatio: cardAspectRatio,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return TweenAnimationBuilder<double>(
                      duration: Duration(
                        milliseconds: 300 + (index * 80),
                      ),
                      tween: Tween(
                        begin: 0,
                        end: 1,
                      ),
                      builder: (
                        context,
                        value,
                        child,
                      ) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              20 * (1 - value),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            isSmallMobile ? 14 : 18,
                          ),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFE3F2FD),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withOpacity(
                                0.10,
                              ),
                              blurRadius: isMobile ? 8 : 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: DashboardCard(
                          icon: item.icon,
                          title: item.title,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              item.route,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FOOTER
  // ------------------------------------------------------------

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFE8EDF4),
      child: const Text(
        '© 2026 Manager Panel • v1.0',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGOUT DIALOG
  // ------------------------------------------------------------

  static Future<bool?> _showLogoutDialog(
    BuildContext context,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
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
