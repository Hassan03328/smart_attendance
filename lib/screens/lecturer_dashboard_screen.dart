import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class LecturerDashboardScreen extends StatelessWidget {
  final AppUser user;

  const LecturerDashboardScreen({super.key, required this.user});

  Future<Map<String, int>> _getStats() async {
    final courses = await FirebaseFirestore.instance
        .collection('courses')
        .where('lecturer_id', isEqualTo: user.uid)
        .get();

    final lectures = await FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: user.uid)
        .get();

    int totalAttendance = 0;

    for (final lecture in lectures.docs) {
      final attendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('lecture_id', isEqualTo: lecture.id)
          .get();

      totalAttendance += attendance.docs.length;
    }

    return {
      'courses': courses.docs.length,
      'lectures': lectures.docs.length,
      'attendance': totalAttendance,
    };
  }

  @override
  Widget build(BuildContext context) {
    final latestLecturesStream = FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .limit(5)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard Stats'),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _getStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Courses',
                        value: stats['courses'].toString(),
                        icon: Icons.menu_book,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Lectures',
                        value: stats['lectures'].toString(),
                        icon: Icons.qr_code,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatCard(
                  title: 'Attendance Records',
                  value: stats['attendance'].toString(),
                  icon: Icons.people,
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Latest Lectures',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: latestLecturesStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Text('No lectures yet');
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.class_),
                            title: Text(data['name'] ?? ''),
                            subtitle: Text(data['course_name'] ?? ''),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
