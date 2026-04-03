import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/user.dart';
import '../services/report_service.dart';
import 'lecture_report_screen.dart';
import 'lecturer_course_students_screen.dart';

class LecturerHome extends StatefulWidget {
  final AppUser user;

  const LecturerHome({super.key, required this.user});

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _courseName = TextEditingController();
  final _sectionController = TextEditingController();
  final _lectureName = TextEditingController();
  final _buildingController = TextEditingController();
  final _roomController = TextEditingController();

  String? selectedCourseId;
  String? selectedCourseName;
  String? selectedCourseSection;

  int selectedDurationMinutes = 10;

  String? qrData;
  String? activeLectureId;
  DateTime? activeLectureEndTime;
  bool activeLectureOpen = false;

  Timer? _timer;
  Duration _remaining = Duration.zero;

  late Future<Map<String, dynamic>> dashboardFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    dashboardFuture =
        ReportService.getLecturerDashboardSummary(lecturerId: widget.user.uid);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _courseName.dispose();
    _sectionController.dispose();
    _lectureName.dispose();
    _buildingController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _refreshDashboard() {
    setState(() {
      dashboardFuture = ReportService.getLecturerDashboardSummary(
        lecturerId: widget.user.uid,
      );
    });
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showDialogMessage(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (activeLectureEndTime == null || !activeLectureOpen) {
        setState(() {
          _remaining = Duration.zero;
        });
        return;
      }

      final diff = activeLectureEndTime!.difference(DateTime.now());

      if (diff.isNegative || diff.inSeconds <= 0) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
        });

        if (activeLectureId != null) {
          await FirebaseFirestore.instance
              .collection('lectures')
              .doc(activeLectureId)
              .update({'is_active': false});
        }

