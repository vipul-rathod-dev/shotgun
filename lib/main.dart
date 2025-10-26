import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shotgun/screens/auth_screens/login_controller.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🟢 Get saved role if session is valid
  final role = await LoginController.getSavedRole();

  String initialRoute;
  if (role == 'admin') {
    initialRoute = '/admin';
  } else if (role == 'supervisor') {
    initialRoute = '/supervisor';
  } else if (role == 'staff') {
    initialRoute = '/staff';
  } else {
    initialRoute = '/login';
  }

  runApp(MyApp(initialRoute: initialRoute));
}
