import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:smart_attendance_app/models/user.dart';
import 'package:smart_attendance_app/screens/login_screen.dart';
import 'package:smart_attendance_app/screens/student_home.dart';
import 'package:smart_attendance_app/screens/lecturer_home.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in
        if (!authSnap.hasData) {
          return const LoginScreen();
        }

        // Logged in → get user data
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnap.data!.uid)
              .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const LoginScreen();
            }

            final appUser = AppUser.fromFirestore(userSnap.data!);

            // Route by role
            if (appUser.role == 'lecturer') {
              return LecturerHome(user: appUser);
            } else {
              return StudentHome(user: appUser);
            }
          },
        );
      },
    );
  }
}
