import 'package:cloud_firestore/cloud_firestore.dart';

<<<<<<< HEAD
// Service to handle student enrollment in courses
class EnrollmentService {
  // Firestore instance
  static final _db = FirebaseFirestore.instance;

  // Add student to a course
=======
class EnrollmentService {
  static final _db = FirebaseFirestore.instance;

>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
  static Future<void> enrollStudent({
    required String studentId,
    required String courseId,
  }) async {
    await _db.collection('enrollments').add({
<<<<<<< HEAD
      'student_id': studentId, // store student ID
      'course_id': courseId,   // store course ID
      'created_at': FieldValue.serverTimestamp(), // save time
    });
  }

  // Remove student from a course
=======
      'student_id': studentId,
      'course_id': courseId,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
  static Future<void> dropStudent({
    required String studentId,
    required String courseId,
  }) async {
<<<<<<< HEAD
    // Find enrollment documents for this student + course
=======
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
    final q = await _db
        .collection('enrollments')
        .where('student_id', isEqualTo: studentId)
        .where('course_id', isEqualTo: courseId)
        .get();

<<<<<<< HEAD
    // Delete all matching documents
=======
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
    for (var doc in q.docs) {
      await doc.reference.delete();
    }
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
