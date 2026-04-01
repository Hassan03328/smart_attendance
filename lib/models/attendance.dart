import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String studentId;
  final Timestamp time;

  Attendance({
    required this.studentId,
    required this.time,
  });

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Attendance(
      studentId: data['student_id'] ?? '',
      time: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
