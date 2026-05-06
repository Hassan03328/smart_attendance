// Imports Dart async utilities, including Timer.
import 'dart:async';
// Imports Flutter Material UI components.
import 'package:flutter/material.dart';
// Imports Firebase Authentication for sign-out functionality.
import 'package:firebase_auth/firebase_auth.dart';
// Imports Cloud Firestore for database operations.
import 'package:cloud_firestore/cloud_firestore.dart';
// Imports QR Flutter package to display QR codes.
import 'package:qr_flutter/qr_flutter.dart';
// Imports the main app to access theme toggling.
import 'package:smart_attendance_app/main.dart';

// Imports the custom user model.
import '../models/user.dart';
// Imports report-related services.
import '../services/report_service.dart';
// Imports the lecture report screen.
import 'lecture_report_screen.dart';
// Imports the screen that displays students in a lecturer course.
import 'lecturer_course_students_screen.dart';
// Imports the login screen used after logout.
import 'login_screen.dart';

// Main lecturer home screen widget.
class LecturerHome extends StatefulWidget {
  // Stores the logged-in lecturer user data.
  final AppUser user;

  // Creates the lecturer home screen with the required user.
  const LecturerHome({super.key, required this.user});

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

// State class for LecturerHome.
class _LecturerHomeState extends State<LecturerHome>
    with SingleTickerProviderStateMixin {
  // Controls the tabs in the lecturer dashboard.
  late TabController _tabController;

  // Controller for the course name input.
  final _courseName = TextEditingController();
  // Controller for the section input.
  final _sectionController = TextEditingController();
  // Controller for the lecture name input.
  final _lectureName = TextEditingController();
  // Controller for the building input.
  final _buildingController = TextEditingController();
  // Controller for the room input.
  final _roomController = TextEditingController();

  // Stores the selected course ID.
  String? selectedCourseId;
  // Stores the selected course name.
  String? selectedCourseName;
  // Stores the selected course section.
  String? selectedCourseSection;

  // Stores the selected QR duration in minutes.
  int selectedDurationMinutes = 10;

  // Stores QR data to display in the QR widget.
  String? qrData;
  // Stores the currently active lecture ID.
  String? activeLectureId;
  // Stores the end time of the active lecture.
  DateTime? activeLectureEndTime;
  // Tracks whether the active lecture QR is open.
  bool activeLectureOpen = false;

  // Timer used to update the remaining QR time.
  Timer? _timer;
  // Stores the remaining time before the QR closes.
  Duration _remaining = Duration.zero;

  // Future used to load dashboard summary data.
  late Future<Map<String, dynamic>> dashboardFuture;

  @override
  void initState() {
    super.initState();
    // Initializes the tab controller with three tabs.
    _tabController = TabController(length: 3, vsync: this);
    // Loads the lecturer dashboard summary.
    dashboardFuture =
        ReportService.getLecturerDashboardSummary(lecturerId: widget.user.uid);
    // Checks if there is already an active lecture.
    _loadActiveLecture();
    // Starts the timer for QR countdown updates.
    _startTimer();
  }

  @override
  void dispose() {
    // Cancels the timer to prevent memory leaks.
    _timer?.cancel();
    // Disposes the tab controller.
    _tabController.dispose();
    // Disposes text controllers to free resources.
    _courseName.dispose();
    _sectionController.dispose();
    _lectureName.dispose();
    _buildingController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  // Loads the currently active lecture for this lecturer, if one exists.
  Future<void> _loadActiveLecture() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    // Stops if there is no active lecture.
    if (snapshot.docs.isEmpty) return;

    final doc = snapshot.docs.first;
    final data = doc.data();
    final endTime = data['end_time'];

    // Updates local state with the active lecture data.
    setState(() {
      activeLectureId = doc.id;
      qrData = doc.id;
      activeLectureOpen = true;
      activeLectureEndTime = endTime is Timestamp ? endTime.toDate() : null;
    });
  }

  // Refreshes dashboard summary data.
  void _refreshDashboard() {
    setState(() {
      dashboardFuture = ReportService.getLecturerDashboardSummary(
        lecturerId: widget.user.uid,
      );
    });
  }

  // Shows a short snackbar notification.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Shows an alert dialog with a title and message.
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

  // Deletes a course after user confirmation.
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

    // Stops deletion if the user does not confirm.
    if (confirm != true) return;

    // Deletes the course and refreshes the dashboard.
    await ReportService.deleteCourse(courseId);
    _refreshDashboard();
    _notify('Course deleted successfully');
  }

