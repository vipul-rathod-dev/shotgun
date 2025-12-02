import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/models/task_model.dart';

class FirestoreScripts {
  /// Adds a new field to all documents where `category == "Finished"`
  /// inside companies/{companyId}/{subCollectionName}
  static Future<void> addFieldToFinishedCategory({
    required String subCollectionName,
    required String fieldName,
    required dynamic value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');

    if (companyId == null) {
      throw Exception("Company ID not found in SharedPreferences");
    }

    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore
        .collection('companies')
        .doc(companyId)
        .collection(subCollectionName)
        // .where('category', isEqualTo: 'Finished')
        .get();

    if (querySnapshot.docs.isEmpty) {
      debugPrint("⚠️ No matching documents found.");
      return;
    }

    int counter = 0;
    WriteBatch batch = firestore.batch();

    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {fieldName: value});
      counter++;

      // Commit batch every 400 updates (limit 500)
      if (counter % 400 == 0) {
        await batch.commit();
        batch = firestore.batch();
      }
    }

    await batch.commit();
    debugPrint("✅ Added '$fieldName' to $counter documents in $subCollectionName.");
  }

  Future<List<TaskModel>> getAllTasks(String companyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .get();

    return snapshot.docs.map((d) => TaskModel.fromFirestore(d)).toList();
  }

    /// Returns the cached companyId stored in SharedPreferences.
    /// Throws an exception if not found.
    static Future<String> getCachedCompanyId() async {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('cachedCompanyId');

      if (companyId == null || companyId.isEmpty) {
        throw Exception("Company ID not found in SharedPreferences");
      }

      return companyId;
    }


}
