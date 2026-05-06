import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String courseId;
  final String lecturerId;
  final Timestamp startTime;
  final Timestamp endTime;
  final double latitude;
  final double longitude;
  final bool isActive;

  Session({
    required this.id,
    required this.courseId,
    required this.lecturerId,
    required this.startTime,
    required this.endTime,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      courseId: data['courseId'],
      lecturerId: data['lecturerId'],
      startTime: data['startTime'],
      endTime: data['endTime'],
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? false,
    );
  }
}
