import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_attendance_app/main.dart';

import '../models/user.dart';
import '../services/report_service.dart';
import 'lecture_report_screen.dart';
import 'lecturer_course_students_screen.dart';
import 'login_screen.dart';

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
    _loadActiveLecture();
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

  Future<void> _loadActiveLecture() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    final doc = snapshot.docs.first;
    final data = doc.data();
    final endTime = data['end_time'];

    setState(() {
      activeLectureId = doc.id;
      qrData = doc.id;
      activeLectureOpen = true;
      activeLectureEndTime = endTime is Timestamp ? endTime.toDate() : null;
    });
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

  Future<void> _deleteCourse(String courseId, String courseName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Are you sure you want to delete $courseName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ReportService.deleteCourse(courseId);
    _refreshDashboard();
    _notify('Course deleted successfully');
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (activeLectureId == null) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('lectures')
          .doc(activeLectureId)
          .get();

      if (!doc.exists) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
          qrData = null;
          activeLectureId = null;
          activeLectureEndTime = null;
        });
        return;
      }

      final data = doc.data()!;
      final isActive = (data['is_active'] ?? false) == true;
      final endTime = data['end_time'];

      if (!isActive || endTime is! Timestamp) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
        });
        return;
      }

      final end = endTime.toDate();
      final diff = end.difference(DateTime.now());

      if (diff.isNegative || diff.inSeconds <= 0) {
        await doc.reference.update({'is_active': false});

        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
          activeLectureEndTime = end;
        });

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
        qrData = doc.id;
        activeLectureId = doc.id;
        activeLectureEndTime = end;
        activeLectureOpen = true;
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
          Text(
            'My Courses',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
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
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _deleteCourse(doc.id, title),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
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
        Text(
          'Create Course',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
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
        Text(
          'My Courses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
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
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteCourse(doc.id, title),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
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
          Text(
            'Create Lecture',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                    Text(
                      'Active Lecture QR',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
          Text(
            'My Lectures',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
