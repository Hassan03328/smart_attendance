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
  final TextEditingController _lectureName = TextEditingController();
  String? qrData;

  Future<void> _createLecture() async {
    if (_lectureName.text.isEmpty) return;

    final doc = await FirebaseFirestore.instance.collection('lectures').add({
      'name': _lectureName.text,
      'lecturer_id': widget.user.uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    setState(() {
      qrData = doc.id;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _lectureName,
              decoration: const InputDecoration(
                labelText: 'Lecture Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createLecture,
              child: const Text('Create Lecture & QR'),
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
          ],
        ),
      ),
    );
  }
}
