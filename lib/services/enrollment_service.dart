import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    await _db.collection('enrollments').add({
      'student_id': studentId,
      'course_id': courseId,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> dropStudent({
    required String studentId,
    required String courseId,
  }) async {
    final q = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

    for (var doc in q.docs) {
      await doc.reference.delete();
    }
  }
}
