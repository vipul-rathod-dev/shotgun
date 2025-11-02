import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/staff_screens/tasks_page/tasks_details_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String? companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyId = prefs.getString('cachedCompanyId');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (companyId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('tasks')
            .where('assignedTo',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tasks assigned yet.'));
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final taskDoc = tasks[index];
              final task = taskDoc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text(
                    task['brandName'] ?? 'No Brand',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Order Type: ${task['orderType'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(task['status']),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task['status'] ?? 'Pending',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  onTap: () => _showTaskDetails(context, taskDoc.id, task),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Bottom Sheet with task details + Start Task button
  void _showTaskDetails(
      BuildContext context, String taskId, Map<String, dynamic> task) {
    final productDetails = task['productDetails'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task['brandName'] ?? 'No Brand',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(task['status']),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task['status'] ?? 'Pending',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Order Type: ${task['orderType'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Product Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),

              for (var product in productDetails)
                _buildProductCard(context, product),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Task'),
                  onPressed: () {
                    Navigator.pop(context); // close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailsPage(
                          companyId: companyId!,
                          taskId: taskId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Product card + chip-style customizations
  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final customizations = product['customizations'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['productName'] ?? 'Unnamed Product',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('Quantity: ${product['quantity'] ?? 0}'),
            const SizedBox(height: 8),
            const Text(
              'Customizations:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var c in customizations)
                  Chip(
                    label: Text(
                        'Focus: ${c['focusColor']} (${c['focusQty']} pcs) • Temple: ${c['templeColor']} (${c['templeQty']} pcs)'),
                    backgroundColor: Colors.grey.shade200,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Status color helper
  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
