import 'package:cloud_firestore/cloud_firestore.dart';

// Service to handle student enrollment in courses
class EnrollmentService {
  // Firestore instance
  static final _db = FirebaseFirestore.instance;

  // Add student to a course
  static Future<void> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    await _db.collection('enrollments').add({
      'student_id': studentId, // store student ID
      'course_id': courseId,   // store course ID
      'created_at': FieldValue.serverTimestamp(), // save time
    });
  }

  // Remove student from a course
  static Future<void> dropStudent({
    required String studentId,
    required String courseId,
  }) async {
    // Find enrollment documents for this student + course
    final q = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

    // Delete all matching documents
    for (var doc in q.docs) {
      await doc.reference.delete();
    }
  }
}
