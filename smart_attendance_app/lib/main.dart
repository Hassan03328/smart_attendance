import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:smart_attendance_app/screens/role_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RoleRouter(),
    );
  }
}
