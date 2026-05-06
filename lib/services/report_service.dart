import 'package:cloud_firestore/cloud_firestore.dart';

// Service class responsible for generating reports and summaries
class ReportService {
  // Firestore instance used across all methods
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================
  // 📊 Student Dashboard Summary (Overview)
  // ======================================
  static Future<Map<String, dynamic>> getStudentDashboardSummary({
    required String studentId,
  }) async {

    // Fetch student enrollments
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .get();

    // Fetch all attendance records for the student
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .get();

    // Extract unique course IDs from enrollments
    final enrolledCourseIds = enrollmentsSnapshot.docs
        .map((e) => (e.data()['course_id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    int totalLectures = 0;

    // Count total lectures across all enrolled courses
    for (final courseId in enrolledCourseIds) {
      final lecturesSnapshot = await _db
          .collection('lectures')
          .where('course_id', isEqualTo: courseId)
          .get();

      totalLectures += lecturesSnapshot.docs.length;
    }

    int presentCount = 0;
    int lateCount = 0;

    // Count present and late statuses
    for (final doc in attendanceSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'Present') presentCount++;
      if (status == 'Late') lateCount++;
    }

    // Total attended lectures
    final attendedCount = attendanceSnapshot.docs.length;

    // Calculate absences
    final absentCount = totalLectures - attendedCount;

    // Calculate attendance percentage
    final percentage =
        totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

    // Return summary data
    return {
      'enrolled_courses': enrolledCourseIds.length,
      'total_lectures': totalLectures,
      'present_count': presentCount,
      'late_count': lateCount,
      'absent_count': absentCount < 0 ? 0 : absentCount,
      'attendance_percentage': percentage,
    };
  }

  // ======================================
  // 📊 Student Attendance Summary per Course
  // ======================================
  static Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    required String courseId,
  }) async {

    // Fetch attendance for a specific course
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch all lectures for the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    final totalLectures = lecturesSnapshot.docs.length;
    final attendedLectures = attendanceSnapshot.docs.length;

    int presentCount = 0;
    int lateCount = 0;

    // Count attendance statuses
    for (final doc in attendanceSnapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status == 'Present') presentCount++;
      if (status == 'Late') lateCount++;
    }

    // Calculate absence and percentage
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

  // ======================================
  // 📚 Student Courses Dashboard
  // ======================================
  static Future<List<Map<String, dynamic>>> getStudentCoursesDashboard({
    required String studentId,
  }) async {

    // Fetch student enrollments
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .get();

    final results = <Map<String, dynamic>>[];

    // Loop through each enrollment
    for (final enrollment in enrollmentsSnapshot.docs) {
      final courseId = (enrollment.data()['course_id'] ?? '').toString();
      if (courseId.isEmpty) continue;

      // Fetch course details
      final courseDoc = await _db.collection('courses').doc(courseId).get();
      final courseData = courseDoc.data() ?? {};

      // Fetch attendance summary for the course
      final summary = await getStudentAttendanceSummary(
        studentId: studentId,
        courseId: courseId,
      );

      // Combine course info with attendance summary
      results.add({
        'course_id': courseId,
        'course_name': (courseData['name'] ?? '').toString(),
        'section': (courseData['section'] ?? '').toString(),
        ...summary,
      });
    }

    return results;
  }

  // ======================================
  // 👨‍🏫 Lecturer Dashboard Summary
  // ======================================
  static Future<Map<String, dynamic>> getLecturerDashboardSummary({
    required String lecturerId,
  }) async {

    // Fetch lecturer's courses
    final coursesSnapshot = await _db
        .collection('courses')
        .where('lecturer_id', isEqualTo: lecturerId)
        .get();

    // Fetch lecturer's lectures
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('lecturer_id', isEqualTo: lecturerId)
        .get();

    int attendanceCount = 0;

    // Count attendance records per lecture
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

  // ======================================
  // 📋 Course Students Summary
  // ======================================
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

    // Fetch all lectures for the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Count total lectures in the course
    final totalLectures = lecturesSnapshot.docs.length;

    // Store users by their document ID for quick access
    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    // Loop through enrolled students
    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

      // Fetch attendance records for this student in this course
      final attendanceSnapshot = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      int presentCount = 0;
      int lateCount = 0;

      // Count present and late statuses
      for (final doc in attendanceSnapshot.docs) {
        final status = (doc.data()['status'] ?? '').toString();
        if (status == 'Present') presentCount++;
        if (status == 'Late') lateCount++;
      }

      // Calculate attended, absent, and attendance percentage
      final attendedCount = attendanceSnapshot.docs.length;
      final absentCount = totalLectures - attendedCount;
      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      // Get student user data
      final user = usersById[studentId] ?? {};

      // Add student summary to the result list
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

    // Sort students by attendance percentage from highest to lowest
    result.sort((a, b) => (b['attendance_percentage'] as double)
        .compareTo(a['attendance_percentage'] as double));

    return result;
  }

