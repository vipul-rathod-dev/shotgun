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
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddColorTemplatePage()),
          );
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

                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),

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
                  }
                ),
              );
            },
          );
        },
      ),
    );
  }
}
