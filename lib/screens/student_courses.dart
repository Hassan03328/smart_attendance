import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../services/enrollment_service.dart';
import 'student_course_details.dart';

class StudentCoursesScreen extends StatelessWidget {
  final AppUser user;

  const StudentCoursesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final coursesStream =
        FirebaseFirestore.instance.collection('courses').snapshots();

    final enrollmentsStream = FirebaseFirestore.instance
        .collection('enrollments')
        .where('student_id', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: coursesStream,
        builder: (context, courseSnapshot) {
          if (!courseSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final courseDocs = courseSnapshot.data!.docs;
          if (courseDocs.isEmpty) {
            return const Center(child: Text('No courses available'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: enrollmentsStream,
            builder: (context, enrollmentSnapshot) {
              if (!enrollmentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final enrolled = <String>{};
              for (final doc in enrollmentSnapshot.data!.docs) {
                enrolled.add((doc['course_id'] ?? '').toString());
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: courseDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final courseId = doc.id;
                  final courseName = (data['name'] ?? '').toString();
                  final section = (data['section'] ?? '').toString();

                  final title = section.isEmpty
                      ? courseName
                      : '$courseName - Section $section';

                  final isEnrolled = enrolled.contains(courseId);

                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text(isEnrolled ? 'Enrolled' : 'Not enrolled'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (!isEnrolled)
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                await EnrollmentService.enrollStudent(
                                  studentId: user.uid,
                                  courseId: courseId,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Enrolled successfully'),
                                    ),
                                  );
                                }
                              },
                            ),
                          if (isEnrolled)
                            IconButton(
                              icon: const Icon(
                                Icons.open_in_new,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentCourseDetailsScreen(
                                      user: user,
                                      courseId: courseId,
                                      courseName: courseName,
                                      section: section,
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (isEnrolled)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await EnrollmentService.dropStudent(
                                  studentId: user.uid,
                                  courseId: courseId,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Dropped successfully'),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
