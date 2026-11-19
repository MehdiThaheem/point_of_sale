import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/expense.dart';

class ExpenseService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('expenses');

  Stream<List<Expense>> streamExpenses() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it) and sort here,
    // because "branch equals + order by date" would need a composite index.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('date', descending: true)
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Expense.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) {
        int ms(Expense x) => x.date?.millisecondsSinceEpoch ?? 0;
        list.sort((x, y) => ms(y).compareTo(ms(x)));
      }
      return list;
    });
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