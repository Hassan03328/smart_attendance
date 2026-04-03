import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/pdf_service.dart';

class LectureReportScreen extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final String courseId;

  const LectureReportScreen({
    super.key,
    required this.lectureId,
    required this.lectureName,
    required this.courseId,
  });

  @override
  State<LectureReportScreen> createState() => _LectureReportScreenState();
}

class _LectureReportScreenState extends State<LectureReportScreen> {
  late Future<List<Map<String, dynamic>>> data;
  String search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    data = ReportService.getLectureAttendanceReport(
      lectureId: widget.lectureId,
      courseId: widget.courseId,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatSource(Map<String, dynamic> item) {
    if (item['marked_manually'] == true) return 'Manual by lecturer';

    final inside = item['inside_university'] == true;
    final wifi = item['on_university_wifi'] == true;

    if (item['status'] == 'Absent') return 'No attendance';
    if (inside && wifi) return 'Inside + WiFi';
    if (inside) return 'Inside university';
    if (wifi) return 'University WiFi';
    return 'Unknown';
  }

  Future<void> _openManualAttendanceDialog() async {
    final students = await ReportService.getCourseStudentsForManualAttendance(
      courseId: widget.courseId,
      lectureId: widget.lectureId,
    );

    if (!mounted) return;

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No remaining students to mark')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        String localSearch = '';

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filtered = students.where((student) {
              final name = (student['student_name'] ?? '').toLowerCase();
              final email = (student['student_email'] ?? '').toLowerCase();
              return name.contains(localSearch) || email.contains(localSearch);
            }).toList();

            return AlertDialog(
              title: const Text('Manual Attendance'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search student...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          localSearch = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No students found'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final student = filtered[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(student['student_name'] ?? ''),
                                    subtitle:
                                        Text(student['student_email'] ?? ''),
                                    trailing: ElevatedButton(
                                      onPressed: () async {
                                        final lectureInfo =
                                            await ReportService.getLectureInfo(
                                          widget.lectureId,
                                        );
                                        final courseInfo =
                                            await ReportService.getCourseInfo(
                                          widget.courseId,
                                        );

                                        if (lectureInfo == null ||
                                            courseInfo == null) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Failed to load lecture data'),
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        await ReportService
                                            .markAttendanceManually(
                                          lectureId: widget.lectureId,
                                          lectureName: widget.lectureName,
                                          courseId: widget.courseId,
                                          courseName: (courseInfo['name'] ?? '')
                                              .toString(),
                                          section: (courseInfo['section'] ?? '')
                                              .toString(),
                                          building: lectureInfo['building']
                                              ?.toString(),
                                          room: lectureInfo['room']?.toString(),
                                          studentId:
                                              (student['student_id'] ?? '')
                                                  .toString(),
                                          studentName:
                                              (student['student_name'] ?? '')
                                                  .toString(),
                                          studentEmail:
                                              (student['student_email'] ?? '')
                                                  .toString(),
                                        );

                                        if (mounted) {
                                          Navigator.pop(context);
                                          setState(() {
                                            _reload();
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Attendance marked manually'),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Mark'),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report - ${widget.lectureName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: _openManualAttendanceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final list = await data;
              await PdfService.generateLectureReport(
                lectureName: widget.lectureName,
                data: list,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search student...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
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
              future: data,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data!.where((item) {
                  final name = (item['student_name'] ?? '').toLowerCase();
                  final email = (item['student_email'] ?? '').toLowerCase();
                  return name.contains(search) || email.contains(search);
                }).toList();

                if (list.isEmpty) {
                  return const Center(child: Text('No students found'));
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final status = item['status'] ?? 'Unknown';
                    final p = (item['attendance_percentage'] ?? 0).toDouble();

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status),
                          child: Text(
                            status[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(item['student_name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['student_email'] ?? ''),
                            const SizedBox(height: 4),
                            Text('Status: $status'),
                            const SizedBox(height: 4),
                            Text('Attendance: ${p.toStringAsFixed(1)}%'),
                            const SizedBox(height: 4),
                            Text(
                              'Building: ${item['building'] ?? '-'} | Room: ${item['room'] ?? '-'} | Section: ${item['section'] ?? '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text(_formatSource(item)),
                          ],
                        ),
                        trailing: status == 'Absent'
                            ? null
                            : IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await ReportService.deleteAttendance(
                                    lectureId: widget.lectureId,
                                    studentId: item['student_id'],
                                  );

                                  setState(() {
                                    _reload();
                                  });
                                },
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
