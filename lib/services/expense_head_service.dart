import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_head.dart';

class ExpenseHeadService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('expense_heads');

  Stream<List<ExpenseHead>> streamExpenseHeads() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) =>
        ExpenseHead.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addExpenseHead(String name) async {
    await _col.add(ExpenseHead(id: '', name: name).toMap());
  }

  Future<void> deleteExpenseHead(String id) async {
    await _col.doc(id).delete();
  }
}