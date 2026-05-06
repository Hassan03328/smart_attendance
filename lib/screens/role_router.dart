import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import 'lecturer_home.dart';
import 'login_screen.dart';
import 'student_home.dart';

// This widget decides which screen to open based on user role
class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Get current logged-in user from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;

    // If no user logged in → go to Login screen
    if (currentUser == null) {
      return const LoginScreen();
    }

    // Listen to user data from Firestore in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnap) {

        // While loading → show loading spinner
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If no data or user not found → go to Login
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const LoginScreen();
        }

        // Convert Firestore data to AppUser model
        final appUser = AppUser.fromFirestore(userSnap.data!);

        // Check user role and route to correct screen
        if (appUser.role == 'lecturer') {
          return LecturerHome(user: appUser); // Lecturer screen
        } else {
          return StudentHome(user: appUser); // Student screen
        }
      },
    );
  }
}