import 'package:cloud_firestore/cloud_firestore.dart';

// The specific ledger account an expense is debited against (Dr) — e.g.
// "Office Rent Account", "Fuel Account". Shown in the "Expense Account
// (Dr)" dropdown.
class ExpenseAccount {
  final String id;
  final String name;
  final Timestamp? createdAt;

  ExpenseAccount({required this.id, required this.name, this.createdAt});

  factory ExpenseAccount.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseAccount(
        id: id, name: map['name'] ?? '', createdAt: map['createdAt']);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'createdAt': createdAt ?? FieldValue.serverTimestamp()};
  }

  // See the matching note on ExpenseHead — fixes the "Expense Account
  // (Dr)" dropdown breaking when the stream provides fresh instances.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExpenseAccount && other.id == id);

  @override
  int get hashCode => id.hashCode;
}