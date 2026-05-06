import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_attendance_app/main.dart';

import '../models/user.dart';
import '../services/report_service.dart';
import 'student_course_details.dart';
import 'student_courses.dart';
import 'login_screen.dart';

// Student dashboard screen
class StudentHome extends StatefulWidget {
  final AppUser user; // logged-in student data

  const StudentHome({super.key, required this.user});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  // Student summary data
  late Future<Map<String, dynamic>> summaryFuture;

  // Student courses data
  late Future<List<Map<String, dynamic>>> coursesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // Load student dashboard and courses
  void _refreshData() {
    summaryFuture =
        ReportService.getStudentDashboardSummary(studentId: widget.user.uid);
    coursesFuture =
        ReportService.getStudentCoursesDashboard(studentId: widget.user.uid);
  }

  // Refresh page data
  Future<void> _refresh() async {
    setState(() {
      _refreshData();
    });
  }

  // Return color based on attendance percentage
  Color _color(double value) {
    if (value >= 75) return Colors.green;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }

  // Reusable dashboard card
  Widget _card(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          // Change app theme
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
          ),
          // Refresh dashboard
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          // Logout user
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome message
            Text(
              'Welcome ${widget.user.fullName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Student dashboard summary
            FutureBuilder<Map<String, dynamic>>(
              future: summaryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final s = snapshot.data!;
                final p = (s['attendance_percentage'] ?? 0.0).toDouble();

                return Column(
                  children: [
                    Row(
                      children: [
                        _card(
                          'Courses',
                          '${s['enrolled_courses']}',
                          Icons.menu_book,
                        ),
                        _card(
                          'Lectures',
                          '${s['total_lectures']}',
                          Icons.class_,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _card(
                          'Present',
                          '${s['present_count']}',
                          Icons.check_circle,
                        ),
                        _card(
                          'Late',
                          '${s['late_count']}',
                          Icons.schedule,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _card(
                          'Absent',
                          '${s['absent_count']}',
                          Icons.cancel,
                        ),
                        _card(
                          'Attendance %',
                          '${p.toStringAsFixed(1)}%',
                          Icons.percent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Overall attendance progress
                    LinearProgressIndicator(
                      value: p / 100,
                      minHeight: 8,
                      color: _color(p),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Courses section header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Courses Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Open manage courses page
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentCoursesScreen(user: widget.user),
                      ),
                    );
                  },
                  child: const Text('Manage Courses'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Student courses overview
            FutureBuilder<List<Map<String, dynamic>>>(
              future: coursesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final courses = snapshot.data!;

                if (courses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No enrolled courses yet'),
                    ),
                  );
                }

                return Column(
                  children: courses.map((course) {
                    final p =
                        (course['attendance_percentage'] ?? 0.0).toDouble();
                    final section = (course['section'] ?? '').toString();
                    final courseName = (course['course_name'] ?? '').toString();

                    final title = section.isEmpty
                        ? courseName
                        : '$courseName - Section $section';

                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Course attendance counts
                            Text(
                              'Present: ${course['present_count']} | Late: ${course['late_count']} | Absent: ${course['absent_count']}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Attendance: ${p.toStringAsFixed(1)}% (${course['attended_lectures']}/${course['total_lectures']})',
                            ),
                            const SizedBox(height: 6),

                            // Course attendance progress
                            LinearProgressIndicator(
                              value: p / 100,
                              minHeight: 6,
                              color: _color(p),
                            ),
                          ],
                        ),
                        // Open course details page
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentCourseDetailsScreen(
                                  user: widget.user,
                                  courseId:
                                      (course['course_id'] ?? '').toString(),
                                  courseName: courseName,
                                  section: section,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
