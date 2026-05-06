import 'package:cloud_firestore/cloud_firestore.dart';

// Service class responsible for generating reports and summaries
class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= STUDENT DASHBOARD =================
  static Future<Map<String, dynamic>> getStudentDashboardSummary({
    required String studentId,
  }) async {
    // Fetch student enrollments
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .get();

    // Fetch student attendance
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .get();

    // Extract unique course IDs
    final enrolledCourseIds = enrollmentsSnapshot.docs
        .map((e) => (e.data()['course_id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    int totalLectures = 0;

    // Count lectures across all courses
    for (final courseId in enrolledCourseIds) {
      final lecturesSnapshot = await _db
          .collection('lectures')
          .where('course_id', isEqualTo: courseId)
          .get();

      totalLectures += lecturesSnapshot.docs.length;
    }

    int presentCount = 0;
    int lateCount = 0;

    // Count attendance status
    for (final doc in attendanceSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'Present') presentCount++;
      if (status == 'Late') lateCount++;
    }

    final attendedCount = attendanceSnapshot.docs.length;
    final absentCount = totalLectures - attendedCount;

    // Calculate percentage
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

  // ================= STUDENT COURSE SUMMARY =================
  static Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    required String courseId,
  }) async {
    // Fetch attendance per course
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch lectures
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

  // ================= STUDENT COURSES DASHBOARD =================
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

      // Get course info
      final courseDoc = await _db.collection('courses').doc(courseId).get();
      final courseData = courseDoc.data() ?? {};

      // Get attendance summary
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

  // ================= LECTURER DASHBOARD =================
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

    // Count attendance across lectures
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
}


   // ================= COURSE STUDENTS SUMMARY =================
  static Future<List<Map<String, dynamic>>> getCourseStudentsSummary({
    required String courseId,
  }) async {

    // Fetch all enrollments for the course
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch all users
    final usersSnapshot = await _db.collection('users').get();

    // Fetch all lectures of the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;

    // Map users by ID for quick lookup
    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    // Loop through each enrolled student
    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

      // Fetch attendance for this student in this course
      final attendanceSnapshot = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      int presentCount = 0;
      int lateCount = 0;

      // Count attendance statuses
      for (final doc in attendanceSnapshot.docs) {
        final status = (doc.data()['status'] ?? '').toString();
        if (status == 'Present') presentCount++;
        if (status == 'Late') lateCount++;
      }

      final attendedCount = attendanceSnapshot.docs.length;
      final absentCount = totalLectures - attendedCount;

      // Calculate percentage
      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      // Get user data
      final user = usersById[studentId] ?? {};

      // Add student summary
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

    // Sort students by attendance percentage (descending)
    result.sort((a, b) => (b['attendance_percentage'] as double)
        .compareTo(a['attendance_percentage'] as double));

    return result;
  }

  // ================= STUDENT ATTENDANCE LIST =================
  static Future<List<Map<String, dynamic>>> getStudentAttendance({
    required String studentId,
    required String courseId,
  }) async {

    // Fetch attendance records sorted by latest
    final snapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .get();

    // Convert documents to list of maps
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ================= LECTURE ATTENDANCE REPORT =================
  static Future<List<Map<String, dynamic>>> getLectureAttendanceReport({
    required String lectureId,
    required String courseId,
  }) async {

    // Fetch attendance for this lecture
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    // Fetch enrolled students
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch users
    final usersSnapshot = await _db.collection('users').get();

    // Fetch course info
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final courseData = courseDoc.data() ?? {};
    final courseSection = (courseData['section'] ?? '').toString();

    // Fetch all lectures of the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;

    // Map attendance by student ID
    final attendanceByStudent = <String, Map<String, dynamic>>{};
    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final studentId = (data['student_id'] ?? '').toString();
      if (studentId.isNotEmpty) {
        attendanceByStudent[studentId] = data;
      }
    }

    // Map users
    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    // Loop students
    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

      // Fetch total attendance for percentage
      final studentAttendanceInCourse = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      final attendedCount = studentAttendanceInCourse.docs.length;

      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      if (attendanceByStudent.containsKey(studentId)) {

        // Student attended this lecture
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

        // Student absent
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

    // Sort by status (Present -> Late -> Absent)
    result.sort((a, b) {
      const order = {'Present': 0, 'Late': 1, 'Absent': 2};
      return (order[a['status']] ?? 9).compareTo(order[b['status']] ?? 9);
    });

    return result;
  }

  