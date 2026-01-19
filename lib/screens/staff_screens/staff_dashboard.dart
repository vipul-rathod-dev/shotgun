import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/models/dashboard_item.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String fullName = '';
  bool isLoading = true;

  final List<DashboardItem> dashboardItems = [
    DashboardItem(
      icon: Icons.task_alt_rounded,
      title: 'Assigned Tasks',
      route: '/staff/tasks',
    ),
    DashboardItem(
      icon: Icons.play_circle_fill_rounded,
      title: 'Execute Process',
      route: '/staff/process',
    ),
  ];

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName({bool forceRefresh = false}) async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final prefs = await SharedPreferences.getInstance();

      // Use cached displayName unless forceRefresh requested
      if (!forceRefresh) {
        final cached = prefs.getString('cachedDisplayName');
        if (cached != null && cached.trim().isNotEmpty) {
          if (!mounted) return;
          setState(() {
            fullName = cached;
            isLoading = false;
          });
          return;
        }
      }

      final companyId = prefs.getString('cachedCompanyId');

      String displayName = user.displayName?.trim() ?? '';

      if (companyId != null && companyId.trim().isNotEmpty) {
        // Try company namespace fetch
        final userDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          final nameFromDoc = (data?['name'] ?? '').toString().trim();
          if (nameFromDoc.isNotEmpty) displayName = nameFromDoc;
        }
      }

      // Fallback to email username if nothing else
      if (displayName.isEmpty) {
        displayName = user.email?.split('@').first ?? 'Staff Member';
      }

      // cache
      await prefs.setString('cachedDisplayName', displayName);

      if (!mounted) return;
      setState(() {
        fullName = displayName;
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error fetching user name: $e\n$st');
      if (!mounted) return;
      setState(() {
        fullName = 'Staff Member';
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/company-login');
  }

  void _navigateForItem(DashboardItem item) {
    // Safely close drawer if open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Navigate using named route if provided
    if (item.route.isNotEmpty) {
      Navigator.pushNamed(context, item.route);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          title: Text(
            'Staff Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh profile',
              onPressed: () => fetchUserName(forceRefresh: true),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'settings') {
                  Navigator.pushNamed(context, '/staff/settings');
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: const [
                      Icon(Icons.settings, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        drawer: _buildDrawer(primaryColor),
        body: Column(
          children: [
            _buildHeader(primaryColor),
            const SizedBox(height: 10),
            Expanded(child: _buildAnimatedGrid()),
            _buildFooter(),
          ],
        ),
      );
  }

  Drawer _buildDrawer(Color primaryColor) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor,
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              isLoading ? 'Loading...' : fullName,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                fullName.isNotEmpty
                    ? fullName
                        .split(' ')
                        .where((e) => e.isNotEmpty)
                        .map((e) => e[0].toUpperCase())
                        .take(2)
                        .join()
                    : '?',
                style: TextStyle(fontSize: 24, color: primaryColor),
              ),
            ),
          ),
          ...dashboardItems.map(
            (item) => ListTile(
              leading: Icon(item.icon, color: primaryColor),
              title: Text(item.title, style: GoogleFonts.poppins(fontSize: 15)),
              onTap: () => _navigateForItem(item),
            ),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Logout', style: GoogleFonts.poppins(color: Colors.redAccent)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.9), primaryColor.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                SizedBox(width: 12),
                Text('Loading...', style: TextStyle(fontSize: 18, color: Colors.white)),
              ],
            )
          : Text(
              'Welcome, $fullName 👋',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildAnimatedGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: dashboardItems.length,
      itemBuilder: (context, index) {
        final item = dashboardItems[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: StaffDashboardCard(
            title: item.title,
            icon: item.icon,
            color: (Theme.of(context).colorScheme.primary),
            onTap: () => _navigateForItem(item),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final year = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.all(14),
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(
        '© $year A1Specto • Staff Panel v2.0',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}

class StaffDashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StaffDashboardCard({
    super.key,
    required this.title,
    required this.icon,
    Color? color,
    this.onTap,
  }) : color = color ?? Colors.blueAccent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: color.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
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
