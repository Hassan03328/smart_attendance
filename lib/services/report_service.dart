import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static final _db = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> getLectureAttendanceReport({
    required String lectureId,
    required String courseId,
  }) async {
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    final usersSnapshot = await _db.collection('users').get();
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final courseData = courseDoc.data() ?? {};
    final courseSection = (courseData['section'] ?? '').toString();
    final totalLectures = lecturesSnapshot.docs.length;

    final attendanceByStudent = <String, Map<String, dynamic>>{};
    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();
      attendanceByStudent[data['student_id']] = data;
    }

    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = enrollment['student_id'];

      final studentAttendanceInCourse = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      final attendedCount = studentAttendanceInCourse.docs.length;
      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      if (attendanceByStudent.containsKey(studentId)) {
        final attendance = attendanceByStudent[studentId]!;
        result.add({
          'student_id': studentId,
          'student_name': attendance['student_name'] ?? '',
          'student_email': attendance['student_email'] ?? '',
          'timestamp': attendance['timestamp'],
          'status': attendance['status'] ?? 'Present',
          'inside_university': attendance['inside_university'] ?? false,
          'on_university_wifi': attendance['on_university_wifi'] ?? false,
          'wifi_ssid': attendance['wifi_ssid'],
          'attendance_percentage': percentage,
          'attended_lectures_count': attendedCount,
          'total_lectures': totalLectures,
          'building': attendance['building'],
          'room': attendance['room'],
          'section': attendance['section'] ?? courseSection,
          'marked_manually': attendance['marked_manually'] ?? false,
        });
      } else {
        final user = usersById[studentId] ?? {};
        result.add({
          'student_id': studentId,
          'student_name': user['full_name'] ?? user['name'] ?? 'Unknown',
          'student_email': user['email'] ?? '',
          'timestamp': null,
          'status': 'Absent',
          'inside_university': false,
          'on_university_wifi': false,
          'wifi_ssid': null,
          'attendance_percentage': percentage,
          'attended_lectures_count': attendedCount,
          'total_lectures': totalLectures,
          'building': null,
          'room': null,
          'section': courseSection,
          'marked_manually': false,
        });
      }
    }

    result.sort((a, b) {
      const order = {'Present': 0, 'Late': 1, 'Absent': 2};
      return (order[a['status']] ?? 9).compareTo(order[b['status']] ?? 9);
    });

    return result;
  }

  static Future<List<Map<String, dynamic>>>
      getCourseStudentsForManualAttendance({
    required String courseId,
    required String lectureId,
  }) async {
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    final usersSnapshot = await _db.collection('users').get();

    final lectureAttendanceSnapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    final attendedStudentIds = lectureAttendanceSnapshot.docs
        .map((e) => e['student_id'] as String)
        .toSet();

    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = enrollment['student_id'];

      if (attendedStudentIds.contains(studentId)) continue;

      final user = usersById[studentId] ?? {};
      result.add({
        'student_id': studentId,
        'student_name': user['full_name'] ?? user['name'] ?? 'Unknown',
        'student_email': user['email'] ?? '',
      });
    }

    result.sort((a, b) => (a['student_name'] ?? '')
        .toString()
        .compareTo((b['student_name'] ?? '').toString()));

    return result;
  }

  static Future<void> markAttendanceManually({
    required String lectureId,
    required String lectureName,
    required String courseId,
    required String courseName,
    required String section,
    required String? building,
    required String? room,
    required String studentId,
    required String studentName,
    required String studentEmail,
  }) async {
    final existing = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .where('student_id', isEqualTo: studentId)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _db.collection('attendance').add({
      'student_id': studentId,
      'student_name': studentName,
      'student_email': studentEmail,
      'lecture_id': lectureId,
      'lecture_name': lectureName,
      'course_id': courseId,
      'course_name': courseName,
      'section': section,
      'building': building,
      'room': room,
      'timestamp': FieldValue.serverTimestamp(),
      'inside_university': false,
      'on_university_wifi': false,
      'wifi_ssid': null,
      'status': 'Present',
      'marked_manually': true,
      'manual_by_lecturer': true,
    });
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

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static Future<Map<String, dynamic>?> getLectureInfo(String lectureId) async {
    final doc = await _db.collection('lectures').doc(lectureId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  static Future<Map<String, dynamic>?> getCourseInfo(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
