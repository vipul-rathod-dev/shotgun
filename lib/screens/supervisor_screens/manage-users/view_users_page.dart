
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  Future<String?>? _companyFuture;
  String _searchQuery = '';
  String _selectedRole = 'All';

  @override
  void initState() {
    super.initState();
    _companyFuture = _loadCompanyId();
  }

  Future<String?> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cachedCompanyId');
  }

  String _getValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _getName(Map<String, dynamic> data) {
    return _getValue(data, [
      'displayName',
      'name',
      'fullName',
      'userName',
      'username',
    ]);
  }

  String _getRole(Map<String, dynamic> data) {
    final role = _getValue(data, ['role']);
    return role.isEmpty ? 'Unassigned' : role;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return Colors.deepPurple;
      case 'supervisor':
        return Colors.blue;
      case 'staff':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  bool _matchesSearch(
    Map<String, dynamic> data,
    String userId,
  ) {
    final name = _getName(data).toLowerCase();
    final email = _getValue(data, ['email']).toLowerCase();
    final phone = _getValue(
      data,
      ['phone', 'phoneNumber', 'mobile'],
    ).toLowerCase();
    final role = _getRole(data).toLowerCase();

    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    return name.contains(query) ||
        email.contains(query) ||
        phone.contains(query) ||
        role.contains(query) ||
        userId.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF1976D2),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add User',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushNamed(
                '/supervisor/add-user',
              );
            },
            icon: const Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _companyFuture,
        builder: (context, companySnapshot) {
          if (companySnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (companySnapshot.hasError) {
            return _errorView(
              'Unable to load company information.',
            );
          }

          final companyId = companySnapshot.data;

          if (companyId == null || companyId.isEmpty) {
            return _errorView(
              'Company ID not found. Please login again.',
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('companies')
                .doc(companyId)
                .collection('users')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _errorView(
                  'Unable to fetch users: ${snapshot.error}',
                );
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final documents = snapshot.data?.docs ?? [];

              final allUsers = documents
                  .where((doc) {
                    final role = doc.data()['role']
                        ?.toString()
                        .trim()
                        .toLowerCase();

                    return role == 'manager' ||
                        role == 'supervisor' ||
                        role == 'staff';
                  })
                  .map((doc) {
                    return {
                      'id': doc.id,
                      'data': doc.data(),
                    };
                  })
                  .toList();

              final roles = allUsers
                  .map((user) => _getRole(
                        user['data'] as Map<String, dynamic>,
                      ))
                  .toSet()
                  .toList()
                ..sort();

              final filteredUsers = allUsers.where((user) {
                final data =
                    user['data'] as Map<String, dynamic>;
                final id = user['id'] as String;
                final role = _getRole(data);

                final matchesRole = _selectedRole == 'All' ||
                    role.toLowerCase() ==
                        _selectedRole.toLowerCase();

                return matchesRole && _matchesSearch(data, id);
              }).toList();

              final managerCount = allUsers.where((user) {
                final data = user['data'] as Map<String, dynamic>;
                return _getRole(data).toLowerCase() == 'manager';
              }).length;

              final supervisorCount = allUsers.where((user) {
                final data = user['data'] as Map<String, dynamic>;
                return _getRole(data).toLowerCase() == 'supervisor';
              }).length;

              final staffCount = allUsers.where((user) {
                final data = user['data'] as Map<String, dynamic>;
                return _getRole(data).toLowerCase() == 'staff';
              }).length;

              return Column(
                children: [
                  _buildStatistics(
                    allUsers.length,
                    supervisorCount,
                    staffCount,
                    managerCount,
                  ),

                  _buildSearch(),

                  _buildRoleFilters(roles),

                  Expanded(
                    child: filteredUsers.isEmpty
                        ? _emptyView(
                            allUsers.isEmpty
                                ? 'No users found in this company.'
                                : 'No users match your search.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              16, 8, 16, 24,
                            ),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final data = user['data']
                                  as Map<String, dynamic>;
                              final id = user['id'] as String;

                              return _buildUserCard(data, id);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatistics(
    int total,
    int supervisors,
    int staff,
    int managers,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Total Users',
              total,
              Icons.people_alt_outlined,
              Colors.indigo,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              'Supervisors',
              supervisors,
              Icons.supervisor_account,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              'Managers',
              managers,
              Icons.manage_accounts,
              Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              'Staff',
              staff,
              Icons.badge_outlined,
              Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 7),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search name, email, phone or role...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilters(List<String> roles) {
    final filters = ['All', ...roles];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final role = filters[index];
          final selected = _selectedRole == role;

          return ChoiceChip(
            label: Text(role),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedRole = role;
              });
            },
            selectedColor: const Color(0xFF1565C0),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> data,
    String userId,
  ) {
    final name = _getName(data);
    final email = _getValue(data, ['email']);
    final phone = _getValue(
      data,
      ['phone', 'phoneNumber', 'mobile'],
    );
    final role = _getRole(data);
    final roleColor = _getRoleColor(role);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: roleColor.withOpacity(0.12),
              child: Text(
                _getInitials(name),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Unnamed User' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 65,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
