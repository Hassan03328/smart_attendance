import 'package:flutter/material.dart';
import '../services/report_service.dart';

class LectureReportScreen extends StatefulWidget {
  final String lectureId;
  final String lectureName;

  const LectureReportScreen({
    super.key,
    required this.lectureId,
    required this.lectureName,
  });

  @override
  State<LectureReportScreen> createState() => _LectureReportScreenState();
}

class _LectureReportScreenState extends State<LectureReportScreen> {
  late Future<List<Map<String, dynamic>>> attendanceFuture;

  @override
  void initState() {
    super.initState();
    attendanceFuture = ReportService.getLectureAttendance(widget.lectureId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report - ${widget.lectureName}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No attendance yet'));
          }

          final attendance = snapshot.data!;

          return ListView.builder(
            itemCount: attendance.length,
            itemBuilder: (context, index) {
              final item = attendance[index];

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(item['student_id'] ?? 'Unknown'),
                subtitle: Text(
                  item['timestamp'] != null
                      ? item['timestamp'].toDate().toString()
                      : '',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await ReportService.dropStudent(
                      lectureId: widget.lectureId,
                      studentId: item['student_id'],
                    );

                    setState(() {
                      attendanceFuture =
                          ReportService.getLectureAttendance(widget.lectureId);
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