  // ======================================
  // 🧾 Student Attendance Records
  // ======================================
  static Future<List<Map<String, dynamic>>> getStudentAttendance({
    required String studentId,
    required String courseId,
  }) async {

    // Fetch attendance records for a student in a specific course
    final snapshot = await _db
        .collection('attendance')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .get();

    // Return attendance records as a list
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ======================================
  // 📄 Lecture Attendance Report
  // ======================================
  static Future<List<Map<String, dynamic>>> getLectureAttendanceReport({
    required String lectureId,
    required String courseId,
  }) async {

    // Fetch attendance records for the selected lecture
    final attendanceSnapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    // Fetch all students enrolled in the course
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch all users
    final usersSnapshot = await _db.collection('users').get();

    // Fetch course information
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    final courseData = courseDoc.data() ?? {};
    final courseSection = (courseData['section'] ?? '').toString();

    // Fetch all lectures in the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Count total course lectures
    final totalLectures = lecturesSnapshot.docs.length;

    // Store attendance records by student ID
    final attendanceByStudent = <String, Map<String, dynamic>>{};
    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final studentId = (data['student_id'] ?? '').toString();
      if (studentId.isNotEmpty) {
        attendanceByStudent[studentId] = data;
      }
    }

    // Store users by ID
    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    // Loop through every enrolled student
    for (final enrollment in enrollmentsSnapshot.docs) {
      final studentId = (enrollment.data()['student_id'] ?? '').toString();
      if (studentId.isEmpty) continue;

      // Fetch all attendance records for the student in this course
      final studentAttendanceInCourse = await _db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .where('course_id', isEqualTo: courseId)
          .get();

      // Calculate student attendance percentage
      final attendedCount = studentAttendanceInCourse.docs.length;
      final percentage =
          totalLectures == 0 ? 0.0 : (attendedCount / totalLectures) * 100;

      // If the student has attendance for this lecture
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

        // If the student has no attendance record, mark as absent
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

    // Sort report by attendance status
    result.sort((a, b) {
      const order = {'Present': 0, 'Late': 1, 'Absent': 2};
      return (order[a['status']] ?? 9).compareTo(order[b['status']] ?? 9);
    });

    return result;
  }

  // ======================================
  // ✍️ Students Available for Manual Attendance
  // ======================================
  static Future<List<Map<String, dynamic>>>
      getCourseStudentsForManualAttendance({
    required String courseId,
    required String lectureId,
  }) async {

    // Fetch enrollments for the course
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Fetch all users
    final usersSnapshot = await _db.collection('users').get();

    // Fetch attendance records for the lecture
    final lectureAttendanceSnapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .get();

    // Get IDs of students who already attended
    final attendedStudentIds = lectureAttendanceSnapshot.docs
        .map((e) => (e['student_id'] ?? '').toString())
        .toSet();

    // Store users by ID
    final usersById = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      usersById[doc.id] = doc.data();
    }

    final result = <Map<String, dynamic>>[];

    // Add only students who have not been marked yet
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

    // Sort students alphabetically
    result.sort((a, b) => (a['student_name'] ?? '')
        .toString()
        .compareTo((b['student_name'] ?? '').toString()));

    return result;
  }

  // # GET ACTIVE OR LATEST LECTURE FOR MANUAL ATTENDANCE
  static Future<Map<String, dynamic>?> getBestLectureForManualAttendance({
    required String courseId,
  }) async {

    // Try to get the active lecture first
    final activeSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .where('is_active', isEqualTo: true)
        .get();

    // If an active lecture exists, return it
    if (activeSnapshot.docs.isNotEmpty) {
      final doc = activeSnapshot.docs.first;
      final data = doc.data();
      data['doc_id'] = doc.id;
      return data;
    }

    // If no active lecture exists, fetch all lectures for the course
    final allLectures = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Return null if the course has no lectures
    if (allLectures.docs.isEmpty) return null;

    // Sort lectures by creation date, newest first
    allLectures.docs.sort((a, b) {
      final aTime = a.data()['created_at'];
      final bTime = b.data()['created_at'];

      if (aTime is! Timestamp && bTime is! Timestamp) return 0;
      if (aTime is! Timestamp) return 1;
      if (bTime is! Timestamp) return -1;
      return bTime.compareTo(aTime);
    });

    // Return the latest lecture
    final doc = allLectures.docs.first;
    final data = doc.data();
    data['doc_id'] = doc.id;
    return data;
  }

