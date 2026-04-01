import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user.dart';
import 'lecture_report_screen.dart';

class LecturerHome extends StatefulWidget {
  final AppUser user;

  const LecturerHome({super.key, required this.user});

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome> {
  final TextEditingController _courseName = TextEditingController();
  final TextEditingController _lectureName = TextEditingController();

  String? qrData;
  String? selectedCourseId;
  String? selectedCourseName;
  int selectedDurationMinutes = 10;

  Future<void> _createCourse() async {
    if (_courseName.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('courses').add({
      'name': _courseName.text.trim(),
      'lecturer_id': widget.user.uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    _courseName.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully')),
      );
    }
  }

  Future<void> _createLecture() async {
    if (_lectureName.text.trim().isEmpty) return;

    if (selectedCourseId == null || selectedCourseName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course first')),
      );
      return;
    }

    final now = DateTime.now();
    final end = now.add(Duration(minutes: selectedDurationMinutes));

    final doc = FirebaseFirestore.instance.collection('lectures').doc();

    await doc.set({
      'name': _lectureName.text.trim(),
      'lecturer_id': widget.user.uid,
      'course_id': selectedCourseId,
      'course_name': selectedCourseName,
      'qr_code': doc.id,
      'start_time': Timestamp.fromDate(now),
      'end_time': Timestamp.fromDate(end),
      'created_at': FieldValue.serverTimestamp(),
    });

    setState(() {
      qrData = doc.id;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lecture QR created for $selectedDurationMinutes minutes',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lecturerCoursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .snapshots();

    final lecturerLecturesStream = FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .orderBy('created_at', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create Course',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _courseName,
              decoration: const InputDecoration(
                labelText: 'Course Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createCourse,
                child: const Text('Create Course'),
              ),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create Lecture QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: lecturerCoursesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No courses yet. Create a course first.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (selectedCourseId == null) {
                  selectedCourseId = docs.first.id;
                  selectedCourseName = docs.first['name'];
                }

                return DropdownButtonFormField<String>(
                  value: docs.any((d) => d.id == selectedCourseId)
                      ? selectedCourseId
                      : docs.first.id,
                  decoration: const InputDecoration(
                    labelText: 'Select Course',
                    border: OutlineInputBorder(),
                  ),
                  items: docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    final selectedDoc = docs.firstWhere((d) => d.id == value);

                    setState(() {
                      selectedCourseId = selectedDoc.id;
                      selectedCourseName = selectedDoc['name'];
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lectureName,
              decoration: const InputDecoration(
                labelText: 'Lecture Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedDurationMinutes,
              decoration: const InputDecoration(
                labelText: 'QR Duration',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 minutes')),
                DropdownMenuItem(value: 10, child: Text('10 minutes')),
                DropdownMenuItem(value: 15, child: Text('15 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
                DropdownMenuItem(value: 60, child: Text('60 minutes')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedDurationMinutes = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createLecture,
                child: const Text('Create Lecture & QR'),
              ),
            ),
            const SizedBox(height: 30),
            if (qrData != null)
              Column(
                children: [
                  const Text(
                    'Scan this QR for attendance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: qrData!,
                    size: 220,
                  ),
                ],
              ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Lectures',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: lecturerLecturesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No lectures yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final lectureName = data['name'] ?? '';
                    final courseName = data['course_name'] ?? '';
                    final startTime = data['start_time'] as Timestamp?;
                    final endTime = data['end_time'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(lectureName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(courseName),
                            if (startTime != null && endTime != null)
                              Text(
                                '${startTime.toDate()}  →  ${endTime.toDate()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LectureReportScreen(
                                  lectureId: doc.id,
                                  lectureName: lectureName,
                                ),
                              ),
                            );
                          },
                          child: const Text('Report'),
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