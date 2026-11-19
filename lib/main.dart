import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CompanyManagementApp());
}

class CompanyManagementApp extends StatelessWidget {
  const CompanyManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Company Management System',
      theme: AppTheme.lightTheme,
      // AuthGate shows the branded splash first, then keeps listening to
      // the Firebase auth session for as long as the app runs, so login
      // and logout both route correctly at any time.
      home: const AuthGate(),
    );
  }
}