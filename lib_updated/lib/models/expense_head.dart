import 'package:cloud_firestore/cloud_firestore.dart';

// A category of expense (Rent, Utilities, Fuel, etc.) — shown in the
// "Expense Head" dropdown on the Add Expense form.
class ExpenseHead {
  final String id;
  final String name;
  final Timestamp? createdAt;

  ExpenseHead({required this.id, required this.name, this.createdAt});

  factory ExpenseHead.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseHead(id: id, name: map['name'] ?? '', createdAt: map['createdAt']);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'createdAt': createdAt ?? FieldValue.serverTimestamp()};
  }

  // Without this, the "Expense Head" dropdown breaks the moment the
  // stream re-emits (e.g. right after adding a new head) — the
  // previously selected value is an old instance that no longer matches
  // anything in the fresh list by reference, so Flutter shows it as
  // unselected / throws. Comparing by id fixes that.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExpenseHead && other.id == id);

  @override
  int get hashCode => id.hashCode;
}