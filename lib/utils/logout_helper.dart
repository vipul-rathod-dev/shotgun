import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('cachedCompanyId');
  await FirebaseAuth.instance.signOut();
}
