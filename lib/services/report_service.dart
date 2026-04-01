import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static final _db = FirebaseFirestore.instance;

  // دكتور - كل حضور محاضرة
  static Future<List<Map<String, dynamic>>> getLectureAttendance(
      String lectureId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // طالب - حضوره في مادة
  static Future<List<Map<String, dynamic>>> getStudentAttendance({
    required String studentId,
    required String courseId,
  }) async {
    final snapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  static Future<void> deleteAttendance({
    required String lectureId,
    required String studentId,
  }) async {
    final snapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .where('student_id', isEqualTo: studentId)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
