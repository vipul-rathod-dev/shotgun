import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> createUser(String email) async {
    final uid = email.hashCode.toString(); // Or use FirebaseAuth.instance.currentUser?.uid

    await _db.collection('users').doc(uid).set({
      'email': email,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
