import 'package:flutter/material.dart';
import '../models/user.dart';
import 'qr_scan_page.dart';
import 'student_attendance_report_screen.dart';

class StudentCourseDetailsScreen extends StatelessWidget {
  final AppUser user;
  final String courseId;
  final String courseName;
  final String section;

  const StudentCourseDetailsScreen({
    super.key,
    required this.user,
    required this.courseId,
    required this.courseName,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        section.isEmpty ? courseName : '$courseName - Section $section';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
