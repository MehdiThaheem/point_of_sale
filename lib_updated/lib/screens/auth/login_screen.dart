import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;

  // =========================
  // LOGIN
  // =========================
  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('Please enter email and password');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Login failed');
    } catch (e) {
      showMessage('Something went wrong');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================
  // MESSAGE
  // =========================
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================
  // DISPOSE
  // =========================
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF03264C);
    const pageBackground = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: pageBackground,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 440,
            ),

            child: Card(
              color: navy,
              elevation: 8,
              shadowColor: Colors.black26,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),

              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  30,
                  35,
                  30,
                  28,
                ),

                child: Column(
                  children: [

                    // =========================
                    // MARKETING BOOSTER LOGO
                    // =========================

                    Container(
                      width: 170,
                      height: 170,

                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 15,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),

                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/marketing.jpg',

                          width: 170,
                          height: 170,

                          fit: BoxFit.cover,

                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return const Icon(
                              Icons.business,
                              size: 65,
                              color: Color(0xFF0D6EFD),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =========================
                    // TITLE
                    // =========================

                    const Text(
                      'Marketing Booster',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 7),

                    // =========================
                    // SUBTITLE
                    // =========================

                    const Text(
                      'Professional Business Management System',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // =========================
                    // EMAIL
                    // =========================

                    TextField(
                      controller: emailController,

                      keyboardType:
                      TextInputType.emailAddress,

                      textInputAction:
                      TextInputAction.next,

                      style: const TextStyle(
                        color: Colors.black87,
                      ),

                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',

                        filled: true,
                        fillColor: Colors.white,

                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: navy,
                        ),

                        labelStyle: const TextStyle(
                          color: Colors.black54,
                        ),

                        hintStyle: const TextStyle(
                          color: Colors.black38,
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =========================
                    // PASSWORD
                    // =========================

                    TextField(
                      controller: passwordController,

                      obscureText: obscurePassword,

                      textInputAction:
                      TextInputAction.done,

                      onSubmitted: (_) {
                        if (!isLoading) {
                          login();
                        }
                      },

                      style: const TextStyle(
                        color: Colors.black87,
                      ),

                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',

                        filled: true,
                        fillColor: Colors.white,

                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: navy,
                        ),

                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',

                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,

                            color: navy,
                          ),

                          onPressed: () {
                            setState(() {
                              obscurePassword =
                              !obscurePassword;
                            });
                          },
                        ),

                        labelStyle: const TextStyle(
                          color: Colors.black54,
                        ),

                        hintStyle: const TextStyle(
                          color: Colors.black38,
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =========================
                    // LOGIN BUTTON
                    // =========================

                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton(
                        onPressed:
                        isLoading ? null : login,

                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.white,

                          foregroundColor:
                          navy,

                          disabledBackgroundColor:
                          Colors.white54,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),

                          elevation: 0,
                        ),

                        child: isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2.5,

                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                              navy,
                            ),
                          ),
                        )
                            : const Text(
                          'LOGIN',

                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =========================
                    // REGISTER
                    // =========================

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) =>
                            const RegisterScreen(),
                          ),
                        );
                      },

                      child: const Text(
                        "Don't have an account? Register",

                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}