        _showDialogMessage(
          'Lecture Closed',
          'The QR code has expired and attendance is now closed.',
        );
        return;
      }

      if (diff.inSeconds == 60) {
        _notify('Only 1 minute left before QR closes');
      }

      setState(() {
        _remaining = diff;
      });
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  Future<void> _createCourse() async {
    if (_courseName.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('courses').add({
      'name': _courseName.text.trim(),
      'section': _sectionController.text.trim(),
      'lecturer_id': widget.user.uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    _courseName.clear();
    _sectionController.clear();
    _refreshDashboard();
    _notify('Course created successfully');
  }

  Future<void> _createLecture() async {
    if (_lectureName.text.trim().isEmpty) return;

    if (selectedCourseId == null || selectedCourseName == null) {
      _notify('Please select a course first');
      return;
    }

    if (_buildingController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      _notify('Please enter building and room');
      return;
    }

    final doc = FirebaseFirestore.instance.collection('lectures').doc();

    await doc.set({
      'name': _lectureName.text.trim(),
      'lecturer_id': widget.user.uid,
      'course_id': selectedCourseId,
      'course_name': selectedCourseName,
      'section': selectedCourseSection ?? '',
      'building': _buildingController.text.trim(),
      'room': _roomController.text.trim(),
      'qr_code': doc.id,
      'created_at': FieldValue.serverTimestamp(),
      'is_active': false,
    });

    _lectureName.clear();
    _buildingController.clear();
    _roomController.clear();
    _notify('Lecture created successfully');
    _refreshDashboard();
  }

  Future<void> _openLectureQr(String lectureId) async {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: selectedDurationMinutes));

    final activeLectures = await FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .where('is_active', isEqualTo: true)
        .get();

    for (final doc in activeLectures.docs) {
      await doc.reference.update({'is_active': false});
    }

    await FirebaseFirestore.instance
        .collection('lectures')
        .doc(lectureId)
        .update({
      'start_time': Timestamp.fromDate(now),
      'end_time': Timestamp.fromDate(end),
      'is_active': true,
    });

    setState(() {
      activeLectureId = lectureId;
      qrData = lectureId;
      activeLectureEndTime = end;
      activeLectureOpen = true;
      _remaining = end.difference(DateTime.now());
    });

    _showDialogMessage('Lecture Started', 'QR is now active.');
  }

  Future<void> _closeLectureNow() async {
    if (activeLectureId == null) return;

    await FirebaseFirestore.instance
        .collection('lectures')
        .doc(activeLectureId)
        .update({'is_active': false});

    setState(() {
      activeLectureOpen = false;
      _remaining = Duration.zero;
      qrData = null;
      activeLectureId = null;
      activeLectureEndTime = null;
    });

    _showDialogMessage('Lecture Closed', 'The QR code was closed manually.');
  }

  Widget _dashboardCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon),
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

  Widget _dashboardTab() {
    final coursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .snapshots();

    return RefreshIndicator(
      onRefresh: () async => _refreshDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: dashboardFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snapshot.data!;

              return Column(
                children: [
                  Row(
                    children: [
                      _dashboardCard(
                        'Courses',
                        '${stats['courses_count']}',
                        Icons.menu_book,
                      ),
                      _dashboardCard(
                        'Lectures',
                        '${stats['lectures_count']}',
                        Icons.class_,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _dashboardCard(
                        'Attendance',
                        '${stats['attendance_count']}',
                        Icons.people,
                      ),
                      _dashboardCard(
                        'Active QR',
                        activeLectureOpen ? '1' : '0',
                        Icons.qr_code,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'My Courses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: coursesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No courses yet'),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final section = data['section'] ?? '';
                  final title = section.toString().isEmpty
                      ? (data['name'] ?? '')
                      : '${data['name']} - Section $section';

                  return Card(
                    child: ListTile(
                      title: Text(title),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LecturerCourseStudentsScreen(
                                courseId: doc.id,
                                courseName: title,
                              ),
                            ),
                          );
                        },
                        child: const Text('Students'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _coursesTab() {
    final coursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Create Course',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        TextField(
          controller: _sectionController,
          decoration: const InputDecoration(
            labelText: 'Section',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _createCourse,
          child: const Text('Create Course'),
        ),
        const SizedBox(height: 24),
        const Text(
          'My Courses',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: coursesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Text('No courses yet');
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final section = data['section'] ?? '';
                final title = section.toString().isEmpty
                    ? (data['name'] ?? '')
                    : '${data['name']} - Section $section';

                return Card(
                  child: ListTile(
                    title: Text(title),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LecturerCourseStudentsScreen(
                              courseId: doc.id,
                              courseName: title,
                            ),
                          ),
                        );
                      },
                      child: const Text('Students'),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _lecturesTab() {
    final coursesStream = FirebaseFirestore.instance
        .collection('courses')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .snapshots();

    final lecturesStream = FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .snapshots();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Lecture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: coursesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Text('Create a course first');
              }

              if (selectedCourseId == null) {
                selectedCourseId = docs.first.id;
                selectedCourseName = docs.first['name'];
                selectedCourseSection = docs.first['section'] ?? '';
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
                  final data = doc.data() as Map<String, dynamic>;
                  final section = data['section'] ?? '';
                  final title = section.toString().isEmpty
                      ? (data['name'] ?? '')
                      : '${data['name']} - Section $section';

                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(title),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final selectedDoc = docs.firstWhere((d) => d.id == value);
                  final data = selectedDoc.data() as Map<String, dynamic>;
                  setState(() {
                    selectedCourseId = selectedDoc.id;
                    selectedCourseName = data['name'];
                    selectedCourseSection = data['section'] ?? '';
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lectureName,
            decoration: const InputDecoration(
              labelText: 'Lecture Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buildingController,
            decoration: const InputDecoration(
              labelText: 'Building',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomController,
            decoration: const InputDecoration(
              labelText: 'Room',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
              child: const Text('Create Lecture'),
            ),
          ),
          const SizedBox(height: 24),
          if (qrData != null && activeLectureOpen)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Active Lecture QR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(data: qrData!, size: 220),
                    const SizedBox(height: 12),
                    Text(
                      'Time Remaining: ${_formatDuration(_remaining)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _remaining.inSeconds <= 60
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _closeLectureNow,
                        icon: const Icon(Icons.close),
                        label: const Text('Close QR Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'My Lectures',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: lecturesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();

              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aTime = aData['created_at'];
                final bTime = bData['created_at'];

                if (aTime is! Timestamp && bTime is! Timestamp) return 0;
                if (aTime is! Timestamp) return 1;
                if (bTime is! Timestamp) return -1;

                return bTime.compareTo(aTime);
              });

              if (docs.isEmpty) {
                return const Text('No lectures yet');
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isActive = (data['is_active'] ?? false) == true;
                  final section = data['section'] ?? '';
                  final courseTitle = section.toString().isEmpty
                      ? (data['course_name'] ?? '')
                      : '${data['course_name']} - Section $section';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(courseTitle),
                          const SizedBox(height: 4),
                          Text(
                            'Building: ${data['building'] ?? '-'} | Room: ${data['room'] ?? '-'}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'Active' : 'Closed',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _openLectureQr(docs[index].id),
                                  child: const Text('Open QR'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LectureReportScreen(
                                          lectureId: docs[index].id,
                                          lectureName: data['name'] ?? '',
                                          courseId: data['course_id'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Report'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Courses'),
            Tab(text: 'Lectures'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _dashboardTab(),
          _coursesTab(),
          _lecturesTab(),
        ],
      ),
    );
  }
}
