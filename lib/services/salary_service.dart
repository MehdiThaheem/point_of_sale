import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/salary_payment.dart';

class SalaryService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('salary_payments');

  Stream<List<SalaryPayment>> streamSalaryPayments() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => SalaryPayment.fromMap(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> generateSalary(SalaryPayment payment) async {
    await _col.add(payment.toMap());
  }

  Future<void> deleteSalaryPayment(String id) async {
    await _col.doc(id).delete();
  }
}