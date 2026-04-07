import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_attendance_app/main.dart';

import '../models/user.dart';
import '../utils/validators.dart';
import 'lecturer_home.dart';
import 'student_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  String? error;
  String selectedRole = 'student';

  Future<void> _goToHome(AppUser appUser) async {
    if (!mounted) return;

    if (appUser.role == 'lecturer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LecturerHome(user: appUser),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentHome(user: appUser),
        ),
      );
    }
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = _email.text.trim();
      final password = _password.text.trim();
      final fullName = _name.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter email and password';
      }

      if (!Validators.isValidPassword(password)) {
        throw 'Password must contain uppercase, lowercase, number and symbol';
      }

      final detectedRole = Validators.getRoleFromEmail(email);
      if (detectedRole == null) {
        throw 'Invalid email domain';
      }

      if (detectedRole != selectedRole) {
        throw selectedRole == 'lecturer'
            ? 'You selected Lecturer, please enter a lecturer email'
            : 'You selected Student, please enter a student email';
      }

      if (isLogin) {
        // # LOGIN
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (!userDoc.exists) {
          throw 'User data not found in database';
        }

        final appUser = AppUser.fromFirestore(userDoc);
        await _goToHome(appUser);
      } else {
        // # REGISTER
        if (fullName.isEmpty) {
          throw 'Please enter full name';
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'email': email,
          'full_name': fullName,
          'role': selectedRole,
          'created_at': Timestamp.now(),
        });

        final newUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        final appUser = AppUser.fromFirestore(newUserDoc);
        await _goToHome(appUser);
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Authentication failed';

      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered';
      } else if (e.code == 'invalid-credential') {
        msg = 'Invalid email or password';
      } else if (e.code == 'user-not-found') {
        msg = 'No account found for this email';
      } else if (e.code == 'wrong-password') {
        msg = 'Wrong password';
      }

      setState(() {
        error = msg;
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  Future<void> forgotPassword() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      setState(() {
        error = 'Please enter your email first';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? 'Failed to send reset email';
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildRoleCard({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final isSelected = selectedRole == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRole = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade400),
              width: 1.5,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : Theme.of(context).iconTheme.color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: Theme.of(context).inputDecorationTheme.enabledBorder,
      focusedBorder: Theme.of(context).inputDecorationTheme.focusedBorder,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Register'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLogin ? Icons.login : Icons.person_add_alt_1,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLogin ? 'Login' : 'Register',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildRoleCard(
                        value: 'student',
                        title: 'Student',
                        icon: Icons.school,
                      ),
                      const SizedBox(width: 12),
                      _buildRoleCard(
                        value: 'lecturer',
                        title: 'Lecturer',
                        icon: Icons.person,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!isLogin) ...[
                    TextField(
                      controller: _name,
                      decoration: _inputDecoration('Full Name'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _email,
                    decoration: _inputDecoration('Email'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: _inputDecoration('Password'),
                  ),
                  const SizedBox(height: 18),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.withOpacity(0.15)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.withOpacity(0.35)
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: isDark
                              ? Colors.red.shade200
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(isLogin ? 'Login' : 'Register'),
                          ),
                  ),
                  if (isLogin) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                        error = null;
                      });
                    },
                    child: Text(
                      isLogin
                          ? 'Create new account'
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
