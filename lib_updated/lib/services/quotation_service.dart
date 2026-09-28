import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quotation.dart';

// Shared across the shop, not per-user — so any Counter Sale staff can
// resume a hold that a colleague parked earlier, same as a real till.
class QuotationService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('quotations');

  Stream<List<Quotation>> streamQuotations() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Quotation.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addQuotation(Quotation quotation) async {
    await _col.add(quotation.toMap());
  }

  Future<void> deleteQuotation(String id) async {
    await _col.doc(id).delete();
  }
}