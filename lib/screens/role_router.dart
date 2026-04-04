import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import 'lecturer_home.dart';
import 'login_screen.dart';
import 'student_home.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const LoginScreen();
        }

        final appUser = AppUser.fromFirestore(userSnap.data!);

        if (appUser.role == 'lecturer') {
          return LecturerHome(user: appUser);
        } else {
          return StudentHome(user: appUser);
        }
      },
    );
  }
}