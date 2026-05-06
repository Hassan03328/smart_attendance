import 'package:flutter/material.dart';
import '../models/user.dart';
import 'qr_scan_page.dart';
<<<<<<< HEAD
import 'student_attendance_report_screen.dart';

// This screen shows course actions for the student
class StudentCourseDetailsScreen extends StatelessWidget {
  final AppUser user; // logged-in student
  final String courseId; // current course id
  final String courseName; // course name
  final String section; // course section
=======

class StudentCourseDetailsScreen extends StatelessWidget {
  final AppUser user;
  final String courseId;
  final String courseName;
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2

  const StudentCourseDetailsScreen({
    super.key,
    required this.user,
    required this.courseId,
    required this.courseName,
<<<<<<< HEAD
    required this.section,
=======
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    // Create title with section if exists
    final title =
        section.isEmpty ? courseName : '$courseName - Section $section';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Button to scan QR code (attendance)
            ElevatedButton(
=======
    return Scaffold(
      appBar: AppBar(
        title: Text(courseName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              courseName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRScanPage(
                      user: user,
                      courseId: courseId,
<<<<<<< HEAD
                      courseName: title,
=======
                      courseName: courseName,
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
                    ),
                  ),
                );
              },
<<<<<<< HEAD
              child: const Text('Scan QR Code'),
            ),
            const SizedBox(height: 16),

            // Button to open attendance report
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentAttendanceReportScreen(
                      user: user,
                      courseId: courseId,
                      courseName: title,
                    ),
                  ),
                );
              },
              child: const Text('Attendance Report'),
=======
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan the QR code for this course only.',
              style: TextStyle(color: Colors.grey),
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
