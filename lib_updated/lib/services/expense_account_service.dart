import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_account.dart';

class ExpenseAccountService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('expense_accounts');

  Stream<List<ExpenseAccount>> streamExpenseAccounts() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) =>
        ExpenseAccount.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addExpenseAccount(String name) async {
    await _col.add(ExpenseAccount(id: '', name: name).toMap());
  }

  Future<void> deleteExpenseAccount(String id) async {
    await _col.doc(id).delete();
  }
}