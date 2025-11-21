import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_color_template_page.dart';
import 'color_template_details_page.dart';

class ColorTemplatesPage extends StatefulWidget {
  const ColorTemplatesPage({super.key});

  @override
  State<ColorTemplatesPage> createState() => _ColorTemplatesPageState();
}

class _ColorTemplatesPageState extends State<ColorTemplatesPage> {
  late String companyId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();

    companyId = prefs.getString("cachedCompanyId") ?? "";

    if (companyId.isEmpty) {
      companyId = FirebaseAuth.instance.currentUser?.uid ?? "unknown_company";
    }

    setState(() => loading = false);
  }

  CollectionReference get ref => FirebaseFirestore.instance
      .collection("companies")
      .doc(companyId)
      .collection("color_templates");

  Future<void> _deleteTemplate(String docId, String templateName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete template"),
        content: Text("Delete \"$templateName\"? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template deleted")));
      // No need to setState, StreamBuilder will update. But return true in case caller wants it.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  Future<void> _duplicateTemplate(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final newData = Map<String, dynamic>.from(data);

      // Update name
      final name = newData["name"] ?? "Unnamed Template";
      newData["name"] = "$name (copy)";

      // New timestamp
      newData["createdAt"] = FieldValue.serverTimestamp();

      await ref.add(newData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Template duplicated")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Duplicate failed: $e")),
      );
    }
  }


  Future<void> _editTemplate(String docId, Map<String, dynamic> data) async {
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddColorTemplatePage(
          templateId: docId,
          initialData: data,
        ),
      ),
    );

    if (result == true) {
      // StreamBuilder will update automatically; optional feedback:
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template updated")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Color Templates"),
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool?>(
            context,
            MaterialPageRoute(builder: (_) => const AddColorTemplatePage()),
          );

          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template saved")));
          }
        },
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: ref.orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No color templates added yet",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final templateName = data["name"] ?? "Unnamed Template";

              final productCustomizations = data["productCustomizations"] as Map<String, dynamic>? ?? {};
              final genderKey = productCustomizations.keys.isNotEmpty
                  ? productCustomizations.keys.first
                  : "unknown";

              final combinations = productCustomizations[genderKey] as List? ?? [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(Icons.palette_rounded, color: Colors.blue.shade600),
                  ),

                  title: Text(
                    templateName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Gender: ${genderKey[0].toUpperCase()}${genderKey.substring(1)}",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Combinations: ${combinations.length}",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),

                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editTemplate(doc.id, data);
                      } 
                      else if (value == 'duplicate') {
                        await _duplicateTemplate(doc.id, data);
                      }
                      else if (value == 'delete') {
                        await _deleteTemplate(doc.id, templateName);
                      }
                    },

                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Duplicate'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ColorTemplateDetailsPage(
                          templateName: templateName,
                          gender: genderKey,
                          combinations: combinations,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
