import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../services/location_service.dart';

class QRScanPage extends StatefulWidget {
  final AppUser user;

  const QRScanPage({super.key, required this.user});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _processing = false;

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markAttendance(String qrCode) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      /// ✅ 1. Check location first
      final inside = await LocationService.isInsideUniversity();
      if (!inside) {
        _showMsg('You must be inside the university to mark attendance');
        setState(() => _processing = false);
        return;
      }

      /// ✅ 2. Get lecture by QR
      final lectureQuery = await FirebaseFirestore.instance
          .collection('lectures')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (lectureQuery.docs.isEmpty) {
        _showMsg('Invalid QR code');
        setState(() => _processing = false);
        return;
      }

      final lecture = lectureQuery.docs.first;

      /// ✅ 3. Prevent duplicate attendance
      final alreadyMarked = await FirebaseFirestore.instance
          .collection('attendance')
          .where('student_id', isEqualTo: widget.user.uid)
          .where('lecture_id', isEqualTo: lecture.id)
          .get();

      if (alreadyMarked.docs.isNotEmpty) {
        _showMsg('Attendance already recorded');
        setState(() => _processing = false);
        return;
      }

      /// ✅ 4. Save attendance
      await FirebaseFirestore.instance.collection('attendance').add({
        'student_id': widget.user.uid,
        'lecture_id': lecture.id,
        'lecture_name': lecture['name'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showMsg('Attendance marked successfully');
      Navigator.pop(context);
    } catch (e) {
      _showMsg('Error: $e');
    }

    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw != null) {
              _markAttendance(raw);
              break;
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
