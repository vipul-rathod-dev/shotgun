import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shotgun/app/app.dart';
import 'package:shotgun/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());

}

