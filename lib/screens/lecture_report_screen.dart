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
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    data = ReportService.getLectureAttendance(widget.lectureId);
  }

  String _formatSource(Map<String, dynamic> item) {
    final bool insideUniversity = item['inside_university'] == true;
    final bool onUniversityWifi = item['on_university_wifi'] == true;
    final String? wifiName = item['wifi_ssid'];

    if (insideUniversity && onUniversityWifi) {
      return 'Inside university + WiFi (${wifiName ?? 'Unknown'})';
    }

    if (insideUniversity) {
      return 'Inside university';
    }

    if (onUniversityWifi) {
      return 'University WiFi (${wifiName ?? 'Unknown'})';
    }

    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report - ${widget.lectureName}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(item['student_name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['student_email'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        item['timestamp'] != null
                            ? item['timestamp'].toDate().toString()
                            : '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSource(item),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
