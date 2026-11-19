import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quotation.dart';
import '../utils/branch_filter.dart';

// Shared across ONE branch's counters, not per-user — so any Counter Sale
// staff of that branch can resume a hold that a colleague parked earlier,
// same as a real till. Other branches' holds are never visible.
class QuotationService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('quotations');

  Stream<List<Quotation>> streamQuotations() {
    // A branch-locked login (Counter Sale / Manager) asks Firestore for its
    // own branch only (the security rules require it) and sorts here,
    // because "branch equals + order by date" would need a composite index.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('createdAt', descending: true)
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) =>
          Quotation.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) {
        int ms(Quotation x) => x.createdAt?.millisecondsSinceEpoch ?? 0;
        list.sort((x, y) => ms(y).compareTo(ms(x)));
      }
      return list;
    });
  }

  Future<void> addQuotation(Quotation quotation) async {
    // Stamp the branch here so every screen that parks a sale gets it.
    final data = quotation.toMap();
    data['branchId'] = lockedBranchId ?? selectedBranchId.value ?? '';
    await _col.add(data);
  }

  Future<void> deleteQuotation(String id) async {
    await _col.doc(id).delete();
  }
}