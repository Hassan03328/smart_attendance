import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
<<<<<<< HEAD
import '../services/location_service.dart';
import '../services/wifi_service.dart';

// QR Scan screen for student attendance
class QRScanPage extends StatefulWidget {
  final AppUser user; // current logged-in student
  final String courseId; // current course id
  final String courseName; // current course name
=======

class QRScanPage extends StatefulWidget {
  final AppUser user;
  final String courseId;
  final String courseName;
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2

  const QRScanPage({
    super.key,
    required this.user,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
<<<<<<< HEAD
  bool processing = false; // prevent multiple scans

  // Show message to user
=======
  bool processing = false;

>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

<<<<<<< HEAD
  // Main scan logic
  Future<void> scan(String code) async {
    if (processing) return; // stop if already scanning
    processing = true;

    try {
      // Check location and WiFi for anti-cheat
      final insideUniversity = await LocationService.isInsideUniversity();
      final onUniversityWifi = await WifiService.isOnUniversityWifi();

      if (!insideUniversity && !onUniversityWifi) {
        showMsg(
          'You must be inside the university or connected to ${WifiService.allowedWifiSsid}',
        );
        processing = false;
        return;
      }

      // Get lecture by QR code
      final query = await FirebaseFirestore.instance
          .collection('lectures')
          .where('qr_code', isEqualTo: code)
          .limit(1)
=======
  Future<void> scan(String code) async {
    if (processing) return;
    processing = true;

    try {
      final query = await FirebaseFirestore.instance
          .collection('lectures')
          .where('qr_code', isEqualTo: code)
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
          .get();

      if (query.docs.isEmpty) {
        showMsg('Invalid QR code');
        processing = false;
        return;
      }

      final doc = query.docs.first;
      final lecture = doc.data();

<<<<<<< HEAD
      // Check if QR belongs to this course
=======
      // ✅ تحقق من المادة
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
      if (lecture['course_id'] != widget.courseId) {
        showMsg('This QR does not belong to this course');
        processing = false;
        return;
      }

<<<<<<< HEAD
      // Check if lecture is active
      if (lecture['is_active'] != true) {
        showMsg('This QR is closed');
        processing = false;
        return;
      }

      // Check time validity
=======
      // ✅ تحقق من الوقت
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
      final now = DateTime.now();
      final start = lecture['start_time'].toDate();
      final end = lecture['end_time'].toDate();

      if (now.isBefore(start)) {
        showMsg('Attendance not started yet');
        processing = false;
        return;
      }

      if (now.isAfter(end)) {
        showMsg('QR expired');
        processing = false;
        return;
      }

<<<<<<< HEAD
      // Check if student already scanned
=======
      // ✅ منع التكرار
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
      final exist = await FirebaseFirestore.instance
          .collection('attendance')
          .where('student_id', isEqualTo: widget.user.uid)
          .where('lecture_id', isEqualTo: doc.id)
          .get();

      if (exist.docs.isNotEmpty) {
        showMsg('Already recorded');
        processing = false;
        return;
      }

<<<<<<< HEAD
      // Get WiFi name
      final currentWifi = await WifiService.getCurrentWifiName();

      // Late rule: after 5 minutes
      final lateThreshold = start.add(const Duration(minutes: 5));
      final status = now.isAfter(lateThreshold) ? 'Late' : 'Present';

      // Save attendance in Firestore
=======
      // ✅ تسجيل الحضور
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
      await FirebaseFirestore.instance.collection('attendance').add({
        'student_id': widget.user.uid,
        'student_name': widget.user.fullName,
        'student_email': widget.user.email,
        'lecture_id': doc.id,
        'lecture_name': lecture['name'],
        'course_id': lecture['course_id'],
        'course_name': lecture['course_name'],
<<<<<<< HEAD
        'section': lecture['section'] ?? '',
        'building': lecture['building'],
        'room': lecture['room'],
        'timestamp': FieldValue.serverTimestamp(),
        'inside_university': insideUniversity,
        'on_university_wifi': onUniversityWifi,
        'wifi_ssid': currentWifi,
        'status': status,
      });

      // Success message
      showMsg('Attendance recorded as $status');

      // Close page after success
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Handle errors
=======
        'timestamp': FieldValue.serverTimestamp(),
      });

      showMsg('Attendance recorded');

      if (mounted) Navigator.pop(context);
    } catch (e) {
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
      showMsg('Error: $e');
    }

    processing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR - ${widget.courseName}'),
      ),
<<<<<<< HEAD
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  scan(code); // call scan function
                  break;
                }
              }
            },
          ),
          // Top info message (anti-cheat info)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Anti-Cheat Enabled: Course + Time + Location/WiFi + One Check-in Only',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
=======
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final code = barcode.rawValue;

            if (code != null) {
              scan(code);
              break;
            }
          }
        },
      ),
    );
  }
}
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
