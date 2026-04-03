import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';

class QRScanPage extends StatefulWidget {
  final AppUser user;
  final String courseId;
  final String courseName;

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
  bool processing = false;

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> scan(String code) async {
    if (processing) return;
    processing = true;

    try {
      final insideUniversity = await LocationService.isInsideUniversity();
      final onUniversityWifi = await WifiService.isOnUniversityWifi();

      if (!insideUniversity && !onUniversityWifi) {
        showMsg(
          'You must be inside the university or connected to ${WifiService.allowedWifiSsid}',
        );
        processing = false;
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('lectures')
          .where('qr_code', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        showMsg('Invalid QR code');
        processing = false;
        return;
      }

      final doc = query.docs.first;
      final lecture = doc.data();

      if (lecture['course_id'] != widget.courseId) {
        showMsg('This QR does not belong to this course');
        processing = false;
        return;
      }

      if (lecture['is_active'] != true) {
        showMsg('This QR is closed');
        processing = false;
        return;
      }

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

      final currentWifi = await WifiService.getCurrentWifiName();
      final lateThreshold = start.add(const Duration(minutes: 5));
      final status = now.isAfter(lateThreshold) ? 'Late' : 'Present';

      await FirebaseFirestore.instance.collection('attendance').add({
        'student_id': widget.user.uid,
        'student_name': widget.user.fullName,
        'student_email': widget.user.email,
        'lecture_id': doc.id,
        'lecture_name': lecture['name'],
        'course_id': lecture['course_id'],
        'course_name': lecture['course_name'],
        'section': lecture['section'] ?? '',
        'building': lecture['building'],
        'room': lecture['room'],
        'timestamp': FieldValue.serverTimestamp(),
        'inside_university': insideUniversity,
        'on_university_wifi': onUniversityWifi,
        'wifi_ssid': currentWifi,
        'status': status,
      });

      showMsg('Attendance recorded as $status');

      if (mounted) Navigator.pop(context);
    } catch (e) {
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
      body: Stack(
        children: [
          MobileScanner(
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
