import 'package:flutter/material.dart';
import 'package:smart_attendance_app/main.dart';

import '../services/report_service.dart';

// This screen shows all students inside one course for the lecturer
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
  // Students data from ReportService
  late Future<List<Map<String, dynamic>>> studentsFuture;

  // Search text
  String search = '';

  // Used to show loading on selected student button
  String? savingStudentId;

  @override
  void initState() {
    super.initState();

    // Load students summary when screen opens
    studentsFuture =
        ReportService.getCourseStudentsSummary(courseId: widget.courseId);
  }

  // Reload students data after manual attendance
  void _reload() {
    setState(() {
      studentsFuture =
          ReportService.getCourseStudentsSummary(courseId: widget.courseId);
    });
  }

  // Return color based on attendance percentage
  Color _color(double value) {
    if (value >= 75) return Colors.green;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }

  // Mark student attendance manually
  Future<void> _markAttendance(
    Map<String, dynamic> student,
    String status,
  ) async {
    setState(() {
      savingStudentId = (student['student_id'] ?? '').toString();
    });

    try {
      await ReportService.markAttendanceManuallyFromCourse(
        courseId: widget.courseId,
        courseName: widget.courseName,
        studentId: (student['student_id'] ?? '').toString(),
        studentName: (student['student_name'] ?? '').toString(),
        studentEmail: (student['student_email'] ?? '').toString(),
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $status')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }

    if (!mounted) return;
    setState(() {
      savingStudentId = null;
    });
  }

  // Manual attendance buttons
  Widget _manualButtons(Map<String, dynamic> student) {
    final studentId = (student['student_id'] ?? '').toString();
    final loading = savingStudentId == studentId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Manual Attendance',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed:
                    loading ? null : () => _markAttendance(student, 'Present'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Present'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    loading ? null : () => _markAttendance(student, 'Late'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Late'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    loading ? null : () => _markAttendance(student, 'Absent'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Absent'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} Students'),
        actions: [
          // Change theme button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
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

          // Students list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: studentsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter students by name or email
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student name
                            Text(
                              (student['student_name'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Student email
                            Text(
                              (student['student_email'] ?? '').toString(),
                            ),
                            const SizedBox(height: 4),

                            // Student attendance counts
                            Text(
                              'Present: ${student['present_count']} | Late: ${student['late_count']} | Absent: ${student['absent_count']}',
                            ),
                            const SizedBox(height: 4),

                            // Student attendance percentage
                            Text(
                              'Attendance: ${p.toStringAsFixed(1)}% (${student['attended_count']}/${student['total_lectures']})',
                            ),
                            const SizedBox(height: 6),

                            // Progress bar
                            LinearProgressIndicator(
                              value: p / 100,
                              minHeight: 6,
                              color: _color(p),
                            ),

                            // Manual attendance buttons
                            _manualButtons(student),
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