import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/user.dart';

class StudentAttendanceReportScreen extends StatefulWidget {
  final AppUser user;
  final String courseId;
  final String courseName;

  const StudentAttendanceReportScreen({
    super.key,
    required this.user,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentAttendanceReportScreen> createState() =>
      _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState
    extends State<StudentAttendanceReportScreen> {
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    data = ReportService.getStudentAttendance(
      studentId: widget.user.uid,
      courseId: widget.courseId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
      ),
      body: FutureBuilder(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;

          if (list.isEmpty) {
            return const Center(child: Text('No attendance yet'));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];

              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(item['lecture_name'] ?? ''),
                subtitle: Text(
                  item['timestamp'] != null
                      ? item['timestamp'].toDate().toString()
                      : '',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
