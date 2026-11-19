import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/supplier.dart';

class SupplierService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('suppliers');

  Stream<List<Supplier>> streamSuppliers() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it). Admin, Counter
    // Sale etc. get everything, sorted by name as before.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('name')
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Supplier.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) list.sort((x, y) => x.name.compareTo(y.name));
      return list;
    });
  }

  Stream<Supplier?> streamSupplierByEmail(String email) {
    if (email.isEmpty) return Stream.value(null);
    return _col.where('email', isEqualTo: email).limit(1).snapshots().map(
            (snap) => snap.docs.isEmpty
            ? null
            : Supplier.fromMap(
            snap.docs.first.id,
            snap.docs.first.data() as Map<String, dynamic>));
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _col.add(supplier.toMap());
  }

  Future<void> updateSupplier(String id, Supplier supplier) async {
    await _col.doc(id).update(supplier.toMap());
  }

  Future<void> deleteSupplier(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> adjustPayable(String id, double delta) async {
    await _col.doc(id).update({'totalPayable': FieldValue.increment(delta)});
  }
}