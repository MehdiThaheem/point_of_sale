import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String dateKey; // 'YYYY-MM-DD', one record per employee per day
  final String status; // present / absent / leave
  final Timestamp? createdAt;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dateKey,
    required this.status,
    this.createdAt,
  });

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      dateKey: map['dateKey'] ?? '',
      status: map['status'] ?? 'present',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'dateKey': dateKey,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}