  // ======================================
  // ✍️ Mark Attendance Manually
  // ======================================
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
    required String status,
  }) async {

    // Check if the student already has attendance for this lecture
    final existing = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .where('student_id', isEqualTo: studentId)
        .get();

    // If attendance exists, update the status instead of creating a duplicate
    if (existing.docs.isNotEmpty) {
      for (final doc in existing.docs) {
        await doc.reference.update({
          'status': status,
          'marked_manually': true,
          'manual_by_lecturer': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    // If no attendance exists, create a new manual attendance record
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
      'status': status,
      'marked_manually': true,
      'manual_by_lecturer': true,
    });
  }

  // # MANUAL ATTENDANCE FROM COURSE SCREEN
  static Future<void> markAttendanceManuallyFromCourse({
    required String courseId,
    required String courseName,
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String status,
  }) async {

    // Get the active lecture or the latest lecture
    final lecture = await getBestLectureForManualAttendance(courseId: courseId);

    // Stop if there is no lecture available
    if (lecture == null) {
      throw 'Create a lecture first before manual attendance';
    }

    // Mark attendance using the selected lecture data
    await markAttendanceManually(
      lectureId: (lecture['doc_id'] ?? '').toString(),
      lectureName: (lecture['name'] ?? 'Lecture').toString(),
      courseId: courseId,
      courseName: courseName,
      section: (lecture['section'] ?? '').toString(),
      building: lecture['building']?.toString(),
      room: lecture['room']?.toString(),
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      status: status,
    );
  }

  // ======================================
  // 🗑️ Delete Attendance Record
  // ======================================
  static Future<void> deleteAttendance({
    required String lectureId,
    required String studentId,
  }) async {

    // Fetch attendance records matching lecture and student
    final snapshot = await _db
        .collection('attendance')
        .where('lecture_id', isEqualTo: lectureId)
        .where('student_id', isEqualTo: studentId)
        .get();

    // Delete all matching attendance records
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // # DELETE COURSE WITH RELATED DATA
  static Future<void> deleteCourse(String courseId) async {

    // Fetch all lectures related to the course
    final lecturesSnapshot = await _db
        .collection('lectures')
        .where('course_id', isEqualTo: courseId)
        .get();

    // Delete attendance records for each lecture, then delete the lecture
    for (final lecture in lecturesSnapshot.docs) {
      final attendanceByLecture = await _db
          .collection('attendance')
          .where('lecture_id', isEqualTo: lecture.id)
          .get();

      for (final attendance in attendanceByLecture.docs) {
        await attendance.reference.delete();
      }

      await lecture.reference.delete();
    }

    // Delete any remaining attendance records linked directly to the course
    final attendanceByCourse = await _db
        .collection('attendance')
        .where('course_id', isEqualTo: courseId)
        .get();

    for (final doc in attendanceByCourse.docs) {
      await doc.reference.delete();
    }

    // Delete enrollments related to the course
    final enrollmentsSnapshot = await _db
        .collection('enrollments')
        .where('course_id', isEqualTo: courseId)
        .get();

    for (final doc in enrollmentsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Finally, delete the course document itself
    await _db.collection('courses').doc(courseId).delete();
  }

  // ======================================
  // ℹ️ Get Lecture Info
  // ======================================
  static Future<Map<String, dynamic>?> getLectureInfo(String lectureId) async {

    // Fetch lecture document by ID
    final doc = await _db.collection('lectures').doc(lectureId).get();

    // Return lecture data
    return doc.data();
  }

  // ======================================
  // ℹ️ Get Course Info
  // ======================================
  static Future<Map<String, dynamic>?> getCourseInfo(String courseId) async {

    // Fetch course document by ID
    final doc = await _db.collection('courses').doc(courseId).get();

    // Return course data
    return doc.data();
  }
}
