import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String fullName = '';
  bool isLoading = true;

  final List<Map<String, dynamic>> dashboardItems = [
    {
      'title': 'Manage Inventory',
      'icon': Icons.inventory,
      'route': '/manage-inventory',
    },
    // Add more here
  ];

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();
          final firstName = data?['first_name'] ?? '';
          final lastName = data?['last_name'] ?? '';
          setState(() {
            fullName = '$firstName $lastName';
            isLoading = false;
          });
        } else {
          debugPrint('User document does not exist.');
          setState(() {
            fullName = 'Staff Member';
            isLoading = false;
          });
        }
      } else {
        debugPrint('No user is currently logged in.');
        setState(() {
          fullName = 'Staff Member';
          isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error fetching user name: $e\n$stack');
      setState(() {
        fullName = 'Staff Member';
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigateTo(String routeName) {
    Navigator.pop(context); // close drawer
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: Colors.lightBlue,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.lightBlue),
              accountName: Text(
                isLoading ? 'Loading...' : fullName,
                style: const TextStyle(fontSize: 18),
              ),
              accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (fullName.isNotEmpty)
                      ? fullName
                          .split(' ')
                          .where((e) => e.isNotEmpty)
                          .map((e) => e[0].toUpperCase())
                          .take(2)
                          .join()
                      : '?',
                  style: const TextStyle(fontSize: 24, color: Colors.lightBlue),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.lightBlue),
              title: const Text('Manage Inventory'),
              onTap: () => _navigateTo('/manage-inventory'),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // HEADER WITH NAME
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.lightBlue.shade100,
            child: isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(width: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                )
              : Text(
                  'Welcome, $fullName!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),

          const SizedBox(height: 10),

          // BODY - GridView of cards
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: dashboardItems.map((item) {
                return StaffDashboardCard(
                  title: item['title'],
                  icon: item['icon'],
                  onTap: () => _navigateTo(item['route']),
                );
              }).toList(),
            ),
          ),

          // FOOTER
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Text(
              '© 2025 A1Specto • Staff Panel v1.0',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffDashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const StaffDashboardCard({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped: $title')),
              );
            },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.lightBlue),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
