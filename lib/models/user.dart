import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role; // student, lecturer
  final Timestamp createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? data['name'] ?? '',
      role: data['role'] ?? 'student',
      createdAt: data['created_at'] ?? data['createdAt'] ?? Timestamp.now(),
    );
  }
}
