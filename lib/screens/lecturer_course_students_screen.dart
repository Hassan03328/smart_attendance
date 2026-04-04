import 'package:flutter/material.dart';

import '../services/report_service.dart';

class LecturerCourseStudentsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const LecturerCourseStudentsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<LecturerCourseStudentsScreen> createState() =>
      _LecturerCourseStudentsScreenState();
}

class _LecturerCourseStudentsScreenState
    extends State<LecturerCourseStudentsScreen> {
  late Future<List<Map<String, dynamic>>> studentsFuture;
  String search = '';

  @override
  void initState() {
    super.initState();
    studentsFuture =
        ReportService.getCourseStudentsSummary(courseId: widget.courseId);
  }

  Color _color(double value) {
    if (value >= 75) return Colors.green;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} Students'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search student...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  search = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: studentsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data!.where((student) {
                  final name =
                      (student['student_name'] ?? '').toString().toLowerCase();
                  final email =
                      (student['student_email'] ?? '').toString().toLowerCase();
                  return name.contains(search) || email.contains(search);
                }).toList();

                if (students.isEmpty) {
                  return const Center(child: Text('No students found'));
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final p =
                        (student['attendance_percentage'] ?? 0.0).toDouble();

                    return Card(
                      child: ListTile(
                        title: Text(
                          (student['student_name'] ?? '').toString(),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (student['student_email'] ?? '').toString(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Present: ${student['present_count']} | Late: ${student['late_count']} | Absent: ${student['absent_count']}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Attendance: ${p.toStringAsFixed(1)}% (${student['attended_count']}/${student['total_lectures']})',
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: p / 100,
                              minHeight: 6,
                              color: _color(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
