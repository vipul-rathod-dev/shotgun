// File: remember_me_service.dart
// Purpose: Centralized Remember Me logic (email + optional company)
// Reusable: Yes

import 'package:shared_preferences/shared_preferences.dart';

class RememberMeService {
  static const _emailKey = 'remember_email';
  static const _companyKey = 'remember_company';
  static const _flagKey = 'remember_me';

  static Future<void> save({
    required String email,
    String? company,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    if (company != null) {
      await prefs.setString(_companyKey, company);
    }
    await prefs.setBool(_flagKey, true);
  }

  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_flagKey) ?? false;

    if (!remember) return {};

    return {
      'email': prefs.getString(_emailKey) ?? '',
      'company': prefs.getString(_companyKey) ?? '',
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_companyKey);
    await prefs.setBool(_flagKey, false);
  }
}