  // Starts a periodic timer to update QR status and remaining time.
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      // Resets countdown if there is no active lecture.
      if (activeLectureId == null) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
        });
        return;
      }

      // Gets the active lecture document from Firestore.
      final doc = await FirebaseFirestore.instance
          .collection('lectures')
          .doc(activeLectureId)
          .get();

      // Resets local state if the lecture document no longer exists.
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

      // Stops countdown if the lecture is inactive or has no valid end time.
      if (!isActive || endTime is! Timestamp) {
        setState(() {
          _remaining = Duration.zero;
          activeLectureOpen = false;
        });
        return;
      }

      final end = endTime.toDate();
      final diff = end.difference(DateTime.now());

      // Closes the lecture when the QR duration expires.
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

      // Notifies the lecturer when only one minute remains.
      if (diff.inSeconds == 60) {
        _notify('Only 1 minute left before QR closes');
      }

      // Updates QR state and countdown.
      setState(() {
        qrData = doc.id;
        activeLectureId = doc.id;
        activeLectureEndTime = end;
        activeLectureOpen = true;
        _remaining = diff;
      });
    });
  }

  // Formats a Duration into HH:MM:SS or MM:SS.
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  // Creates a new course in Firestore.
  Future<void> _createCourse() async {
    if (_courseName.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('courses').add({
      'name': _courseName.text.trim(),
      'section': _sectionController.text.trim(),
      'lecturer_id': widget.user.uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Clears inputs and refreshes dashboard after course creation.
    _courseName.clear();
    _sectionController.clear();
    _refreshDashboard();
    _notify('Course created successfully');
  }

  // Creates a new lecture linked to the selected course.
  Future<void> _createLecture() async {
    if (_lectureName.text.trim().isEmpty) return;

    // Requires a course to be selected before creating a lecture.
    if (selectedCourseId == null || selectedCourseName == null) {
      _notify('Please select a course first');
      return;
    }

    // Requires building and room information.
    if (_buildingController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      _notify('Please enter building and room');
      return;
    }

    final doc = FirebaseFirestore.instance.collection('lectures').doc();

    // Saves the lecture data in Firestore.
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

    // Clears lecture inputs and refreshes dashboard.
    _lectureName.clear();
    _buildingController.clear();
    _roomController.clear();
    _notify('Lecture created successfully');
    _refreshDashboard();
  }

  // Opens a lecture QR for the selected duration.
  Future<void> _openLectureQr(String lectureId) async {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: selectedDurationMinutes));

    // Finds all currently active lectures for this lecturer.
    final activeLectures = await FirebaseFirestore.instance
        .collection('lectures')
        .where('lecturer_id', isEqualTo: widget.user.uid)
        .where('is_active', isEqualTo: true)
        .get();

    // Closes any previously active lecture before opening a new one.
    for (final doc in activeLectures.docs) {
      await doc.reference.update({'is_active': false});
    }

    // Activates the selected lecture and sets its start and end time.
    await FirebaseFirestore.instance
        .collection('lectures')
        .doc(lectureId)
        .update({
      'start_time': Timestamp.fromDate(now),
      'end_time': Timestamp.fromDate(end),
      'is_active': true,
    });

    // Updates local QR state.
    setState(() {
      activeLectureId = lectureId;
      qrData = lectureId;
      activeLectureEndTime = end;
      activeLectureOpen = true;
      _remaining = end.difference(DateTime.now());
    });

    _showDialogMessage('Lecture Started', 'QR is now active.');
  }

  // Manually closes the currently active QR.
  Future<void> _closeLectureNow() async {
    if (activeLectureId == null) return;

    // Marks the active lecture as inactive in Firestore.
    await FirebaseFirestore.instance
        .collection('lectures')
        .doc(activeLectureId)
        .update({'is_active': false});

    // Clears active lecture state.
    setState(() {
      activeLectureOpen = false;
      _remaining = Duration.zero;
      qrData = null;
      activeLectureId = null;
      activeLectureEndTime = null;
    });

    _showDialogMessage('Lecture Closed', 'The QR code was closed manually.');
  }

  // Builds a reusable dashboard statistics card.
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

  // Builds the dashboard tab with summary cards and course list.
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

              // Displays dashboard statistics.
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

              // Shows a message when there are no courses.
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No courses yet'),
                  ),
                );
              }

              // Builds the list of lecturer courses.
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

  // Builds the courses tab for creating and viewing courses.
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

            // Displays each course with student and delete actions.
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

  // Builds the lectures tab for creating lectures, managing QR, and viewing reports.
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

              // Selects the first course by default if no course is selected.
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
          // Shows the active QR card only when a QR is open.
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

              // Sorts lectures from newest to oldest.
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

              // Builds the lecture list with QR and report actions.
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
    // Checks whether the current theme is dark mode.
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
              // Signs out the current Firebase user.
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              // Navigates back to login and removes previous routes.
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
