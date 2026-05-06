import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_attendance_app/main.dart';

import '../models/user.dart';
import '../utils/validators.dart';
import 'lecturer_home.dart';
import 'student_home.dart';

// Login & Register screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for input fields
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  // UI state
  bool isLogin = true; // true = login , false = register
  bool loading = false; // show loading spinner
  String? error; // error message
  String selectedRole = 'student'; // selected role

  // Navigate user to correct home screen
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

  // Main function for login/register
  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = _email.text.trim();
      final password = _password.text.trim();
      final fullName = _name.text.trim();

      // Check empty fields
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter email and password';
      }

      // Check strong password
      if (!Validators.isValidPassword(password)) {
        throw 'Password must contain uppercase, lowercase, number and symbol';
      }

      // Detect role from email
      final detectedRole = Validators.getRoleFromEmail(email);
      if (detectedRole == null) {
        throw 'Invalid email domain';
      }

      // Check selected role matches email
      if (detectedRole != selectedRole) {
        throw selectedRole == 'lecturer'
            ? 'You selected Lecturer, please enter a lecturer email'
            : 'You selected Student, please enter a student email';
      }

      if (isLogin) {
        // ===== LOGIN =====
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (!userDoc.exists) {
          throw 'User data not found in database';
        }

        // Convert to model
        final appUser = AppUser.fromFirestore(userDoc);

        // Go to home
        await _goToHome(appUser);
      } else {
        // ===== REGISTER =====
        if (fullName.isEmpty) {
          throw 'Please enter full name';
        }

        // Create account in Firebase Auth
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Save user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'email': email,
          'full_name': fullName,
          'role': selectedRole,
          'created_at': Timestamp.now(),
        });

        // Get saved data
        final newUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        final appUser = AppUser.fromFirestore(newUserDoc);

        // Go to home
        await _goToHome(appUser);
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase errors
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
      // Other errors
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  // Send reset password email
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

  // Role selection card (Student / Lecturer)
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
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Input style
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
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
              if (!isLogin)
                TextField(
                  controller: _name,
                  decoration: _inputDecoration('Full Name'),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                decoration: _inputDecoration('Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: _inputDecoration('Password'),
              ),
              const SizedBox(height: 20),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submit,
                      child: Text(isLogin ? 'Login' : 'Register'),
                    ),
              if (isLogin)
                TextButton(
                  onPressed: forgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    error = null;
                  });
                },
                child: Text(isLogin ? 'Create new account' : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
