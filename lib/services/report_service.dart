import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> getStudentDashboardSummary({
    required String studentId,
  }) async {
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .get();

    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .get();

    final enrolledCourseIds = enrollmentsSnapshot.docs
        .map((e) => (e.data()['course_id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    int totalLectures = 0;

    for (final courseId in enrolledCourseIds) {
      final lecturesSnapshot = await _db
          .collection('lectures')
          .where('course_id', isEqualTo: courseId)
          .get();

      totalLectures += lecturesSnapshot.docs.length;
    }

    int presentCount = 0;
    int lateCount = 0;

    for (final doc in attendanceSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'Present') presentCount++;
      if (status == 'Late') lateCount++;
    }

    final attendedCount = attendanceSnapshot.docs.length;
    final absentCount = totalLectures - attendedCount;
    final percentage =
        totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

    return {
      'enrolled_courses': enrolledCourseIds.length,
      'total_lectures': totalLectures,
      'present_count': presentCount,
      'late_count': lateCount,
      'absent_count': absentCount < 0 ? 0 : absentCount,
      'attendance_percentage': percentage,
    };
  }

  static Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    required String courseId,
  }) async {
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;
    final attendedLectures = attendanceSnapshot.docs.length;

    int presentCount = 0;
    int lateCount = 0;

    for (final doc in attendanceSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'Present') presentCount++;
      if (status == 'Late') lateCount++;
    }

    final absentCount = totalLectures - attendedLectures;
    final percentage =
        totalLectures == 0 ? 0.0 : (attendedLectures / totalLectures) * 100;

    return {
      'total_lectures': totalLectures,
      'attended_lectures': attendedLectures,
      'present_count': presentCount,
      'late_count': lateCount,
      'absent_count': absentCount < 0 ? 0 : absentCount,
      'attendance_percentage': percentage,
    };
  }

  static Future<List<Map<String, dynamic>>> getStudentCoursesDashboard({
    required String studentId,
  }) async {
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .get();

    final results = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final courseId = (enrollment.data()['course_id'] ?? '').toString();
      if (courseId.isEmpty) continue;

      final courseDoc = await _db.collection('courses').doc(courseId).get();
      final courseData = courseDoc.data() ?? {};

      final summary = await getStudentAttendanceSummary(
        studentId: studentId,
        courseId: courseId,
      );

      results.add({
        'course_id': courseId,
        'course_name': (courseData['name'] ?? '').toString(),
        'section': (courseData['section'] ?? '').toString(),
        ...summary,
      });
    }

    return results;
  }

  static Future<Map<String, dynamic>> getLecturerDashboardSummary({
    required String lecturerId,
  }) async {
    final coursesSnapshot = await _db
        .collection('courses')
        .where('lecturer_id', isEqualTo: lecturerId)
        .get();

    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('lecturer_id', isEqualTo: lecturerId)
        .get();

    int attendanceCount = 0;

    for (final lecture in lecturesSnapshot.docs) {
      final attendanceSnapshot = await _db
          .collection('attendance')
          .where('lecture_id', isEqualTo: lecture.id)
          .get();

      attendanceCount += attendanceSnapshot.docs.length;
    }

    return {
      'courses_count': coursesSnapshot.docs.length,
      'lectures_count': lecturesSnapshot.docs.length,
      'attendance_count': attendanceCount,
    };
  }

  static Future<List<Map<String, dynamic>>> getCourseStudentsSummary({
    required String courseId,
  }) async {
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    final usersSnapshot = await _db.collection('users').get();
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;

    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

      final attendanceSnapshot = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      int presentCount = 0;
      int lateCount = 0;

      for (final doc in attendanceSnapshot.docs) {
        final status = (doc.data()['status'] ?? '').toString();
        if (status == 'Present') presentCount++;
        if (status == 'Late') lateCount++;
      }

      final attendedCount = attendanceSnapshot.docs.length;
      final absentCount = totalLectures - attendedCount;
      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      final user = usersById[studentId] ?? {};

      result.add({
        'student_id': studentId,
        'student_name':
            (user['full_name'] ?? user['name'] ?? 'Unknown').toString(),
        'student_email': (user['email'] ?? '').toString(),
        'present_count': presentCount,
        'late_count': lateCount,
        'absent_count': absentCount < 0 ? 0 : absentCount,
        'attendance_percentage': percentage,
        'attended_count': attendedCount,
        'total_lectures': totalLectures,
      });
    }

    result.sort((a, b) => (b['attendance_percentage'] as double)
        .compareTo(a['attendance_percentage'] as double));

    return result;
  }

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
    final courseData = courseDoc.data() ?? {};
    final courseSection = (courseData['section'] ?? '').toString();

    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;

    final attendanceByStudent = <String, Map<String, dynamic>>{};
    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final studentId = (data['student_id'] ?? '').toString();
      if (studentId.isNotEmpty) {
        attendanceByStudent[studentId] = data;
      }
    }

    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

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
          'student_name': (attendance['student_name'] ?? '').toString(),
          'student_email': (attendance['student_email'] ?? '').toString(),
          'timestamp': attendance['timestamp'],
          'status': (attendance['status'] ?? 'Present').toString(),
          'inside_university': attendance['inside_university'] ?? false,
          'on_university_wifi': attendance['on_university_wifi'] ?? false,
          'wifi_ssid': attendance['wifi_ssid'],
          'attendance_percentage': percentage,
          'attended_lectures_count': attendedCount,
          'total_lectures': totalLectures,
          'building': attendance['building'],
          'room': attendance['room'],
          'section': (attendance['section'] ?? courseSection).toString(),
          'marked_manually': attendance['marked_manually'] ?? false,
        });
      } else {
        final user = usersById[studentId] ?? {};
        result.add({
          'student_id': studentId,
          'student_name':
              (user['full_name'] ?? user['name'] ?? 'Unknown').toString(),
          'student_email': (user['email'] ?? '').toString(),
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
        .map((e) => (e['student_id'] ?? '').toString())
        .toSet();

    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment['student_id'] ?? '').toString();
      if (studentId.isEmpty || attendedStudentIds.contains(studentId)) continue;

      final user = usersById[studentId] ?? {};
      result.add({
        'student_id': studentId,
        'student_name':
            (user['full_name'] ?? user['name'] ?? 'Unknown').toString(),
        'student_email': (user['email'] ?? '').toString(),
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
    return doc.data();
  }

  static Future<Map<String, dynamic>?> getCourseInfo(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    return doc.data();
  }
}
