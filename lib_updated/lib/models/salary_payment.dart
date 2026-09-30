import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryPayment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String month; // e.g. "September 2026"
  final double amount; // amount actually paid
  final String notes;

  // Optional breakdown used by the Salary Sheet. Old records don't have
  // these, so they all default to 0 / empty and keep working.
  final double basic;
  final double deduction;
  final String deductionReason;
  final double incentive;

  final Timestamp? createdAt;

  SalaryPayment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.amount,
    this.notes = '',
    this.basic = 0,
    this.deduction = 0,
    this.deductionReason = '',
    this.incentive = 0,
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
      basic: (map['basic'] ?? 0).toDouble(),
      deduction: (map['deduction'] ?? 0).toDouble(),
      deductionReason: map['deductionReason'] ?? '',
      incentive: (map['incentive'] ?? 0).toDouble(),
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
      'basic': basic,
      'deduction': deduction,
      'deductionReason': deductionReason,
      'incentive': incentive,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}