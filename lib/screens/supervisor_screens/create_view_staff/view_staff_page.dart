import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ViewStaffPage extends StatefulWidget {
  const ViewStaffPage({super.key});

  @override
  State<ViewStaffPage> createState() => _ViewStaffPageState();
}

class _ViewStaffPageState extends State<ViewStaffPage> {
  String? companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('user_companies')
        .doc(uid)
        .get();

    if (doc.exists && doc.data()?['companyId'] != null) {
      setState(() {
        companyId = doc.data()!['companyId'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (companyId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Staff'),
          backgroundColor: Colors.lightBlue,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final staffStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Staff'),
        backgroundColor: Colors.lightBlue,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadCompanyId(),
        child: StreamBuilder<QuerySnapshot>(
          stream: staffStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading staff: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
        
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
        
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No staff members found in your company.'),
              );
            }
        
            final staffList = snapshot.data!.docs;
        
            return ListView.builder(
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final staff = staffList[index];
                final name = staff['name'] ?? 'Unnamed';
                final email = staff['email'] ?? 'No email';
        
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.lightBlue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () {
                        // TODO: open staff edit page
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue,
        onPressed: () {
          // TODO: navigate to Add Staff page under this company
          Navigator.pushNamed(
            context,
            '/supervisor/add-staff',
            arguments: companyId,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
