import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payments.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('payments');

  Stream<List<Payment>> streamPayments() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Payment.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // Records a payment and reduces the party's outstanding balance.
  // Customer payment -> reduces totalReceivable.
  // Supplier payment -> reduces totalPayable.
  Future<void> addPayment(Payment payment) async {
    await _db.runTransaction((transaction) async {
      final paymentRef = _col.doc();
      transaction.set(paymentRef, payment.toMap());

      final collectionName =
      payment.partyType == 'supplier' ? 'suppliers' : 'customers';
      final field =
      payment.partyType == 'supplier' ? 'totalPayable' : 'totalReceivable';

      final partyRef = _db.collection(collectionName).doc(payment.partyId);
      transaction.update(partyRef, {
        field: FieldValue.increment(-payment.amount),
      });
    });
  }

  Future<void> deletePayment(Payment payment) async {
    await _db.runTransaction((transaction) async {
      final collectionName =
      payment.partyType == 'supplier' ? 'suppliers' : 'customers';
      final field =
      payment.partyType == 'supplier' ? 'totalPayable' : 'totalReceivable';

      final partyRef = _db.collection(collectionName).doc(payment.partyId);
      transaction.update(partyRef, {
        field: FieldValue.increment(payment.amount),
      });

      transaction.delete(_col.doc(payment.id));
    });
  }
}