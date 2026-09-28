import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../rolerouter/role_router.dart';
import '../splash_screen.dart';
import 'login_screen.dart';

// Sits at the root of the app for its entire lifetime. Keeps listening to
// Firebase auth state, so login AND logout both correctly switch screens
// at any point, not just on app start. The branded SplashScreen is shown
// for a minimum amount of time (so it doesn't just flash), and also
// whenever Firebase is still resolving the very first auth snapshot.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final waitingForAuth =
            snapshot.connectionState == ConnectionState.waiting;

        if (!_minSplashElapsed || waitingForAuth) {
          return const SplashScreen();
        }

        final user = snapshot.data;
        return user == null ? const LoginScreen() : const RoleRouter();
      },
    );
  }
}