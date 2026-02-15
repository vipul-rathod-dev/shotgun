import 'package:shared_preferences/shared_preferences.dart';

class RememberMeService {
  /* -------- ADMIN -------- */

  static Future<void> saveAdmin({required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_email', email);
  }

  static Future<String?> loadAdminEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_email');
  }

  static Future<void> clearAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_email');
  }

  /* -------- COMPANY -------- */

  static Future<void> saveCompany({
    required String email,
    required String company,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_email', email);
    await prefs.setString('company_name', company);
  }

  static Future<Map<String, String?>> loadCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('company_email'),
      'company': prefs.getString('company_name'),
    };
  }

  static Future<void> clearCompany() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('company_email');
    await prefs.remove('company_name');
  }
}
