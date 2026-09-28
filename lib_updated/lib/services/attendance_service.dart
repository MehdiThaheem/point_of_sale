import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_record.dart';

class AttendanceService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('attendance');

  // One record per employee per day - the doc id combines both so
  // marking attendance again for the same day simply overwrites it.
  String _docId(String employeeId, String dateKey) => '${employeeId}_$dateKey';

  Stream<List<AttendanceRecord>> streamAttendanceForDate(String dateKey) {
    return _col
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => AttendanceRecord.fromMap(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<AttendanceRecord>> streamAttendanceForEmployee(
      String employeeId) {
    // Sorting is done locally (below) instead of via Firestore's
    // .orderBy(), because where('employeeId') + orderBy('dateKey') on two
    // different fields requires a composite index that doesn't exist by
    // default — that's exactly what threw the
    // "cloud_firestore/failed-precondition ... requires an index" error.
    // A plain where() with no orderBy needs no index, so this works
    // immediately with no Firebase console setup at all.
    return _col
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snap) {
      final records = snap.docs
          .map((d) => AttendanceRecord.fromMap(
          d.id, d.data() as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
      return records;
    });
  }

  Future<void> markAttendance(AttendanceRecord record) async {
    await _col
        .doc(_docId(record.employeeId, record.dateKey))
        .set(record.toMap());
  }
}