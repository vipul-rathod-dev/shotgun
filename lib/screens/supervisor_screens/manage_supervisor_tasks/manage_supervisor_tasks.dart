import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shotgun/utils/firestore_scripts.dart';

class SupervisorTasksPage extends StatefulWidget {
  const SupervisorTasksPage({super.key});

  @override
  State<SupervisorTasksPage> createState() => _SupervisorTasksPageState();
}

class _SupervisorTasksPageState extends State<SupervisorTasksPage> {
  String? companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final id = await FirestoreScripts.getCachedCompanyId();
    setState(() => companyId = id);
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
        title: const Text("Manage Tasks"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('tasks') // GLOBAL TASK REFS
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final globalTasks = snapshot.data!.docs;

          if (globalTasks.isEmpty) {
            return const Center(
              child: Text(
                "No tasks found",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadFullTasks(globalTasks),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final fullTasks = taskSnapshot.data!;

              return ListView.builder(
                itemCount: fullTasks.length,
                itemBuilder: (context, index) {
                  final task = fullTasks[index];

                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: ListTile(
                      title: Text(task['taskTitle'] ?? 'Task'),
                      subtitle: Text("Assigned To: ${task['assignedToName']}"),
                      trailing: Text(
                        task['status'] ?? 'Pending',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 🔥 Fetch REAL task details for each global task reference
  Future<List<Map<String, dynamic>>> _loadFullTasks(
    List<DocumentSnapshot> globalDocs,
  ) async {
    List<Map<String, dynamic>> results = [];

    for (var doc in globalDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final taskPath = data['taskPath'];

      if (taskPath == null) continue;

      final fullTaskDoc = await FirebaseFirestore.instance.doc(taskPath).get();

      if (fullTaskDoc.exists) {
        final fullData = fullTaskDoc.data() as Map<String, dynamic>;

        results.add({
          'taskId': fullData['taskId'],
          'taskTitle': fullData['taskTitle'] ?? 'Task',
          'orderId': fullData['orderId'],
          'status': fullData['status'],
          'assignedToName': fullData['assignedToName'],
        });
      }
    }

    return results;
  }
}
