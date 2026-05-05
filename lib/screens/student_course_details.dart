import 'package:flutter/material.dart';
import '../models/user.dart';
import 'qr_scan_page.dart';
import 'student_attendance_report_screen.dart';

// This screen shows course actions for the student
class StudentCourseDetailsScreen extends StatelessWidget {
  final AppUser user; // logged-in student
  final String courseId; // current course id
  final String courseName; // course name
  final String section; // course section

  const StudentCourseDetailsScreen({
    super.key,
    required this.user,
    required this.courseId,
    required this.courseName,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRScanPage(
                      user: user,
                      courseId: courseId,
                      courseName: title,
                    ),
                  ),
                );
              },
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
            ),
          ],
        ),
      ),
    );
  }
}