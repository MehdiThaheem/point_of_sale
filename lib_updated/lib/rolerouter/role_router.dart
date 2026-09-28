import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/customers/customer_dashboard.dart';
import '../screens/employees/employee_dashboard.dart';
import '../screens/suppliers/supplier_dashboard.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

// Shown whenever a user is signed in. Looks up their role in Firestore
// and routes them to the right dashboard. If anything is wrong (missing
// profile, unknown role, or the session drops), it falls back to the
// Login screen instead of leaving a broken/stuck screen on display.
class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return FutureBuilder(
      future: UserService().getUserProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();

        if (data == null) {
          return _errorScreen(
            context,
            'We could not find your account profile in the database.',
          );
        }

        switch (data['role']) {
          case 'admin':
            return const AdminDashboard();
          case 'employee':
            return const EmployeeDashboard();
          case 'supplier':
            return const SupplierDashboard();
          case 'customer':
            return const CustomerDashboard();
          default:
            return _errorScreen(
              context,
              'Your account does not have a valid role assigned.',
            );
        }
      },
    );
  }

  Widget _errorScreen(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}