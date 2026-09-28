import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String partyType; // 'customer' or 'supplier'
  final String partyId;
  final String partyName;
  final double amount;
  final String note;
  final Timestamp? createdAt;

  Payment({
    required this.id,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    required this.amount,
    this.note = '',
    this.createdAt,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      partyType: map['partyType'] ?? 'customer',
      partyId: map['partyId'] ?? '',
      partyName: map['partyName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partyType': partyType,
      'partyId': partyId,
      'partyName': partyName,
      'amount': amount,
      'note': note,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}