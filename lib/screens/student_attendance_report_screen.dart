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
  late Future<Map<String, dynamic>> summary;

  @override
  void initState() {
    super.initState();
    data = ReportService.getStudentAttendance(
      studentId: widget.user.uid,
      courseId: widget.courseId,
    );

    summary = ReportService.getStudentAttendanceSummary(
      studentId: widget.user.uid,
      courseId: widget.courseId,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} Report'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: summary,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  );
                }

                final info = snapshot.data!;
                final percentage =
                    (info['attendance_percentage'] ?? 0.0).toDouble();

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Attendance Summary',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            color: percentage >= 75
                                ? Colors.green
                                : percentage >= 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Attended: ${info['attended_lectures']} / ${info['total_lectures']}',
                          ),
                          const SizedBox(height: 8),
                          Text('Present: ${info['present_count']}'),
                          Text('Late: ${info['late_count']}'),
                          Text('Absent: ${info['absent_count']}'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final status = item['status'] ?? 'Present';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status),
                          child: Text(
                            status[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(item['lecture_name'] ?? ''),
                        subtitle: Text(
                          item['timestamp'] != null
                              ? item['timestamp'].toDate().toString()
                              : '',
                        ),
                        trailing: Text(
                          status,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
