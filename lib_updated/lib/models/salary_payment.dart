import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryPayment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String month; // e.g. "September 2026"
  final double amount;
  final String notes;
  final Timestamp? createdAt;

  SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.amount,
    this.notes = '',
    this.createdAt,
  });

  factory SalaryPayment.fromMap(String id, Map<String, dynamic> map) {
    return SalaryPayment(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      month: map['month'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'month': month,
      'amount': amount,
      'notes': notes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}