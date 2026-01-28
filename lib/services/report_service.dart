import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static final _db = FirebaseFirestore.instance;

  /// عدد الطلاب الحاضرين
  static Future<int> getLectureAttendanceCount(String lectureId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    return snapshot.docs.length;
  }

  /// تفاصيل الحضور
  static Future<List<Map<String, dynamic>>> getLectureAttendance(
      String lectureId) async {
    final snapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// حذف طالب من الحضور (Drop)
  static Future<void> dropStudent({
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
