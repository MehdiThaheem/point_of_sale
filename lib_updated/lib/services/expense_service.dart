import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

class ExpenseService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('expenses');

  Stream<List<Expense>> streamExpenses() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => Expense.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addExpense(Expense expense) async {
    await _col.add(expense.toMap());
  }

  Future<void> updateExpense(String id, Expense expense) async {
    await _col.doc(id).update(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    await _col.doc(id).delete();
  }
}